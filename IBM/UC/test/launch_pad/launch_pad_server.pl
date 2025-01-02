#!/usr/bin/perl

#use strict;


use IBM::UC::Database::SolidDB;
use IBM::UC::Database::Db2DB;
use IBM::UC::Database::InformixDB;
use IBM::UC::CDC::CDCSolid;
use IBM::UC::CDC::CDCDb2;
use IBM::UC::CDC::CDCInformix;
use IBM::UC::AccessServer::AccessServer;
use IBM::UC::AccessServer::Datastore;
use IBM::UC::Environment;
use IO::Socket::INET;
use File::Path;
use File::Copy;

my @VALID_METHODS = qw(init install_solid install_cdc_solid install_cdc_db2 install_cdc_ids 
						create_instance_solid create_instance_db2 create_instance_ids 
						create_instance_cdc_solid create_instance_cdc_db2 create_instance_cdc_ids
						install_access_server init_access_server install_mconsole create_datastore
						create_datastore_remote replication cleanup test);

my ($env,$db_src,$db_tgt,$cdc_src,$cdc_tgt,$mConsole,$ds_src,$ds_tgt,$subname);


# Installation packages
my $SOLID_PACKAGE_32 = 'solidDB6.5_x86.bin';
my $SOLID_PACKAGE_WIN_32 = 'solidDB6.5_x86.exe';
my $SOLID_PACKAGE_64 = 'solidDB6.5_x86_64.bin';
my $SOLID_PACKAGE_WIN_64 = 'solidDB6.5_x86.exe';
my $CDC_SOLID_PACKAGE = 'setup-linux-x86-solid.bin';
my $CDC_SOLID_PACKAGE_WIN = 'setup-win-x86-solid.exe';
my $CDC_DB2_PACKAGE = 'setup-linux-x86-udb.bin';
my $CDC_DB2_PACKAGE_WIN = 'setup-win-x86-udb.exe';
my $CDC_IDS_PACKAGE = 'setup-linux-x86-informix.bin';
my $CDC_IDS_PACKAGE_WIN = 'setup-win-x86-informix.exe';
my $ACCESS_SERVER_PACKAGE = 'setup-linux-x86-accessserver.bin';
my $ACCESS_SERVER_PACKAGE_WIN = 'setup-win-x86-accessserver.exe';


if (require Config) {
	if ($Config::Config{'osname'} =~ /^MSWin/i) {
		 launch_pad_server_pipe_win(@ARGV);
	} else {
		launch_pad_server_pipe_linux(@ARGV);
	}
} else {
	die "Cannot load Config module: $!";
}

my $global_test = 'x';
sub test
{
	my @arglist = @_;
	my ($key, $value);
	print join('*',@arglist) . "\n";
	print $global_test . "\n";
	$global_test .= 'x';
	return "FINISHED_TEST";
}


#-----------------------------------------------------------------------
# launch_pad_server_pipe_linux()
#-----------------------------------------------------------------------
#
# Start server (on Linux machine)
# Server talks to clients through a named pipe
# A client sends a request to the server to invoke a server method
# Method name and parameters are passed from client as a single string
# Method name is separated from parameters by the pound sign
# Individual parameters are separated by an exclamation mark
# e.g. "install_solid£/home/db2inst1/bank_demo/!/home/db2inst1/soliddb-6.5"
#
#-----------------------------------------------------------------------
sub launch_pad_server_pipe_linux
{
	my $lpipe = $ENV{'HOME'} . '/launch_pad_server.pipe';
	my $ret_code;
	my $loop = 1;
	my ($lmethod,$method,$param);

	# Deleting existing pipe
	unlink($lpipe) if (-p $lpipe);
	require POSIX or die "Cannot load POSIX module: $!";
    POSIX::mkfifo($lpipe, 0666) or die "can't mknod $lpipe: $!"; # Create new pipe

	while ($loop) {
		open(SYSFIFO, "< $lpipe")  or die "launch_pad_server_linux: Can't open pipe for reading: $!";
		if (defined($lmethod = <SYSFIFO>)) { # Read any data sent by client
			chomp $lmethod;
			($method, $param) = split(/£/,$lmethod); # Split method and parameters
			@param = split(/!/,$param);
			close(SYSFIFO);
			if ($method eq "stop_server") { # Signal from client to shut down server
				$loop = 0;
				last;
			}
			# Call method and write result to client (0 for success, non-zero for failure)
			open(SYSFIFO, "> $lpipe")  or die "launch_pad_server_linux: Can't open pipe for writing: $!";
			if (grep($method eq $_, @VALID_METHODS)) {
				$ret_code = &$method(@param);
				print SYSFIFO $ret_code;
			} elsif (length($method) > 0) {
				print "Invalid method: $method\n";
				print SYSFIFO 1;
			}
		}
		close(SYSFIFO);
		sleep(3);
	}
	unlink($lpipe);
	print ">> SERVER SHUT DOWN\n";
	exit(0);
}


#-----------------------------------------------------------------------
# launch_pad_server_pipe_win()
#-----------------------------------------------------------------------
#
# Start server (on Windows machine)
# Server talks to clients through a named pipe
# A client sends a request to the server to invoke a server method
# Method name and parameters are passed from client as a single string
# Method name is separated from parameters by the pound sign
# Individual parameters are separated by an exclamation mark
# e.g. "install_solid£/home/db2inst1/bank_demo/!/home/db2inst1/soliddb-6.5"
#
#-----------------------------------------------------------------------
sub launch_pad_server_pipe_win
{
	my $lpipe;
	my $ret_code;
	my $user;
	my ($lmethod,$method,$param);

	require Win32::Pipe or die "Cannot load required module Win32::Pipe: $!";

	while (1) {
		$lpipe = new Win32::Pipe("launch_pad_server.pipe") or die "Cannot create pipe: $!\n";
		if ($lpipe->Connect()) { # check for any connected clients
			$lmethod = $lpipe->Read(); # Read data from client
			chomp $lmethod;

			($method, $param) = split(/£/,$lmethod);
			@param = split(/!/,$param);
		
			last if ($method eq "stop_server"); # Signal from client to shut down server
			# Call method and write result to client (0 for success, non-zero for failure)
			if (grep($method eq $_, @VALID_METHODS)) {
				$ret_code = &$method(@param);
				$lpipe->Write($ret_code);
			} elsif (length($method) > 0) {
				print "Invalid method: $method\n";
				$lpipe->Write(1);
			}
			$lpipe->Disconnect(); # Disconnect from client
		}
		sleep(3);
	}
	$lpipe->Close(); # Close pipe
	print ">> SERVER SHUT DOWN\n";
	exit(0);
}



#-----------------------------------------------------------------------
# launch_pad_server([$port])
#-----------------------------------------------------------------------
#
# Start server listening on tcp port
#
#-----------------------------------------------------------------------
sub launch_pad_server
{ 
	my $port = shift || '7070';
	my ($client, @add, $method, $param, @param, $ret_code, $lmethod);
	my $server = new IO::Socket::INET (
		LocalPort => $port, 
		Proto => 'tcp',
		Listen => 1,
		Reuse => 1,
		Type => IO::Socket::SOCK_STREAM,
	);
  
	die "Could not create socket: $!\n" unless $server;
  
	while ($client = $server->accept())
	{
		@add = $client->peerhost();
#		print join(".",@add)."\n";
		$client->recv($lmethod, 1024);
		chomp $lmethod;

		($method, $param) = split(/£/,$lmethod);
		@param = split(/!/,$param);
		
		last if ($method eq "stop_server");
		if (grep($method eq $_, @VALID_METHODS)) {
			$ret_code = &$method(@param);
			print $client $ret_code;
		} else {
			print "Invalid method: $method\n";
			print $client 1;
		}
		close $client;
	}
	close($client);
	close($server);
	exit(0);
}




#-----------------------------------------------------------------------
# init()
#-----------------------------------------------------------------------
#
# Initialise server module
#
#-----------------------------------------------------------------------
sub init
{
	my $env_parms = {
		debug => 1,
		smtp_server => 'D06DBE01',
		email_admin => 'mooreof@ie.ibm.com',
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));
	$env = Environment->getEnvironment();
	$db_src = undef;
	$db_tgt = undef;
	$cdc_src = undef;
	$cdc_tgt = undef;
	$mConsole = undef;
	$subname = undef;
	$ds_src = undef;
	$ds_tgt = undef;
	return 0;
}



#-----------------------------------------------------------------------
# install_solid($install_root,$install_to)
#-----------------------------------------------------------------------
#
# Installs solid using SolidDB install routine
# Routine also adds installation directory to PATH environment variable
# and sets Environment solidRootDir()
# install_from is the base directory to which is added the actual source
# package name (os-dependent)
# install_solid('/home/user/packages','/home/user/solid')
#
#-----------------------------------------------------------------------
sub install_solid
{
	my ($install_root, $install_to) = @_;
	my $install_from;
	my $ps;

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}
	$ps = $env->getPathSeparator();
	
	if (!defined($install_root)) {
		print ("[ERROR] install_solid: expecting installation source location as 1st parameter\n");
		return 1;
	}
	if (!defined($install_to)) {
		print ("[ERROR] install_solid: expecting installation destination as 2nd parameter\n");
		return 1;
	}

	if ($env->getOSName() eq 'windows') {
		if ($env->CDCBits() == 64) {
			$install_from = "${install_root}${ps}install${ps}${SOLID_PACKAGE_WIN_64}";
		} else {
			$install_from = "${install_root}${ps}install${ps}${SOLID_PACKAGE_WIN_32}";
		}
	} else {
		if ($env->CDCBits() == 64) {
			$install_from = "${install_root}${ps}install${ps}${SOLID_PACKAGE_64}";
		} else {
			$install_from = "${install_root}${ps}install${ps}${SOLID_PACKAGE_32}";
		}
	}

	# I presume install package creates target directory if it doesn't exist?
	eval { # Trap errors from install
       SolidDB->install($install_to, $install_from);
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\ninstall_solid: Errors found: $@\n"); 
		return 1;
	}
	
	return 0;
}


#-----------------------------------------------------------------------
# install_cdc_solid($install_root,$install_to)
#-----------------------------------------------------------------------
#
# Installs CDC for solid using CDCSolid install routine
# Routine also adds installation directory to PATH environment variable
# and sets Environment cdcSolidRootDir()
# install_from is the base directory to which is added the actual source
# package name (os-dependent)
# install_cdc_solid('/home/user/packages','/home/user/cdcsolid')
#
#-----------------------------------------------------------------------
sub install_cdc_solid
{
	my ($install_root, $install_to) = @_;
	my $install_from;
	my $ps;

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}
	$ps = $env->getPathSeparator();
	
	if (!defined($install_root)) {
		print ("[ERROR] install_cdc_solid: expecting installation source location as 1st parameter\n");
		return 1;
	}
	if (!defined($install_to)) {
		print ("[ERROR] install_cdc_solid: expecting installation destination as 2nd parameter\n");
		return 1;
	}

	if ($env->getOSName() eq 'windows') {
		$install_from = "${install_root}${ps}install${ps}${CDC_SOLID_PACKAGE_WIN}";
	} else {
		$install_from = "${install_root}${ps}install${ps}${CDC_SOLID_PACKAGE}";
	}

	# I presume install package creates target directory if it doesn't exist?
	eval { # Trap errors from install
		CDCSolid->install($install_to, $install_from);
		sleep(5);
		# Copy library patch
		File::Copy::cp("${install_root}${ps}patch${ps}api2_uc65.jar", "${install_to}${ps}lib${ps}");
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\ninstall_cdc_solid: Errors found: $@\n"); 
		return 1;
	}
	
	return 0;
}


#-----------------------------------------------------------------------
# install_cdc_db2($install_root,$install_to)
#-----------------------------------------------------------------------
#
# Installs CDC for DB2 using CDCDb2 install routine
# Routine also adds installation directory to PATH environment variable
# and sets Environment cdcDb2RootDir()
# install_from is the base directory to which is added the actual source
# package name (os-dependent)
# install_cdc_db2('/home/user/packages','/home/user/cdcdb2')
#
#-----------------------------------------------------------------------
sub install_cdc_db2
{
	my ($install_root, $install_to) = @_;
	my $install_from;
	my $ps;

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}
	$ps = $env->getPathSeparator();
	
	if (!defined($install_root)) {
		print ("[ERROR] install_cdc_db2: expecting installation source location as 1st parameter\n");
		return 1;
	}
	if (!defined($install_to)) {
		print ("[ERROR] install_cdc_db2: expecting installation destination as 2nd parameter\n");
		return 1;
	}

	if ($env->getOSName() eq 'windows') {
		$install_from = "${install_root}${ps}install${ps}${CDC_DB2_PACKAGE_WIN}";
	} else {
		$install_from = "${install_root}${ps}install${ps}${CDC_DB2_PACKAGE}";
	}

	# I presume install package creates target directory if it doesn't exist?
	eval { # Trap errors from install
		CDCDb2->install($install_to, $install_from);
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\ninstall_cdc_db2: Errors found: $@\n"); 
		return 1;
	}
	
	return 0;
}


#-----------------------------------------------------------------------
# install_cdc_ids($install_root,$install_to)
#-----------------------------------------------------------------------
#
# Installs CDC for IDS using CDCInformix install routine
# Routine also adds installation directory to PATH environment variable
# and sets Environment CDCInformixRootDir()
# install_from is the base directory to which is added the actual source
# package name (os-dependent)
# install_cdc_ids('/home/user/packages','/home/user/cdcinformix')
#
#-----------------------------------------------------------------------
sub install_cdc_ids
{
	my ($install_root, $install_to) = @_;
	my $install_from;
	my $ps;

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}
	$ps = $env->getPathSeparator();
	
	if (!defined($install_root)) {
		print ("[ERROR] install_cdc_ids: expecting installation source location as 1st parameter\n");
		return 1;
	}
	if (!defined($install_to)) {
		print ("[ERROR] install_cdc_ids: expecting installation destination as 2nd parameter\n");
		return 1;
	}

	if ($env->getOSName() eq 'windows') {
		$install_from = "${install_root}${ps}install${ps}${CDC_IDS_PACKAGE_WIN}";
	} else {
		$install_from = "${install_root}${ps}install${ps}${CDC_IDS_PACKAGE}";
	}

	# I presume install package creates target directory if it doesn't exist?
	eval { # Trap errors from install
		CDCInformix->install($install_to, $install_from);
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\ninstall_cdc_ids: Errors found: $@\n"); 
		return 1;
	}
	
	return 0;
}


#-----------------------------------------------------------------------
# install_access_server($install_root,$install_to)
#-----------------------------------------------------------------------
#
# Installs Access server using routine in AccessServer module
# Routine also adds installation directory to PATH environment variable
# and sets Environment accessServerRootDir()
# install_from is the base directory to which is added the actual source
# package name (os-dependent)
# install_access_server('/home/user/packages','/home/user/accessserver')
#
#-----------------------------------------------------------------------
sub install_access_server
{
	my ($install_root, $install_to) = @_;
	my ($install_from,$install_to_default);
	my $ps;

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}
	$ps = $env->getPathSeparator();

	# The InstallAnywhere package for Access Server always installs in a default
	# location which cannot be overridden, hence the need to move to the desired
	# destination directory after the initial installation 
	if ($env->getOSName() eq 'windows') {
		$install_to_default = "c:\\program files\\datamirror\\transformation server access control";
	} else {
		$install_to_default = $ENV{'HOME'} . '/DataMirror/Transformation Server Access Control';
	}
	
	if (!defined($install_root)) {
		print ("[ERROR] install_access_server: expecting installation source location as 1st parameter\n");
		return 1;
	}
	if (!defined($install_to)) {
		print ("[ERROR] install_access_server: expecting installation destination as 2nd parameter\n");
		return 1;
	}

	if ($env->getOSName() eq 'windows') {
		$install_from = "${install_root}${ps}install${ps}${ACCESS_SERVER_PACKAGE_WIN}";
	} else {
		$install_from .= "${install_root}${ps}install${ps}${ACCESS_SERVER_PACKAGE}";
	}

	# I presume install package creates target directory if it doesn't exist?
	eval { # Trap errors from install
		AccessServer->install($install_to, $install_from);
		if ($install_to ne $install_to_default) { # Move to desired destination
			if (require File::Copy::Recursive) {
				mkpath($install_to);
				File::Copy::Recursive::dircopy($install_to_default, $install_to);
				File::Path::rmtree($install_to_default,0,0);
			} else {
				print ("[ERROR] install_access_server: File::Copy::Recursive module not installed so cannot complete installation\n");
				return 1;
			}
		}
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\ninstall_access_server: Errors found: $@\n"); 
		return 1;
	}
	
	return 0;
}



#-----------------------------------------------------------------------
# create_instance_solid($solid_root,$dbdir,$dbport,$dblic,$type,$start,
# 						$dbuser,$dbpass,$dbschema,$sma,$passthrough)
#-----------------------------------------------------------------------
#
# Create and start an instance of Solid, where:
# $solid_root=installation directory of solid binary
# $dbdir=solid instance root directory
# $dbport=database port number
# $dblic=solid licence file
# $type=source or target (s/t)
# $start=start database manager (0/1) [manager may already be running]
# $dbuser=database user name
# $dbpass=database password
# $dbschema=database schema name
# $sma=smart memory access (0/1)
# $passthrough=enable passthrough (0/1)
# create_instance_solid('/home/user/solid/solid','/home/user/solid_test/',1315,
#						'/home/user/solid/solid.lic','s',1,'dba','dba','DBA',0,0)
#
#-----------------------------------------------------------------------
sub create_instance_solid
{
	my $solid_root = shift;
	my $dbdir = shift;
	my $dbport = shift;
	my $dblic = shift;
	my $type = shift;
	my $start = shift;
	my $dbuser = shift;
	my $dbpass = shift;
	my $dbschema = shift;
	my $sma = shift;
	my $passthrough = shift;
	my $solid;
	

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}
	# Store location of solid binary and update PATH environment variable (second parameter = 1)
	$env->solidRootDir($solid_root,1);

	eval { # Trap errors
		$solid = SolidDB->createSimple($dbdir,$dbport,$dblic);
		$solid->dbUser($dbuser) if (defined($dbuser));
		$solid->dbPass($dbpass) if (defined($dbpass));
		$solid->dbSchema($dbschema) if (defined($dbschema));
		$solid->start() if ($start == 1);

		if ($type eq 's') {
			$db_src = $solid;
		} else {
			$db_tgt = $solid;
		}
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\ncreate_instance_solid: Errors found: $@\n");
		return 1;
	}
	return 0;
}


#-----------------------------------------------------------------------
# create_instance_db2($dbdir,$dbuser,$dbpass,$dbschema,$dbname,$dbport,$type,$start)
#-----------------------------------------------------------------------
#
# Create and start an instance of DB2, where:
# $dbdir=solid instance root directory
# $dbuser=database user name
# $dbpass=database password
# $dbschema=database schema name
# $dbname=database schema name
# $dbport=database port number
# $type=source or target (s/t)
# $start=start database manager (0/1) [manager may already be running]
# create_instance_db2('/home/user/db2/','db2admin','db2admin','schema','db2',50000,'s',1)
#
#-----------------------------------------------------------------------
sub create_instance_db2
{
	my $dbdir = shift;
	my $dbuser = shift;
	my $dbpass = shift;
	my $dbschema = shift;
	my $dbname = shift;
	my $dbport = shift;
	my $type = shift;
	my $start = shift;
	my $db2;
	

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}

	eval { # Trap errors
		$db2 = Db2DB->createSimple($dbdir,$dbname,$dbuser,$dbpass,$dbschema);
		$db2->dbPort($dbport);
		if ($start == 1) {
			$db2->start();
			$db2->createDatabase($dbname);
			$db2->createSchema($dbschema);
		}
		if ($type eq 's') {
			$db_src = $db2;
		} else {
			$db_tgt = $db2;
		}
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\ncreate_instance_db2: Errors found: $@\n");
		return 1;
	}
	return 0;
}



#-----------------------------------------------------------------------
# create_instance_ids($dbdir,$dbuser,$dbpass,$dbschema,$dbname,$dbport,
#						$dbserver,$type,$start)
#-----------------------------------------------------------------------
#
# Create and start an instance of DB2, where:
# $dbdir=solid instance root directory
# $dbuser=database user name
# $dbpass=database password
# $dbschema=database schema name
# $dbname=database schema name
# $dbport=database port number
# $dbserver=database server name
# $type=source or target (s/t)
# $start=start database manager (0/1) [manager may already be running]
# create_instance_ids('c:\ids_test','informix','INFORMIX123','informix',
#						'itsTst_db',9088,'INFORMIX_SERVER','s',1)
#
#-----------------------------------------------------------------------
sub create_instance_ids
{
	my $dbdir = shift;
	my $dbuser = shift;
	my $dbpass = shift;
	my $dbschema = shift;
	my $dbname = shift;
	my $dbport = shift;
	my $dbserver = shift;
	my $type = shift;
	my $start = shift;
	my $db_ids;
	

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}

	eval { # Trap errors
    	$db_ids = InformixDB->createSimple($dbuser, $dbpass, $dbdir, $dbserver, $dbname, $dbport, $dbschema);
		if ($start == 1) {
			$db_ids->start();
			$db_ids->createDatabase($db_ids->dbName());
		}
		if ($type eq 's') {
			$db_src = $db_ids;
		} else {
			$db_tgt = $db_ids;
		}
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\ncreate_instance_ids: Errors found: $@\n");
		return 1;
	}
	return 0;
}



#-----------------------------------------------------------------------
# create_instance_cdc_solid($cdc_root,$cdc_name,$cdc_port,$type)
#-----------------------------------------------------------------------
#
# Create and start an instance of CDC for Solid, where:
# $cdc_root=installation directory of cdc solid binary
# $cc_name=cdc name
# $cdc_port=cdc port
# $type=source or target (s/t)
# create_instance_cdc_solid('/home/user/cdcsolid','ts_src',11101,'s')
#
#-----------------------------------------------------------------------
sub create_instance_cdc_solid
{
	my $cdc_root = shift;
	my $cdc_name = shift;
	my $cdc_port = shift;
	my $type = shift || 's';
	my $solid = ($type eq 's' ? $db_src : $db_tgt);
	my $cdc_solid;

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}
	# Store location of cdc for solid binary and update PATH environment variable (second parameter = 1)
	$env->CDCSolidRootDir($cdc_root,1);
	eval { # Trap errors
		$cdc_solid = CDCSolid->createSimple($cdc_name,$cdc_port,$solid);
		# create and start CDC
		$cdc_solid->create();
		$cdc_solid->start();
		# Assign globally as source or target
		if ($type eq 's') {
			$cdc_src = $cdc_solid;
		} else {
			$cdc_tgt = $cdc_solid;
		}
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\ncreate_instance_cdc_solid: Errors found: $@\n"); 
		return 1;
	}
	return 0;
}


#-----------------------------------------------------------------------
# create_instance_cdc_db2($cdc_root,$cdc_solid_root,$cdc_name,$cdc_port,$type)
#-----------------------------------------------------------------------
#
# Create and start an instance of CDC for DB2, where:
# $cdc_root=installation directory of cdc DB2 binary
# $cdc_solid_root=installation directory of cdc Solid binary
# $cdc_name=cdc name
# $cdc_port=cdc port
# $type=source or target (s/t)
# create_instance_cdc_db2('/home/user/cdcdb2','ts_src',11101,'s')
#
#-----------------------------------------------------------------------
sub create_instance_cdc_db2
{
	my $cdc_root = shift;
	my $cdc_solid_root = shift;
	my $cdc_name = shift;
	my $cdc_port = shift;
	my $type = shift || 's';
	my $db2 = ($type eq 's' ? $db_src : $db_tgt);
	my $cdc_db2;

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}
	# Store location of cdc for db2 binary and update PATH environment variable (second parameter = 1)
	$env->CDCDb2RootDir($cdc_root,1);
	# Need to use uc utilities from CDC for Solid also, so store path to this
	$env->CDCSolidRootDir($cdc_solid_root,1);
	eval { # Trap errors
		$cdc_db2 = CDCDb2->createSimple($cdc_name,$cdc_port,$db2);
		# create and start CDC
		$cdc_db2->create();
		$cdc_db2->start();
		# Assign globally as source or target
		if ($type eq 's') {
			$cdc_src = $cdc_db2;
		} else {
			$cdc_tgt = $cdc_db2;
		}
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\ncreate_instance_cdc_db2: Errors found: $@\n"); 
		return 1;
	}
	return 0;
}


#-----------------------------------------------------------------------
# create_instance_cdc_ids($cdc_root,$cdc_solid_root,$cdc_name,$cdc_port,$type)
#-----------------------------------------------------------------------
#
# Create and start an instance of CDC for Informix, where:
# $cdc_root=installation directory of cdc Informix binary
# $cdc_solid_root=installation directory of cdc Solid binary
# $cdc_name=cdc name
# $cdc_port=cdc port
# $type=source or target (s/t)
# create_instance_cdc_ids('/home/user/cdcids','ts_src',11101,'s')
#
#-----------------------------------------------------------------------
sub create_instance_cdc_ids
{
	my $cdc_root = shift;
	my $cdc_solid_root = shift;
	my $cdc_name = shift;
	my $cdc_port = shift;
	my $type = shift || 's';
	my $db_ids = ($type eq 's' ? $db_src : $db_tgt);
	my $cdc_ids;

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}
	# Store location of cdc for Informix binary and update PATH environment variable (second parameter = 1)
	$env->CDCInformixRootDir($cdc_root,1);
	# Need to use uc utilities from CDC for Solid also, so store path to this
	$env->CDCSolidRootDir($cdc_solid_root,1);
	eval { # Trap errors
		$cdc_ids = CDCInformix->createSimple($cdc_name,$cdc_port,$db_ids);
		# create and start CDC
		$cdc_ids->create();
		$cdc_ids->start();
		# Assign globally as source or target
		if ($type eq 's') {
			$cdc_src = $cdc_ids;
		} else {
			$cdc_tgt = $cdc_ids;
		}
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\ncreate_instance_cdc_ids: Errors found: $@\n"); 
		return 1;
	}
	return 0;
}




#-----------------------------------------------------------------------
# init_access_server()
#-----------------------------------------------------------------------
#
# Start access server and create admin user, where:
# $as_port=access server port number
# $as_user=access server user name
# $as_pass=access server password
# $as_root=root directory of accessserver installation
# init_access_server(10101,Admin,admin123,localhost,/home/db2inst1/accessserver)
#
#-----------------------------------------------------------------------
sub init_access_server
{
	my $as_port = shift;
	my $as_user = shift;
	my $as_pass = shift;
	my $as_host = shift;
	my $as_root = shift;
	my $as_cfg;

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}
	# Access server configuration 
	$as_cfg = {ac_host => $as_host,	# Access server host
			 	  ac_port => $as_port,	# Access server port
				  ac_user => $as_user,	# Access server user
				  ac_pass => $as_pass};	# Access server password

	if (!defined($mConsole)) {
		# Create mConsole/Access server instance
		$mConsole = AccessServer->createFromConfig(AccessServerConfig->createFromHash($as_cfg));
	}
	# Store location of access server binary and update PATH environment variable (second parameter = 1)
	$env->accessServerRootDir($as_root,1);
	eval { # Trap errors
		$mConsole->startAccessServer();
		sleep(3);
		$mConsole->createAdminUser();
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\ninit_access_server: Errors found: $@\n"); 
		return 1;
	}
	return 0;
}



#-----------------------------------------------------------------------
# create_datastore($ds_name,$as_port,$as_user,$as_pass,$as_host,$as_root,$type)
#-----------------------------------------------------------------------
#
# Create a datastore and assign a user to it, where:
# $ds_name=datastore name
# $as_port=access server port number
# $as_user=access server user name
# $as_pass=access server password
# $as_root=root directory of accessserver installation
# $type=source or target (s/t)
# create_datastore('ds_src',10101,'admin','admin123','localhost',
#					'/home/db2inst1/accessserver','s')
#
#-----------------------------------------------------------------------
sub create_datastore
{
	my $ds_name = shift;
	my $as_port = shift;
	my $as_user = shift;
	my $as_pass = shift;
	my $as_host = shift;
	my $as_root = shift;
	my $type = shift || 's';
	my ($as_cfg, $ds, $cdc);

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}
	# Store location of access server binary and update PATH environment variable (second parameter = 1)
	$env->accessServerRootDir($as_root,1);

	# Make sure database and cdc have been set up
	if ($type eq 's' && !defined($db_src)) {
		print "[ERROR] Source database not defined.\n";
		return 1;
	} elsif ($type eq 't' && !defined($db_tgt)) {
		print "[ERROR] Target database not defined.\n";
		return 1;
	}
	if ($type eq 's' && !defined($cdc_src)) {
		print "[ERROR] Source cdc not defined.\n";
		return 1;
	} elsif ($type eq 't' && !defined($cdc_tgt)) {
		print "[ERROR] Target cdc not defined.\n";
		return 1;
	}
	$cdc = ($type eq 's' ? $cdc_src : $cdc_tgt);

	eval { # Trap errors

		# Access server configuration 
		$as_cfg = {ac_host => $as_host,	# Access server host
				 	  ac_port => $as_port,	# Access server port
					  ac_user => $as_user,	# Access server user
					  ac_pass => $as_pass};	# Access server password

		if (!defined($mConsole)) {
			# Create mConsole/Access server instance
			$mConsole = AccessServer->createFromConfig(AccessServerConfig->createFromHash($as_cfg));
		}

		# create datastore
		$ds = $mConsole->createDatastoreSimple(
			$ds_name,		# datastore name
			'',	# datastore description
			$as_host,		# datastore host
			$cdc,		# cdc instance
		);
		# Assign globally as source or target
		if ($type eq 's') {
			$mConsole->source($ds);	# assign source datastore
			$ds_src = $ds;
		} else {
			$mConsole->target($ds);	# assign source datastore
			$ds_tgt = $ds;
		}
		$mConsole->assignDatastoreUser($ds);
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\nErrors found: $@\n"); 
		return 1;
	}
	return 0;
}



#-----------------------------------------------------------------------
# create_datastore_remote($ds_name,$as_port,$as_user,$as_pass,$as_host,
# 						  $as_root,$cdc_port,$cdc_host,$cdc_solid_root,
#						  $dbtype,$dbname,$dbuser,$dbpass,$dbport,$dbschema,
#						  $type)
#-----------------------------------------------------------------------
#
# Create a datastore and assign a user to it, where the database and CDC
# instance are already running on a remote machine:
#
# $ds_name=datastore name
# $as_port=access server port number
# $as_user=access server user name
# $as_pass=access server password
# $as_host=access server password
# $as_root=root directory of accessserver installation
# $cdc_port=ts port
# $cdc_host=ts host
# $cdc_solid_root=root directory of solid installation
# $dbtype=database type ('sol', 'db2' or 'ids')
# $dbname=database name
# $dbuser=database user
# $dbpass=database password
# $dbport=database port
# $dbschema=database schema
# $type=source or target (s/t)
# create_datastore('ds_src',10101,'admin','admin123','localhost',
#				   '/home/db2inst1/accessserver','11101','localhost','/home/db2inst1/cdcsolid',
#					'db2','db2name','db2admin','db2admin',50000,'dbschema','t')
#
#-----------------------------------------------------------------------
sub create_datastore_remote
{
	my $ds_name = shift;
	my $as_port = shift;
	my $as_user = shift;
	my $as_pass = shift;
	my $as_host = shift;
	my $as_root = shift;
	my $cdc_port = shift;
	my $cdc_host = shift;
	my $cdc_solid_root = shift;
	my $dbtype = shift;
	my $dbname = shift;
	my $dbuser = shift;
	my $dbpass = shift;
	my $dbport = shift;
	my $dbschema = shift;
	my $dbserver = shift;
	my $type = shift;
	my ($as_cfg, $ds, $cdc,$db);


	# Parameter checking for debug purposes
	print "*****************************************************\nCREATE_DATASTORE_REMOTE (PARAMETERS)\n\n" .
		  "DATASTORE NAME: $ds_name\nACCESS SERVER PORT: $as_port\nACCESS SERVER USER: $as_user\nACCESS SERVER PASS: $as_pass\n" .
		  "ACCESS SERVER HOST: $as_host\nACCESS SERVER ROOT: $as_root\nCDC PORT: $cdc_port\nCDC_HOST: $cdc_host\n" .
		  "CDC SOLID ROOT: $cdc_solid_root\n" .
		  "DATABASE TYPE: $dbtype\nDATABASE NAME: $dbname\nDATABASE USER: $dbuser\nDATABASE PASS: $dbpass\n" .
		  "DATABASE PORT: $dbport\nDATABASE SCHEMA: $dbschema\n" .
		  "TYPE: $type\n******************************************************\n";

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}

	# Store location of access server binary and update PATH environment variable (second parameter = 1)
	$env->accessServerRootDir($as_root,1);
	# Need CDC for Solid path to set access server parameters
	$env->CDCSolidRootDir($cdc_solid_root,1);

	if ($dbtype eq 'db2') {
		$db = Db2DB->createSimple('dir',$dbname,$dbuser,$dbpass,$dbschema);
		$db->dbPort($dbport);
		$cdc = CDCDb2->createSimple('ts_name',$cdc_port,$db);
	} elsif ($dbtype eq 'sol') {
		$db = SolidDB->createSimple('dir',$dbport,'solid.lic');
		$db->dbUser($dbuser);
		$db->dbPass($dbpass);
		$db->dbSchema($dbschema);
		$cdc = CDCSolid->createSimple('ts_name',$cdc_port,$db);
	} elsif ($dbtype eq 'ids') {
    	$db = InformixDB->createSimple($dbuser, $dbpass, '/ids_test', $dbserver, $dbname, $dbport, $dbschema);
		$cdc = CDCInformix->createSimple('ts_name',$cdc_port,$db);
	}
	# Set globals
	if ($type eq 's') {
		$db_src = $db;
		$cdc_src = $cdc;
	} else {
		$db_tgt = $db;
		$cdc_tgt = $cdc;
	}

	eval { # Trap errors

		# Access server configuration 
		$as_cfg = {ac_host => $as_host,	# Access server host
				 	  ac_port => $as_port,	# Access server port
					  ac_user => $as_user,	# Access server user
					  ac_pass => $as_pass};	# Access server password

		if (!defined($mConsole)) {
			# Create mConsole/Access server instance
			$mConsole = AccessServer->createFromConfig(AccessServerConfig->createFromHash($as_cfg));
		}

		# create datastore
		$ds = $mConsole->createDatastoreSimple(
			$ds_name,		# datastore name
			'',	# datastore description
			$cdc_host,		# datastore host
			$cdc,		# cdc instance
		);
		# Assign globally as source or target
		if ($type eq 's') {
			$mConsole->source($ds);	# assign source datastore
			$ds_src = $ds;
		} else {
			$mConsole->target($ds);	# assign source datastore
			$ds_tgt = $ds;
		}
		$mConsole->assignDatastoreUser($ds);
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\nErrors found: $@\n"); 
		return 1;
	}
	return 0;
}



#-----------------------------------------------------------------------
# replication($stype,$ttype,$subname,$sqlpath)
#-----------------------------------------------------------------------
#
# Create subscription and start a mapping between source and target
# datastores, where:
# $stype=source type ('sol', 'db2' or 'ids')
# $ttype=target type ('sol', 'db2' or 'ids')
# $subname=subscription name
# $sqlpath=location of sql files
#
# e.g. replication('sol','db2','subname','/home/user/test/sql')
#-----------------------------------------------------------------------
sub replication
{
	my $source = shift;
	my $target = shift;
	$subname = shift;
	my $sqlpath = shift;
	my $ps;

	if (!defined($env)) {
		print "[ERROR] Environment not initialised.\n";
		return 1;
	}
	if (!defined($mConsole)) {
		print "[ERROR] mConsole not initialised.\n";
		return 1;
	}
	# Set source = target for now
	if (!defined($db_src) and !defined($db_tgt)) {
		print "[ERROR] Neither source nor target database has been initialised.\n";
		return 1;
	}
	if (defined($db_src)) {
		$db_tgt = $db_src;
	} else {
		$db_src = $db_tgt;
	}
	if (!defined($ds_src) and !defined($ds_tgt)) {
		print "[ERROR] Neither source nor target datastore has been initialised.\n";
		return 1;
	}
	if (defined($ds_src)) {
		$ds_tgt = $ds_src;
	} else {
		$ds_src = $ds_tgt;
	}
	$mConsole->source($ds_src);
	$mConsole->target($ds_tgt);



	# if (!defined($db_src)) {
	# 	print "[ERROR] Source databse not initialised.\n";
	# 	return 1;
	# }
	# if (!defined($db_tgt)) {
	# 	print "[ERROR] Target database not initialised.\n";
	# 	return 1;
	# }
	$ps = $env->getPathSeparator();
	eval {
		$db_src->dbTableName('src');
		$db_src->execSql("${sqlpath}${ps}${source}_createsrc.sql"); # Create table 'src'
		$db_tgt->dbTableName('tgt');
		$db_tgt->execSql("${sqlpath}${ps}${target}_createtgt.sql"); # Create table 'tgt'

		$mConsole->createSubscription($subname); # Create subscription between source and target datastores
		$mConsole->addMapping($subname,uc($db_src->dbSchema()).'.SRC',uc($db_tgt->dbSchema()).'.TGT'); # Add default mapping to subscription
		$mConsole->startMirroring($subname); # Start mirroring

		sleep(5);
		$db_src->dbTableName('src');
		$db_src->execSql("${sqlpath}${ps}${source}_insertsrc.sql"); # Insert rows into source table
		sleep(15); # Allow mirroring to take effect
		$db_tgt->dbTableName('tgt');
		$db_tgt->execSql("${sqlpath}${ps}${target}_readtgt.sql"); # Read target table
	};
	if ($@) { # Errors occurred
		Environment::logf("\n\nErrors found: $@\n");
		return 1;
	}
	return 0;
}


#-----------------------------------------------------------------------
# cleanup()
#-----------------------------------------------------------------------
#
# Delete datastores/cdc instances and shutdown services started
#
#-----------------------------------------------------------------------
sub cleanup
{
	# Delete datastores
	if (defined($mConsole)) {
		if (defined($subname)) {
			$mConsole->stopMirroring($subname);
			$mConsole->deleteMapping($subname);
			$mConsole->deleteSubscription($subname);
		}
		$mConsole->deleteDatastore($ds_tgt) if (defined($ds_tgt));
		$mConsole->deleteDatastore($ds_src) if (defined($ds_src));
		$mConsole->stopAccessServer();
	}

	# stop and delete cdc instances
	if (defined($cdc_src)) {
		$cdc_src->stop();
		$cdc_src->delete();
	}
	if (defined($cdc_tgt)) {
		$cdc_tgt->stop();
		$cdc_tgt->delete();
	}

	# shut down databases
	$db_src->stop() if (defined($db_src));
	$db_tgt->stop() if (defined($db_tgt));

	return 0;
}



