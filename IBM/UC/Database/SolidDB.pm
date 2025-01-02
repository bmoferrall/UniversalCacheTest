########################################################################
# 
# File   :  SolidDB.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# SolidDB.pm is a sub-class of Database.pm.
# It provides routines to create and interact with a SolidDB database
# It can also be used to connect with an existing SolidDB database 
# (either remote or local) and interact with it
# 
########################################################################
package SolidDB;

use strict;

use IBM::UC::Database;
use File::Path;
use File::Copy;
use File::Basename;
use Cwd;
use UNIVERSAL qw(isa);

our @ISA = qw(Database); # database super class



#-----------------------------------------------------------------------
# $ob = SolidDB->createSimple([$db_dir,$db_port,$lic_file])
#-----------------------------------------------------------------------
#
# Create solid object using fixed order parameters
# All parameters are optional, but those present must be in the correct order
# $db_dir is created if it doesn't exist, $db_port is the database port, 
# $lic_file is the licence filename and its location (if left out the value
# specified in Environment.pm is used as a default).
# e.g. $ob = SolidDB->createSimple('/home/user/solid/src',2315,'./solid.lic')
#
#-----------------------------------------------------------------------
sub createSimple
{
	my $class = shift;
	my $dbdir = shift; # database directory
	my $dbport = shift; # database port
	my $dblic = shift; # solid licence file name+location

	my $self = $class->SUPER::new();

	bless $self, $class;

	$self->init(); # set defaults

	# override defaults with parameters passed
	if (defined($dblic)) { $self->licenceName($dblic); }
	if (defined($dbport)) { $self->dbPort($dbport); }
	if (defined($dbdir)) { $self->dbDir($dbdir); }

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");

	# Make sure dbDir has a full path and ends with path separator
	$self->setDbDirPath($self->dbDir());
	
	return $self;
}


#-----------------------------------------------------------------------
# $ob = SolidDB->createComplex($refParam)
#-----------------------------------------------------------------------
#
# Create solid object using variable order parameters passed as a hash 
# reference
# See POD for allowed parameter names and their default values
# e.g. $ob = SolidDB->createComplex({db_dir => '/home/user/solid/sol_tgt', db_port => 2317})
#
#-----------------------------------------------------------------------
sub createComplex
{
	my $class = shift;
	my $refParam = shift; # hash ref with name/value pairs

	my $self = $class->SUPER::new();

	bless $self, $class;

	$self->init(); # set defaults

	if (!defined($refParam) or (ref($refParam) ne 'HASH')) {
		Environment::fatal("SolidDB::createComplex: expecting hash reference as parameter\nExiting...\n");
	} else {
		# override defaults with parameters passed
		$self->getConfig()->initFromConfig($refParam);
	}
	
	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");

	# Make sure dbDir has a full path and ends with path separator
	$self->setDbDirPath($self->dbDir());

	return $self;
}


#-----------------------------------------------------------------------
# $ob = SolidDB->createFromConfig($config)
#-----------------------------------------------------------------------
#
# Create solid object using DatabaseConfig object which is essentially a hash
# of parameter name/value pairs.
# See POD for allowed parameter names and their default values
# $config_values = { db_port => 2317, db_dir => '/home/user/solid/sol_tgt' }
# e.g. $ob = SolidDB->createComplex(DatabaseConfig->createFromHash($config_values))
#
#-----------------------------------------------------------------------
sub createFromConfig
{
	my $class = shift;
	my $config = shift;
	my $self = $class->SUPER::new();

	bless $self, $class;

	$self->init();	

	# override defaults with parameters passed
	if (ref($config) eq 'DatabaseConfig') {
		$self->getConfig()->initFromConfig($config->getParams());	
	} else {
		Environment::fatal("SolidDB::createFromConfig: config parameter not of type \"DatabaseConfig\"\n");
	}

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");

	# Make sure dbDir has a full path and ends with path separator
	$self->setDbDirPath($self->dbDir());
	
	return $self;
}


#-----------------------------------------------------------------------
# $ob = SolidDB->createFromFile($ini)
#-----------------------------------------------------------------------
#
# Create solid object using configuration info from ini file (in the form
# of name=value records).
# See POD for allowed parameter names and format of the ini file
# e.g. $ob = SolidDB->createFromFile('solid_instance1.ini')
#
#-----------------------------------------------------------------------
sub createFromFile
{
	my $class = shift;
	my $ini = shift;
	my $self = {};

	# Check that param was passed and that file exists 
	if (defined($ini) && -f $ini) { # Call super class constructor
		$self = $class->SUPER::new($ini);
	} else {
		Environment::fatal("SolidDB::createFromFile needs valid *.ini file as input\nExiting...\n");
	}

	bless $self, $class;

	$self->init();	

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");

	# Make sure dbDir has a full path and ends with path separator
	$self->setDbDirPath($self->dbDir());
	
	return $self;
}



#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise solidDB instance, including asssigning default values and calling
# super class version of init()
#
#-----------------------------------------------------------------------
sub init
{
	my $self = shift;
	
	# Make sure we only initialise once,
	#    in case a user explicitly calls what is intended to be a private method
	if (!$self->initialised()) {
		# Add solid installation dir to environment path
		$self->getEnv()->solidRootDir($self->getEnv()->solidRootDir(),1);
		# Initialise some config parameters to default values
		$self->getConfig()->initFromConfig({db_inst => 'dba_src',
											db_dir => $self->getEnv()->getStartDir() . 'sol_src',
											db_dir_clean => 'yes',
											db_name => 'dba',
											db_host => 'localhost',
											db_port => 2315,
											db_user => 'dba',
											db_pass => 'dba',
											db_schema => 'dba',
											db_sql_output => 'sqloutput.log',
											solid_lic => $self->getEnv()->solidLicenceFile(),
											solid_ini_template => 'solid_template.ini',
											solid_db_inmemory => 'no'});

		# invoke super class' initialiser
		$self->SUPER::init();
		$self->initialised(1);
	}
}


#-----------------------------------------------------------------------
# $ob->createStorage()
#-----------------------------------------------------------------------
#
# Sets up directory structure and copies files according to configuration
# info supplied during object's creation
# Optionally deletes existing storage before re-creating
#
#-----------------------------------------------------------------------
sub createStorage
{
	my $self = shift;
	my $ps = $self->getEnv()->getPathSeparator();
	my $cwd = $self->getEnv()->getStartDir();
	my ($f,$p) = ();

	if (lc($self->dbDirClean()) eq 'yes') {
		$self->cleanStorage();
	}

	# create database directory
	if (!(-d $self->dbDir())) {
		Environment::logf(">> Creating " . $self->dbDir() . "...\n");
		mkpath($self->dbDir());
	}
	chdir($self->dbDir());

	# create the logs directory
	mkpath($self->dbDir() . "logs");
		
	# create the solid ini file (if it doesn't already exist)
	if (lc($self->dbDirClean()) eq 'yes' ||
		(lc($self->dbDirClean()) eq 'no' && (!-f $self->dbDir() . 'solid.ini'))) {
		$self->createIniFile();
	}
	
	# copy the license file
	# first check if path was specified by user
	($f,$p) = File::Basename::fileparse($self->licenceName());
	$p = length($p)>2 ? $p : $cwd;
	# Leave existing licence file if dbDirClean() option was 'no'
	if (lc($self->dbDirClean()) eq 'no' && (-f $self->dbDir() . 'solid.lic')) {
	} elsif (-f $p . $f) {
		File::Copy::cp($p.$f, $self->dbDir());
	} else {
		Environment::fatal("SolidDB::createStorage: Cannot find licence file \"$f\" in \"$p\"\nExiting...\n");
	}
	chdir($cwd);
}


#-----------------------------------------------------------------------
# $ob->cleanStorage()
#-----------------------------------------------------------------------
#
# Delete existing database storage
#
#-----------------------------------------------------------------------
sub cleanStorage
{
	my $self = shift;


	if (-d $self->dbDir()) {
		Environment::logf(">> Removing " . $self->dbDir() . "...\n");
		File::Path::rmtree($self->dbDir(),0,1);
	}
}


#-----------------------------------------------------------------------
# $ob->start()
#-----------------------------------------------------------------------
#
# Calls createStorage(), creates a new solid database listening on the
# port specfied during the object's creation
#
#-----------------------------------------------------------------------
sub start
{
	my $self = shift;
	my $dir = $self->dbDir();
	my $command;
	# solid needs to be explicitly started in background on windows
	my $bg = ($self->getEnv()->getOSName() eq 'windows') ? "start /b " : "";
	my $pd = ($self->getEnv()->getOSName() eq 'windows') ? '.' : '';

	$self->createStorage();

	$command = $bg . "solid -c\"" . $dir . "${pd}\" -U" . $self->dbUser() .
				" -P" . $self->dbPass() . " -C" . $self->dbSchema();
	Environment::logf("\n>> Starting solid for port " . $self->dbPort() . " ...\n");
	Environment::logf(">> COMMAND: $command\n");
	system($command) and Environment::fatal("Error occurred in SolidDB::start\n");
	sleep(15); # give command enough time to complete
	Environment::logf(">> Done.\n");
}


#-----------------------------------------------------------------------
# $ob->stop()
#-----------------------------------------------------------------------
#
# Shuts down the solid database
#
#-----------------------------------------------------------------------
sub stop
{
	my $self = shift;
	my $command;
	
	$command = "solcon \"-e shutdown\" \"tcpip " . $self->dbPort() . "\" " .
				$self->dbUser() . " " . $self->dbPass();
	Environment::logf("\n>> Shutting down solid for " . $self->instanceName() . "...\n");
	Environment::logf(">> COMMAND: $command\n");
	system($command) and Environment::logf("Error occurred in SolidDB::stop\n");
	Environment::logf(">> Done.\n");
}


#-----------------------------------------------------------------------
# $ob->execSql($input)
#-----------------------------------------------------------------------
#
# Execute batch sql statements from a file
# $input is an sql filename (if no path is specified it is assumed
# to be in the start directory).
# e.g.
# $ob->execSql('/home/user/solid/create_src.sql');
#
#-----------------------------------------------------------------------
sub execSql
{
	my $self = shift;
	my $sql = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();
	my $dir = $self->dbDir();
	my $null = ($self->getEnv()->getOSName() eq 'windows') ? ' > null' : ' > /dev/null';
	my $pd = ($self->getEnv()->getOSName() eq 'windows') ? '.' : '';

	if (!defined($sql)) {
		Environment::fatal("SolidDB::execSql: No parameter specified (0, 1, or filename)\n");
	} else {
		# If path not supplied assume start directory and copy to db directory
		my ($f,$p) = File::Basename::fileparse($sql);
		$p = length($p)>2 ? $p : $self->getEnv()->getStartDir();
		File::Copy::cp($p.$f, $dir);
		$sql = $f;
	}
	
	chdir($dir);

	unless (-f $sql) { Environment::fatal("SolidDB::execSql:: Cannot find sql input \"$dir$sql\"\nExiting...\n"); }
	$self->prepareSqlFile($sql);
	$command = "solsql -a -c\"" . $dir . "${pd}\" -f\"" . $sql . "\" -O\"" .
				$self->dbSqlOutputFile() . "\" \"tcp " . $self->dbHost() . ' ' .
				$self->dbPort() . "\" " . $self->dbUser() . " " . $self->dbPass() . $null;	
	Environment::logf("\n>> COMMAND: $command\n");
	system($command) and Environment::logf("Error occurred in SolidDB::execSql\n");
	unlink('null'); # null used to suppress output
	Environment::logf(">> Done. Check " . $dir . $self->dbSqlOutputFile() . " for output\n");

	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->execSqlStmt($sql)
#-----------------------------------------------------------------------
#
# Execute single sql statements against the database
# e.g.
# $sql = 'select * from src';
# $ob->execSqlStmt($sql);
#
#-----------------------------------------------------------------------
sub execSqlStmt
{
	my $self = shift;
	my $sqlstr = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $dir = $self->dbDir();
	my $null = ($self->getEnv()->getOSName() eq 'windows') ? ' > null' : ' > /dev/null';

	chdir($dir);

	if (defined($sqlstr)) { # execute sql string specified by user
		$command = "solsql -a -e\"" . $sqlstr . "\" -O\"" .
					$self->dbSqlOutputFile() . "\" \"tcp " . $self->dbHost() . ' ' . 
					$self->dbPort() . "\" " . $self->dbUser() . " " . $self->dbPass() . $null;
		Environment::logf("\n>> COMMAND: $command\n");
		system($command) and Environment::logf("Error occurred in SolidDB::execSqlStmt\n");
		unlink('null'); # null used to suppress output
		Environment::logf(">> Done. Check " . $dir . $self->dbSqlOutputFile() . " for output\n");
	}
	chdir($savecwd);
}



#-----------------------------------------------------------------------
# $ob->createIniFile()
#-----------------------------------------------------------------------
#
# Generate solid.ini file
# Will look for template file in start directory (name specified by 
# config parameter solid_ini_template) and generate ini from it.
# If the template file isn't found solid.ini is generated
#
#-----------------------------------------------------------------------
sub createIniFile
{
	my $self = shift;
	my $cwd = $self->getEnv()->getStartDir();
	my $contents;
	# If template path not supplied assume start directory
	my ($f,$p) = File::Basename::fileparse($self->templateName());
	$p = length($p)>2 ? $p : $cwd;
	$p .= $f;


	# If template can be found use it
	if (-f $p) {
		open(INIFILE, '<', $p) || 
		Environment::fatal("Couldn't open \"" . $p . "\": $!\n");
		$contents = join("",<INIFILE>);
		close(INIFILE);
		$contents =~ s/<_port_>/$self->dbPort()/eg;
		$contents =~ s/<_inmem_>/$self->inMemoryDatabase()/eg;

		# Make sure correct communication line is uncommented
		#    (all lines are assumed to be commented out initially)
		if ($self->getEnv()->getOSName() eq 'windows') {
			# ;Listen=tcpip 2315, nmpipe SOLID	; Windows
			$contents =~ s/^(;)(Listen=tcpip.*?nmpipe.*?Windows).*?$/$2/m;
		} else { # Assume unix
			$contents =~ s/^(;)(Listen=tcpip.*?Unix).*?$/$2/m;
		}
	} else { # otherwise create ini from scratch using defaults
		$contents = "[Data Sources]\nsolidDB_local=tcp " . $self->dbPort() . 
			    ", tcp 1315, Local eval db connection\n\n";
		if ($self->getEnv()->getOSName() eq 'windows') {
			$contents .= "[Com]\nListen=tcpip " . $self->dbPort() . ", nmpipe SOLID\n\n";
		} else {
			$contents .= "[Com]\nListen=tcpip " . $self->dbPort() . ", upipe SOLID\n\n";
		}
		$contents .= "[General]\nDefaultStoreIsMemory=no\nCheckPointDeleteLog=yes\n\n";
		$contents .= "[IndexFile]\nFileSpec_1=solid.db 1000M\nBlockSize=16K\n\n";
		$contents .= "[Logging]\nLogDir=logs\nDurabilityLevel=3\n\n";
		$contents .= "[LogReader]\nLogReaderEnabled=yes\n\n";
		$contents .= "[MME]\n\n[Sorter]\n\n";
		$contents .= "[SQL]\nIsolationLevel=3\nCharpadding=yes\nNumericPadding=yes\n";
	}

	chdir($self->dbDir());
	open(INIFILE, ">solid.ini");
	print INIFILE $contents . "\n";
	close(INIFILE);
	chdir($cwd);
}


#-----------------------------------------------------------------------
# SolidDB->install([$install_to,$install_from])
# SolidDB::install([$install_to,$install_from])
#-----------------------------------------------------------------------
#
# Install solidDB from server to local machine
# You can optionally provide the destination path of the install and
# the name (and path) of the installation package to install. These
# parameters will override the defaults set in the Environment package
# Routine also updates the environment PATH with the 'bin' directory
# in the destination folder
# e.g.
# SolidDB->install()
# SolidDB->install('/home/user/solid','/mnt/msoftware/solid/solid-6.5.bin')
#
#-----------------------------------------------------------------------
sub install
{
	my $install_to;
	my $install_from;
	my $response_file = "response.ini";
	my $contents;
	my $command;
	my $ps = Environment::getEnvironment()->getPathSeparator();
	my $es = Environment::getEnvironment()->getEnvSeparator();
	my ($f,$p);

	# If sub was called via SolidDB->install rather than SolidDB::install, perl will silently
	# pass class name as first parameter
	if (@_ && ($_[0] eq 'SolidDB')) { shift; }
	($install_to,$install_from) = @_;
		
	$install_from = Environment::getEnvironment()->solidPackage() if (!defined($install_from));
	$install_to = Environment::getEnvironment()->solidRootDir() if (!defined($install_to));
	# Make sure path ends with path separator
	$install_to .= $ps if (substr($install_to,-1,1) !~ m/[\/\\]/);

	($f,$p) = File::Basename::fileparse($install_from);
	Environment::fatal("Cannot find install file \"$p$f\"\nExiting...\n") if (!(-f $p.$f));
	File::Path::rmtree($install_to,0,1);
	mkpath($install_to);

	# Set SolidDB path in environment module
	Environment::getEnvironment()->solidRootDir($install_to);
	# Add installation bin directory to environment path variable
	$ENV{'PATH'} = $install_to . 'bin' . $es . $ENV{'PATH'};

	# Needs double back-slashes in response file
	if (Environment::getEnvironment()->getOSName() eq 'windows') { $install_to =~ s/\\/\\\\/g; }

	chdir(Environment::getEnvironment()->getStartDir());
	File::Copy::cp($p.$f, $f);
	chmod(0755,$f) if (Environment::getEnvironment()->getOSName() ne 'windows');
	$contents = "LICENSE_ACCEPTED=TRUE\n";
	$contents .= "INSTALLER_UI=silent\n";
	$contents .= "USER_INSTALL_DIR=$install_to\n";
	$contents .= "CHOSEN_INSTALL_FEATURE_LIST=Server,ODBC,Samples\n";
	# Need this line for windows (need double back-slashes)
	if (Environment::getEnvironment()->getOSName() eq 'windows') {
		$contents .= "USER_SHORTCUTS=C:\\\\Documents and Settings\\\\Administrator\\\\Start Menu\\\\Programs\\\\solid";
	}
	open(OUT, ">$response_file") or Environment::fatal("SolidDB::install: Cannot write to \"$response_file\": $!\n");
	print OUT $contents . "\n";
	close(OUT);

	$command = ".$ps$f -f $response_file";
	Environment::logf("\n>>Installing SolidDB in $install_to\n");
	system($command) and Environment::logf("Error occurred in SolidDB::install\n");
	unlink($f);
}



#############################################################
# GET/SET METHODS
#############################################################

#-----------------------------------------------------------------------
# $lic = $ob->licenceName()
# $ob->licenceName('solid.lic')
#-----------------------------------------------------------------------
#
# Get/set solid licence name (can include path)
#
#-----------------------------------------------------------------------
sub licenceName
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'solid_lic'} = $name if defined($name);
	return $self->getConfigParams()->{'solid_lic'};
}


#-----------------------------------------------------------------------
# $ini = $ob->templateName()
# $ob->templateName('solid_template.ini')
#-----------------------------------------------------------------------
#
# Get/set name of solid.ini template file name
#
#-----------------------------------------------------------------------
sub templateName
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'solid_ini_template'} = $name if defined($name);
	return $self->getConfigParams()->{'solid_ini_template'};
}


#-----------------------------------------------------------------------
# $yesno = $ob->inMemoryDatabase()
# $ob->inMemoryDatabase('yes')
#-----------------------------------------------------------------------
#
# Get/set flag specifying whether to create in-memory database rather
# than disk-based one
#
#-----------------------------------------------------------------------
sub inMemoryDatabase
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'solid_db_inmemory'} = $name if defined($name);
	return $self->getConfigParams()->{'solid_db_inmemory'};
}


1;


=head1 NAME

SolidDB - 'Database' sub-class for implementing SolidDB-specific functionality

=head1 SYNOPSIS

use IBM::UC::Database::SolidDB;

######################################
#           class methods            #
######################################

 $ob = SolidDB->createSimple([$dbdir,$dbport,$dblic])
  where:
   $dbdir=database directory
   $dbport=port number for database (optional parameter)
   $dblic=name of solid licence file (optional parameter)

 All parameters are optional, but those present must be in the specified order. Parameters not specified
 all get default values

 $ob = SolidDB->createComplex($hash_map)
  where:
   $hash_map=hash map of parameter name/value pairs (see below for examples)

 $ob = SolidDB->createFromConfig($config)
  where:
   $config=object of class DatabaseConfig (see below for examples)

 $ob = SolidDB->createFromFile($ini)
  where:
   $ini=configuration file

 See below for examples of all the above.

 SolidDB->install([i_to,i_from]) (or SolidDB::install)
  Class method to install solid db where:
   i_to (optional) specifies the installation directory
   i_from (optional) specifies the name and path of the package to install
   Both parameters are defaulted in the environment module

######################################
#         object data methods        #
######################################

### get versions ###

 $lic = $ob->licenceName()        # Name of solidDb licence file
 $temp = $ob->templateName()      # Name of solidDb initialisation file
 $inmem = $ob->inMemoryDatabase() # In-memory rather than disk-based database

 See 'Database' module for remaining get methods

### set versions ###

 See 'Database' module for all available set methods

######################################
#        other object methods        #
######################################

 $ob->start();			Creates directories and copy files as necessary,
		        	starts SolidDB database manager and creates solid database
 $ob->stop();           	Shuts down database manager
 $ob->execSql(file);	Executes batch sql statements from file
				(if no path is specified the current directory is assumed)
				%DB% and %TABLE% can be used as placeholders for dbName() and dbTableName()
 $ob->execSqlStmt(sql)		Executes single sql statement

=head1 DESCRIPTION

The SolidDB module is a sub-class of the Database super-class. Its purpose is to implement functionality
specific to Solid databases: create a Solid database and associated storage, launch the Solid database 
manager, execute sql commands and, finally, shut down the database manager.

Initialisation of the database object's data can be done in several ways. Default values are used for 
object parameters not explicitly specified in the object's creation.

Valid configuration parameters and their default values follow (see DatabaseConfig.pm):

 ---------------------------------------------------------------------------------------------------------
 Parameter		Description					Default value
 ---------------------------------------------------------------------------------------------------------
 db_inst		Database instance name				dba_src
 db_dir			Database directory name				current directory + sol_src
 db_dir_clean		delete directory contents first (yes/no)	yes
 db_name		Database name					dba
 db_host		Database host					localhost
 db_port		Database port					2315
 db_user		User name to access database			dba
 db_pass		Password for access to database			dba
 db_schema		Schema name					DBA
 db_sql_output		File where sql output is redirected		sqloutput.log
 solid_lic		Solid licence file/location			Value taken from Environment.pm
 solid_ini_template	Template to use in generating solid.ini		solid_template.ini (curr dir)
			Placeholders <_port_> and <_inmem_> will be
			replaced with db_port and solid_db_inmemory
			If not provided a default version of solid.ini
			is generated			
 solid_db_inmemory	Specify whether to create in-memory database	no
 ---------------------------------------------------------------------------------------------------------

if initialisation is via a configuration ini file the Database section must, by default, start with [DATABASE]
and end with [/DATABASE] or end of file, e.g.:

 [DATABASE]

 ; Database Instance name
 db_inst=dba_src

 ; Database path
 db_dir=/home/db2inst1/automation_workspace/Nightlies/sol_src

 ; Specify whether to delete db_dir and its contents at startup (yes|no)
 db_dir_clean=yes

 ; Host name where database is located
 db_host=localhost

 ; Communication port for database
 db_port=2315 

 ; name of database to be created
 db_name=Solid
 .
 .
 .
 etc.


=head1 EXAMPLES

Following are examples demonstrating the different ways a SolidDB object can be created:

 # Create database object from zero or more fixed order parameters
 # Parameters are all optional but those present must be in correct order
 # Parameters not included in the list get default values 
 sub create_simple
 {
 	# Parameters: database directory, port number, solid licence file
	my $source = SolidDB->createSimple('/tmp/src',2318,'mysolid.lic');
	$source->printout(); # verify contents of object

	# As these parameters are optional you could just call:
	$source = SolidDB->createSimple();
	$source->printout();
	# Default values will be assigned to all parameters in this case

	# If you provide less than 4 parameters they must be in the correct order
	$source = SolidDB->createSimple('/tmp/src');
	$source->printout();
	return $source;
 }

 # Create database object from hash map. Any number of valid parameter names can be used
 # If a parameter name isn't recognised the program aborts and prints a full list of valid parameters
 # As before, default values are assigned to parameters not explicitly specified
 sub create_complex
 {
	my $source = SolidDB->createComplex({db_port => '2319', db_dir => '/home/db2inst1/solid/src',
					     db_name => 'test', db_user => 'user', db_pass => 'mypass',
					     db_schema => 'myschema'});
	$source->printout();
	return $source;
 }


 # Create config object from hash map and use it to create solid database object
 sub create_from_config
 {
	my $cfg_values = { 
		db_port => '2317', 
		db_dir => '/home/db2inst1/solid/sol_tgt',
	};
	my $source = SolidDB->createFromConfig(DatabaseConfig->createFromHash($cfg_values));
	$source->printout();
	return $source;
 }


 # Create config object from configuration file and use it to create database object
 sub create_from_config_ini
 {
	my $ini = shift;
	my $sol_cfg = DatabaseConfig->new($ini);

	$sol_cfg->initFromConfigFile();
	my $source = SolidDB->createFromConfig($sol_cfg);
	$source->printout();
	return $source;
 }


 # Create database object directly from configuration file
 sub create_from_file
 {
	my $ini = shift;
	my $source = SolidDB->createFromFile($ini);
	$source->printout();
	return $source;
 }

A typical sequence of calls to create a SolidDB instance, start solid database manager, 
execute sql and shut down the manager would be:

 sub create_and_run_solid
 {
	# Initialise environment
	my $env_cfg_vals = {
		smtp_server => 'D06DBE01',
		cdc_solid_root_dir => '/home/user/Transformation Server for solidDB',
		testbed_head_dir => '/home/user/workspace/TestBed_HEAD/',
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_cfg_vals));
	
	my $cfg_values = { 
		db_port => '2317', 
		db_dir => '/home/db2inst1/solid/sol_tgt',
	};
	my $source = SolidDB->createFromConfig(DatabaseConfig->createFromHash($cfg_values));

	$source->start();
	# Set table name for sql file, %TABLE% placeholder in *.sql file will be replaced by it	
	$source->dbTableName('src');
	$source->execSql('sol_createsrc.sql');
	my $sql = "insert into src values (val1,val2,val3)";
	$source->execSqlStmt($sql);
	$source->execSql('sol_insertsrc.sql'); 
	$source->stop();
 }

An example of automating the creation of source and target databases, setting up replication between
tables in the databases and verifying that replication has taken place would be as follows:

 # Create subscription and mirror between Solid source and Solid target
 sub replication_sol_to_sol
 {
	my $inp;
	my ($env_parms,$dbvals_src,$dbvals_tgt);
	my ($db_src, $db_tgt);
	my ($cdc_src, $cdc_tgt);
	my ($as_cfg, $mConsole);
	my ($ds_src, $ds_tgt);
	my $sub = 'subname';

 eval { # trap errors so we can clean up before exiting

	$env_parms = {
		debug => 1,
		smtp_server => 'D06DBE01',
		cvs_user => 'dmbuild',
		cvs_pass => 'dmbuild',
		cvs_repository => ':pserver:dmbuild:dmbuild@dmccvs.torolab.ibm.com:/home/cvsuser/cvsdata',
		cvs_home => '/home/db2inst1/cvs',
		cvs_tag => 'HEAD',
		cdc_solid_root_dir => '/home/db2inst1/Transformation Server for solidDB/',
		ant_version => 'apache-ant-1.6.2',
		solid_root_dir => '/home/db2inst1/soliddb-6.5/',
		solid_licence_file => '/home/db2inst1/automation_workspace/Nightlies/solid.lic',
		java_home => '/home/DownloadDirector/ibm-java2-i386-50/',
		java6_home => '/home/DownloadDirector/ibm-java-i386-60/',
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));

	# create and start source database
	$dbvals_src = { 
		db_port => '2315', 
		db_dir => '/home/db2inst1/solid/sol_src',
	};
	$db_src = SolidDB->createFromConfig(DatabaseConfig->createFromHash($dbvals_src));
	$db_src->start();

	# create and start target database
	$dbvals_tgt = { 
		db_port => '2316', 
		db_dir => '/home/db2inst1/solid/sol_tgt',
	};
	$db_tgt = SolidDB->createFromConfig(DatabaseConfig->createFromHash($dbvals_tgt));
	$db_tgt->start();

	# Set source and target table names for sql files
	# %TABLE% in sql files will be replaced with table names specified here
	$db_src->dbTableName('src');
	$db_tgt->dbTableName('tgt');
	$db_src->execSql('sol_createsrc.sql');	# Create table 'src'
	$db_tgt->execSql('sol_createtgt.sql');	# Create table 'tgt'
	
	# create source CDC
	$cdc_src = CDCSolid->createSimple('solsrc_ts',11101,$db_src);

	# create target CDC
	$cdc_tgt = CDCSolid->createSimple('soltgt_ts',11102,$db_tgt);

	# create and start source/target cdc's
	$cdc_src->create();
	$cdc_tgt->create();
	$cdc_src->start();
	$cdc_tgt->start();

	# Access server configuration 
	$as_cfg = {ac_host => 'localhost',	# Access server host
			 	  ac_port => '10101',	# Access server port
				  ac_user => 'Admin',	# Access server user
				  ac_pass => 'admin123'};	# Access server password
	
	# Create mConsole/Access server instance
	$mConsole = AccessServer->createFromConfig(AccessServerConfig->createFromHash($as_cfg));

	# create datastores
	$ds_src = $mConsole->createDatastoreSimple(
		'solsrc_ds',		# datastore name
		'Source datastore',	# datastore description
		'localhost',		# datastore host
		$cdc_src,		# cdc instance
	);
	$ds_tgt = $mConsole->createDatastoreSimple(
		'soltgt_ds',		# datastore name
		'Target datastore',	# datastore description
		'localhost',		# datastore host
		$cdc_tgt,		# cdc instance
	);
	$mConsole->source($ds_src);	# assign source datastore
	$mConsole->target($ds_tgt);	# assign target datastore
	
	$mConsole->assignDatastoreUser($ds_src);
	$mConsole->assignDatastoreUser($ds_tgt);

	$mConsole->createSubscription($sub);	# Create subscription between source and target datastores
	$mConsole->addMapping($sub);        	# Add default mapping to subscription
	$mConsole->startMirroring($sub);    	# Start mirroring

	$db_src->execSql('sol_insertsrc.sql');	# Insert rows into source table
	sleep(15);				# Allow mirroring to take effect
	$db_tgt->execSql('sol_readtgt.sql');	# Read target table

 };

 # Error thrown in eval {...}
 if ($@) { Environment::logf("\n\nErrors found: $@\n"); }

	# CLEANUP

	$mConsole->stopMirroring($sub);     	# Stop mirroring
	$mConsole->deleteMapping($sub);     	# Delete mapping
	$mConsole->deleteSubscription($sub);	# Delete subscription

	# Delete datastores
	$mConsole->deleteDatastore($ds_tgt);
	$mConsole->deleteDatastore($ds_src);

	# stop and delete cdc instances
	$cdc_src->stop();
	$cdc_tgt->stop();
	$cdc_src->delete();
	$cdc_tgt->delete();

	# shut down databases
	$db_src->stop();
	$db_tgt->stop();
 }

If everything works as expected source and target tables should have the same content.

=cut
