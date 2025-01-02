########################################################################
# 
# File   :  Environment.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# Environment.pm encapsulates common configuration parameters associated
# with the host computer's environment
# 
########################################################################
package Environment;

use strict;

use Cwd;
use Carp;
use Data::Dumper;
use IBM::UC::UCConfig::EnvironmentConfig;
use Config;
use POSIX qw(strftime);

my ($environment) = (undef);


#-----------------------------------------------------------------------
# $ob = Environment->getEnvironment()
#-----------------------------------------------------------------------
# 
# Returns an instance of the Environment class. Only one instance
# can be created in a session
# Note that this is implemented as a static method
# 
#-----------------------------------------------------------------------
sub getEnvironment
{
	if (!defined($environment)) {
		croak("Environment::getEnvironment: Environment not initialised.\n");
	}
	return $environment;
}


#-----------------------------------------------------------------------
# $ob = Environment->createFromConfig($config)
#-----------------------------------------------------------------------
# 
# Create environment object from existing EnvironmentConfig object which is essentially a hash
# of parameter name/value pairs.
# Throws error if instance of class has already been created.
# e.g.
# $config_values = { debug => 1, smtp_server => 'D06DBE01', 
#					 email_admin => 'mooreof@ie.ibm.com'};
# Environment->createFromConfig(EnvironmentConfig->createFromHash($config_values));
# 
#-----------------------------------------------------------------------
sub createFromConfig
{
	my $class = shift;
	my $config = shift;

	if (!defined($environment)) {
		my $self = {	
			CONFIG => new EnvironmentConfig(),
		};

		bless $self, $class;
		$environment = $self;

		$self->init();

		# override defaults with parameters passed
		if (ref($config) eq 'EnvironmentConfig') {
			$self->getConfig()->initFromConfig($config->getParams());
		} else {
			croak "Environment::createFromConfig: config parameter not of type \"EnvironmentConfig\"\n";
		}
		$self->initLog();

		# Check that config is fully initialised
		$self->getConfig()->checkRequired() or fatal("Error(s) occurred. Exiting...\n");
	} else {
		logf("Environment::createFromConfig: Environment already initialised\n");
	}
	
	return $environment;
}


#-----------------------------------------------------------------------
# $ob = Environment->createFromFile($ini)
#-----------------------------------------------------------------------
#
# Create environment object using configuration info from ini file (in the form
# of name=value records).
# See POD for allowed parameter names
# e.g. $ob = Environment->createFromFile('environment.ini')
#
#-----------------------------------------------------------------------
sub createFromFile
{
	my $class = shift;
	my $ini = shift;

	if (!defined($environment)) {
		my $self = {};

		# Check that param was passed and that file exists 
		if (defined($ini) && -f $ini) { # Call super class constructor
			$self->{'CONFIG'} = new EnvironmentConfig($ini);
		} else {
			croak "Environment::createFromFile needs valid *.ini file as input\nExiting...\n";
		}

		bless $self, $class;
		$environment = $self;

		$self->init();	
		$self->initLog();
	} else {
		logf("Environment::createFromFile: Environment already initialised\n");
	}		
	
	return $environment;
}




#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise Environment instance, including asssigning default values and calling
# super class version of init()
#
#-----------------------------------------------------------------------
sub init
{
	my $self = shift;

	
	# Make sure we only initialise once,
	#    in case a user explicitly calls what is intended to be a private method
	if (!$self->initialised()) {

		# Initialise some config parameters to default values
		$self->getConfig()->initFromConfig({
					  debug => 0,
					  smtp_server => '',
					  email_admin => '',
					  email_on_error => 0,
					  os_name => $self->initOSName(),
					  start_dir => $self->initStartDir(),
					  cvs_bin => $self->initCvsBin(),
					  cvs_home => $self->initCvsHome(),
					  cvs_tag => 'HEAD',
					  ant_version => 'apache-ant-1.6.2',
					  cdc_solid_root_dir => $self->initCDCSolidRootDir(),
					  cdc_db2_root_dir => $self->initCDCDb2RootDir(),
					  cdc_informix_root_dir => $self->initCDCInformixRootDir(),
					  cdc_bits => $self->initCDCBits(),
					  access_server_root_dir => $self->initAccessRootDir(),
					  solid_package => $self->initSolidPackage(),
					  solid_root_dir => $self->initSolidRootDir(),
					  solid_licence_file => $self->getStartDir(). 'solid.lic',
					  testbed_envname => 'environment.xml',
					  testbed_bucket => 'TestBed_HEAD',
					  testbed_head_dir => '.',
					  testbed_qa_approved_dir => '.',
					  java_home => $self->initJavaHome(),
					  java6_home => $self->initJavaSixHome(),
					  # Windows specific
					  mssdk_home => 'c:\dev\Microsoft SDKs\Windows\v6.1',
					  dotnetsdk_home => 'C:\dev\Microsoft SDKs\Windows\v6.1',
					  vstudio_home => 'c:\dev\devstudio9',
		});
		# Load parameter values from ini if provided
		if (defined($self->getIniFileName())) {	$self->getConfig()->initFromConfigFile(); }
		$self->initialised(1);
	}
}


#-----------------------------------------------------------------------
#
# END block, closes log file
#
#-----------------------------------------------------------------------
END
{
	my $self = shift;
	my $now = strftime("%a %b %d %H:%M:%S %Y",localtime);

	if (defined($environment) && defined($environment->logFile())) {
		logf("\n\n>> END -> $now\n\n");
		close $environment->logFile();
	}
}


#-----------------------------------------------------------------------
# $ob->printout()
#-----------------------------------------------------------------------
#
# Prints out contents of object's hash in a human-readable form
#
#-----------------------------------------------------------------------
sub printout
{
	my $self = shift;
	
	logf(Dumper($self));
}


# write string to output log and stdout
#-----------------------------------------------------------------------
# Environment::logf($str)
#-----------------------------------------------------------------------
#
# Write string to output log and stdout, where:
# str=string to print
# Note that this is implemented as a static method and should not be 
# called via Environment->logf or $ob->logf
#
#-----------------------------------------------------------------------
sub logf
{
	my $msg = shift;
	my $stdout = shift;
	
	print $msg unless (defined($stdout) and !$stdout);
	if (defined($environment) && defined($environment->logFile())) {
		print {${$environment->logFile()}} $msg;
	}
}



#-----------------------------------------------------------------------
# Environment::fatal($str)
#-----------------------------------------------------------------------
#
# Called instead of die/croak, this prints string to error log,
# closes log, sends email with error message and calls croak
# Note that this is implemented as a static method and should not be 
# called via Environment->fatal or $ob->fatal
#
#-----------------------------------------------------------------------
sub fatal
{
	my $msg = shift;
	my $from = "Admin <mooreof\@ie.ibm.com>";
	my $subject = "Program exited abnormally with the following message:\n$msg\n";
	my $body;
	my %mail;
	my $now = strftime("%a %b %d %H:%M:%S %Y",localtime);

	if (defined($environment) && defined($environment->logFile())) {
		$body = $msg . "\n\nSee ".$environment->getStartDir().$environment->logFileName() . " for details\n";
		logf($msg,0);
		logf("\n\n>> END -> $now\n\n");
		close($environment->logFile());
	
		if ($environment->emailOnError() && require Mail::Sendmail) {
			%mail = (To => $environment->adminEmail(),
					 From => $from,
					 subject => 'Abnormal termination of program',
					 message => $body,
					 smtp => $environment->smtpServer());
			Mail::Sendmail::sendmail(%mail) or croak $Mail::Sendmail::error;
		} elsif ($environment->emailOnError()) {
			logf("Unable to send email as Mail::Sendmail module cannot be found\n");
		}
	}
	croak $msg;
}


############################################################
# INITIALISATION METHODS                                   #
############################################################


#-----------------------------------------------------------------------
# $ob->initLog()
#-----------------------------------------------------------------------
#
# Creates output log which can be written to using logf()
#
#-----------------------------------------------------------------------
sub initLog
{
	my $self = shift;
	my $now = strftime("%a %b %d %H:%M:%S %Y",localtime); 

	# If user hasn't defined a name for log file, set it here	
	if (!defined($self->logFileName()) || $self->logFileName() eq '') {
		$self->logFileName('automation_'.strftime("%a_%b_%d_%Y",localtime).'.log');
	}
	open(ALOG,'>',$self->logFileName()) 
		or croak "Cannot open \"${\$self->logFileName()}\" for writing: $!";
	$self->logFile(\*ALOG);
	logf("\n>> START -> $now\n\n");
}


#-----------------------------------------------------------------------
# $ob->initOSName()
#-----------------------------------------------------------------------
#
# Initialise Operating system name
#
#-----------------------------------------------------------------------
sub initOSName
{
	my $self = shift;
	my $os = $Config::Config{'osname'}; # Host operating system

	if ($os =~ /^MSWin/i) {
		 $os = 'windows';
	} elsif ($os =~ /^dos/i) {
		$os = 'dos';
	} elsif ($os =~ /^MacOS/i) {
		$os = 'macintosh';
	} elsif ($os =~ /^os2/i) {
		$os = 'os2';
	} else {
		$os = 'unix';
	}
	$self->getConfigParams()->{'os_name'} = $os;
}


#-----------------------------------------------------------------------
# $ob->initCDCBits()
#-----------------------------------------------------------------------
#
# Initialise Bit architecture (32/64)
#
#-----------------------------------------------------------------------
sub initCDCBits
{
	my $self = shift;
	my $arch = $Config::Config{'myarchname'}; # Return something like MSWin32, MSWin64, i686-linux

	if ($arch =~ /64/) {
		 $self->CDCBits(64);
	} else {
		 $self->CDCBits(32);
	}
}


#-----------------------------------------------------------------------
# $ob->initStartDir()
#-----------------------------------------------------------------------
#
# Stores current directory when main driver file starts
#
#-----------------------------------------------------------------------
sub initStartDir
{
	my $self = shift;
	my $cwd = Cwd::getcwd(); # Current working directory
	my $ps = $self->getPathSeparator();

	if (substr($cwd,-1,1) !~ m/[\/\\]/) { $cwd .= $ps; } # Terminate with path separator
	$self->getConfigParams()->{'start_dir'} = $cwd;
}



#-----------------------------------------------------------------------
# $ob->initCDCSolidRootDir()
#-----------------------------------------------------------------------
#
# Initialises CDC for Solid root directory with default value
# CDCSolid:install() will install to this directory unless overridden
#
#-----------------------------------------------------------------------
sub initCDCSolidRootDir
{
	my $self = shift;
	my $dir;

	if ($self->getOSName() eq 'windows') {
		$dir = "c:\\program files\\DataMirror\\Transformation Server for solidDB\\";
	} else {
		$dir = $ENV{'HOME'} . '/Transformation Server for solidDB/';
	}
	$self->CDCSolidRootDir($dir);
}


#-----------------------------------------------------------------------
# $ob->initCDCDb2RootDir()
#-----------------------------------------------------------------------
#
# Initialises CDC for Db2 root directory with default value
# CDCDb2install() will install to this directory unless overridden
#
#-----------------------------------------------------------------------
sub initCDCDb2RootDir
{
	my $self = shift;
	my $dir;

	if ($self->getOSName() eq 'windows') {
		$dir = "c:\\program files\\DataMirror\\Transformation Server for UDB\\";
	} else {
		$dir = $ENV{'HOME'} . '/Transformation Server for UDB/';
	}
	$self->CDCDb2RootDir($dir);
}

# $ob->initCDCInformixRootDir()
#-----------------------------------------------------------------------
#
# Initialises CDC for Informix root directory with default value
# CDCInformix:install() will install to this directory unless overridden
#
#-----------------------------------------------------------------------
sub initCDCInformixRootDir
{
	my $self = shift;
	my $dir;

	if ($self->getOSName() eq 'windows') {
		$dir = "c:\\program files\\DataMirror\\Transformation Server for Informix\\";
	} else {
		$dir = $ENV{'HOME'} . '/Transformation Server for Informix/';
	}
	$self->CDCInformixRootDir($dir);
}



#-----------------------------------------------------------------------
# $ob->initAccessRootDir()
#-----------------------------------------------------------------------
#
# Initialises Access Server root directory with default value
#
#-----------------------------------------------------------------------
sub initAccessRootDir
{
	my $self = shift;
	my $dir;

	if ($self->getOSName() eq 'windows') {
		$dir = "c:\\program files\\DataMirror\\Transformation Server Access Control\\";
	} else {
		$dir = $ENV{'HOME'} . '/DataMirror/Transformation Server Access Control/';
	}
	$self->accessServerRootDir($dir);
}


#-----------------------------------------------------------------------
# $ob->initSolidPackage()
#-----------------------------------------------------------------------
#
# Initialises solid installation package name 
# SolidDB::install() uses this package  name as source by default
#
#-----------------------------------------------------------------------
sub initSolidPackage
{
	my $self = shift;
	my $name;

	if ($self->getOSName() eq 'windows') {
		$name = "z:\\Databases\\solidDB\\build\ 0010\\CZ9H2EN_solidDB-6.5-w32.exe";
	} else {
		$name = "/mnt/mastersoftware/Databases/solidDB/build\ 0010/CZ9H0EN_solidDB-6.5-linux-x86.bin";
	}
	$self->solidPackage($name);
}


#-----------------------------------------------------------------------
# $ob->initSolidRootDir()
#-----------------------------------------------------------------------
#
# Initialises Solid root directory with default value
# SolidDB::install() will install to this directory unless overridden
#
#-----------------------------------------------------------------------
sub initSolidRootDir
{
	my $self = shift;
	my $dir;

	if ($self->getOSName() eq 'windows') {
		$dir = "c:\\program files\\solid\\";
	} else {
		$dir = $ENV{'HOME'} . '/solid/';
	}
	$self->solidRootDir($dir);
}



#-----------------------------------------------------------------------
# $ob->initCvsHome()
#-----------------------------------------------------------------------
#
# Initialises local CVS home directory
#
#-----------------------------------------------------------------------
sub initCvsHome
{
	my $self = shift;
	my $dir;

	if ($self->getOSName() eq 'windows') {
		$dir = "c:\\cvs";
	} else {
		$dir = $ENV{'HOME'} . '/cvs';
	}
	$self->cvsHome($dir);
}


#-----------------------------------------------------------------------
# $ob->initCvsBin()
#-----------------------------------------------------------------------
#
# Initialises location of CVS binary
#
#-----------------------------------------------------------------------
sub initCvsBin
{
	my $self = shift;
	my $dir;

	if ($self->getOSName() eq 'windows') {
		$dir = "c:\\program files\\CVS Suite\\WinCvs\\cvsnt\\cvs.exe";
	} else {
		$dir = '/usr/bin/cvs';
	}
	$self->cvsBin($dir);
}


#-----------------------------------------------------------------------
# $ob->initJavaHome()
#-----------------------------------------------------------------------
#
# Initialises home directory for Java 5
# Used by ant utility
#
#-----------------------------------------------------------------------
sub initJavaHome
{
	my $self = shift;
	my $dir;

	if ($self->getOSName() eq 'windows') {
		$dir = 'C:\Program Files\Java\jdk1.5.0_16\lib';
	} else {
		$dir = $ENV{'HOME'} . '/ibm-java2-i386-50/jre';
	}
	$self->javaHome($dir);
}



#-----------------------------------------------------------------------
# $ob->initJavaSixHome()
#-----------------------------------------------------------------------
#
# Initialises home directory for Java 6
# Used by ant utility
#
#-----------------------------------------------------------------------
sub initJavaSixHome
{
	my $self = shift;
	my $dir;

	if ($self->getOSName() eq 'windows') {
		$dir = 'C:\Program Files\Java\jdk1.6.0_12\lib';
	} else {
		$dir = $ENV{'HOME'} . '/ibm-java-i386-60';
	}
	$self->javaSixHome($dir);
}


#-----------------------------------------------------------------------
# $init = $ob->initialised()
# $ob->initialised($init)
#-----------------------------------------------------------------------
#
# Get/set flag indicating whether object has been initialised.
# This is done to prevent object being initialised later by a user
# which would set all parameters back to their default values
#
#-----------------------------------------------------------------------
sub initialised
{
	my ($self,$init) = @_;
	if (!defined($self->{'INIT'})) { $self->{'INIT'} = 0; }
	$self->{'INIT'} = $init if defined($init);
	return $self->{'INIT'};
}

#################################################################
# Get/Set methods                                               #
#################################################################


#-----------------------------------------------------------------------
# $cfg = $ob->getConfig()
#-----------------------------------------------------------------------
#
# Get configuration object (class DatabaseConfig)
#
#-----------------------------------------------------------------------
sub getConfig
{
	my $self = shift;
	return $self->{'CONFIG'};
}


#-----------------------------------------------------------------------
# $ref = $ob->getConfigParams()
#-----------------------------------------------------------------------
#
# Get reference to configuration parameters hash
#
#-----------------------------------------------------------------------
sub getConfigParams
{
	my $self = shift;
	return $self->getConfig()->getParams();
}


#-----------------------------------------------------------------------
# $ini = $ob->getIniFileName()
#-----------------------------------------------------------------------
#
# Get configuration ini file name
#
#-----------------------------------------------------------------------
sub getIniFileName
{
	my $self = shift;
	return $self->getConfig()->getIniFile();
}


#-----------------------------------------------------------------------
# $name = $ob->logFileName()
# $ob->logFileName($name)
#-----------------------------------------------------------------------
#
# Get/set name of log file
#
#-----------------------------------------------------------------------
sub logFileName
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'log_file_name'} = $name if defined($name);
	return $self->getConfigParams()->{'log_file_name'};
}


#-----------------------------------------------------------------------
# $fh = $ob->logFile()
# $ob->logFile($fh)
#-----------------------------------------------------------------------
#
# Get/set name of log file handle
#
#-----------------------------------------------------------------------
sub logFile
{
	my ($self,$logref) = @_;
	$self->getConfigParams()->{'log_file'} = $logref if defined($logref);
	return $self->getConfigParams()->{'log_file'};
}


#-----------------------------------------------------------------------
# $name = $ob->getOSName()
#-----------------------------------------------------------------------
#
# Get operating system name
#
#-----------------------------------------------------------------------
sub getOSName
{
	my $self = shift;
	return $self->getConfigParams()->{'os_name'};
}



#-----------------------------------------------------------------------
# $sep = $ob->getPathSeparator()
#-----------------------------------------------------------------------
#
# Get path separator character
#
#-----------------------------------------------------------------------
sub getPathSeparator
{
	my $self = shift;
	return ($self->getOSName() eq 'windows') ? "\\" : "/";
}


#-----------------------------------------------------------------------
# $sep = $ob->getEnvSeparator()
#-----------------------------------------------------------------------
#
# Return separator between components of an environment variable
#
#-----------------------------------------------------------------------
sub getEnvSeparator
{
	my $self = shift;
	return ($self->getOSName() eq 'windows') ? ";" : ":";
}



#-----------------------------------------------------------------------
# $dir = $ob->getStartDir()
#-----------------------------------------------------------------------
#
# Get current directory when main driver file was started
#
#-----------------------------------------------------------------------
sub getStartDir
{
	my $self = shift;
	return $self->getConfigParams()->{'start_dir'};
}


#-----------------------------------------------------------------------
# $name = $ob->smtpServer()
# $ob->smtpServer($name)
#-----------------------------------------------------------------------
#
# SMTP server host name/ip address
#
#-----------------------------------------------------------------------
sub smtpServer
{
	my ($self,$svr) = @_;
	$self->getConfigParams()->{'smtp_server'} = $svr if defined($svr);
	return $self->getConfigParams()->{'smtp_server'};
}



#-----------------------------------------------------------------------
# $name = $ob->adminEmail()
# $ob->adminEmail($name)
#-----------------------------------------------------------------------
#
# Get/set administrator email address
#
#-----------------------------------------------------------------------
sub adminEmail
{
	my ($self,$add) = @_;
	$self->getConfigParams()->{'email_admin'} = $add if defined($add);
	return $self->getConfigParams()->{'email_admin'};
}


#-----------------------------------------------------------------------
# $flag = $ob->emailOnError()
# $ob->emailOnError($flag)
#-----------------------------------------------------------------------
#
# Get/set flag controlling whether an email is sent in fatal() function
#
#-----------------------------------------------------------------------
sub emailOnError
{
	my ($self,$flag) = @_;
	$self->getConfigParams()->{'email_on_error'} = $flag if defined($flag);
	return $self->getConfigParams()->{'email_on_error'};
}



#-----------------------------------------------------------------------
# $dbg = $ob->debugModeOn()
# $ob->debugModeOn($dbg)
#-----------------------------------------------------------------------
#
# Get/set debug flag
#
#-----------------------------------------------------------------------
sub debugModeOn
{
	my ($self,$debug) = @_;
	$self->getConfigParams()->{'debug'} = $debug if defined($debug);
	return $self->getConfigParams()->{'debug'};
}


#-----------------------------------------------------------------------
# $dir = $ob->CDCSolidRootDir()
# $ob->CDCSolidRootDir($dir[,$addpath])
#-----------------------------------------------------------------------
#
# Get/set root directory where CDC for solid is installed
# $addpath(0/1) specififes whether to update environment PATH variable
# CDCSolid::install will install to this directory unless overridden
#
#-----------------------------------------------------------------------
sub CDCSolidRootDir
{
	my ($self,$name,$addpath) = @_;
	my $ps = $self->getPathSeparator();
	my $es = $self->getEnvSeparator();

	$self->getConfigParams()->{'cdc_solid_root_dir'} = $name if defined($name);
	# make sure path is terminated with separator
	if (substr($self->getConfigParams()->{'cdc_solid_root_dir'},-1,1) !~ m/[\/\\]/) { 
		$self->getConfigParams()->{'cdc_solid_root_dir'} .= $ps;
	}
	# abort if not set
	if (!defined($self->getConfigParams()->{'cdc_solid_root_dir'})) {
		fatal("Environment::CDCSolidRootDir: directory not set\n");
	}
	if (defined($addpath) && $addpath == 1) {
		$ENV{'PATH'} = $self->getConfigParams()->{'cdc_solid_root_dir'} . 'bin' . $es . $ENV{'PATH'};
	}
	return $self->getConfigParams()->{'cdc_solid_root_dir'};
}


#-----------------------------------------------------------------------
# $dir = $ob->CDCDb2RootDir()
# $ob->CDCDb2RootDir($dir[,$addpath])
#-----------------------------------------------------------------------
#
# Get/set root directory where CDC for DB2 is installed
# $addpath(0/1) specififes whether to update environment PATH variable
# CDCDb2::install will install to this directory unless overridden
#
#-----------------------------------------------------------------------
sub CDCDb2RootDir
{
	my ($self,$name,$addpath) = @_;
	my $ps = $self->getPathSeparator();
	my $es = $self->getEnvSeparator();

	$self->getConfigParams()->{'cdc_db2_root_dir'} = $name if defined($name);
	# make sure path is terminated with separator
	if (substr($self->getConfigParams()->{'cdc_db2_root_dir'},-1,1) !~ m/[\/\\]/) { 
		$self->getConfigParams()->{'cdc_db2_root_dir'} .= $ps;
	}
	# abort if not set
	if (!defined($self->getConfigParams()->{'cdc_db2_root_dir'})) {
		fatal("Environment::CDCDb2RootDir: directory not set\n");
	}
	if (defined($addpath) && $addpath == 1) {
		$ENV{'PATH'} = $self->getConfigParams()->{'cdc_db2_root_dir'} . 'bin' . $es . $ENV{'PATH'};
	}
	return $self->getConfigParams()->{'cdc_db2_root_dir'};
}

#-----------------------------------------------------------------------
# $dir = $ob->CDCInformixRootDir()
# $ob->CDCInformixRootDir($dir[,$addpath])
#-----------------------------------------------------------------------
#
# Get/set root directory where CDC for Informix is installed
# $addpath(0/1) specififes whether to update environment PATH variable
# CDCInformix::install will install to this directory unless overridden
#
#-----------------------------------------------------------------------
sub CDCInformixRootDir
{
	my ($self,$name,$addpath) = @_;
	my $ps = $self->getPathSeparator();
	my $es = $self->getEnvSeparator();

	$self->getConfigParams()->{'cdc_informix_root_dir'} = $name if defined($name);
	# make sure path is terminated with separator
	if (substr($self->getConfigParams()->{'cdc_informix_root_dir'},-1,1) !~ m/[\/\\]/) { 
		$self->getConfigParams()->{'cdc_informix_root_dir'} .= $ps;
	}
	# abort if not set
	if (!defined($self->getConfigParams()->{'cdc_informix_root_dir'})) {
		fatal("Environment::CDCInformixRootDir: directory not set\n");
	}
	if (defined($addpath) && $addpath == 1) {
		$ENV{'PATH'} = $self->getConfigParams()->{'cdc_informix_root_dir'} . 'bin' . $es . $ENV{'PATH'};
	}
	return $self->getConfigParams()->{'cdc_informix_root_dir'};
}


#-----------------------------------------------------------------------
# $x = $ob->CDCBits()
# $ob->CDCBits($x)
#-----------------------------------------------------------------------
#
# Get/set CPU architecture of host CDC machine
#
#-----------------------------------------------------------------------
sub CDCBits
{
	my ($self,$bits) = @_;
	$self->getConfigParams()->{'cdc_bits'} = $bits if defined($bits);
	return $self->getConfigParams()->{'cdc_bits'};
}


#-----------------------------------------------------------------------
# $x = $ob->accessServerRootDir()
# $ob->accessServerRootDir($x[,$addpath])
#-----------------------------------------------------------------------
#
# Get/set Access Server root directory
# $addpath(0/1) specififes whether to update environment PATH variable
#
#-----------------------------------------------------------------------
sub accessServerRootDir
{
	my ($self,$name,$addpath) = @_;
	my $ps = $self->getPathSeparator();
	my $es = $self->getEnvSeparator();

	$self->getConfigParams()->{'access_server_root_dir'} = $name if defined($name);
	# make sure path is terminated with separator
	if (substr($self->getConfigParams()->{'access_server_root_dir'},-1,1) !~ m/[\/\\]/) { 
		$self->getConfigParams()->{'access_server_root_dir'} .= $ps;
	}
	if (defined($addpath) && $addpath == 1) {
		$ENV{'PATH'} = $self->getConfigParams()->{'access_server_root_dir'} . 'bin' . $es . $ENV{'PATH'};
	}
	return $self->getConfigParams()->{'access_server_root_dir'};
}


#-----------------------------------------------------------------------
# $dir = $ob->solidRootDir()
# $ob->solidRootDir($dir[,$addpath])
#-----------------------------------------------------------------------
#
# Installation directory for SolidDB
# SolidDB:install installs to this directory by default
# $addpath(0/1) specififes whether to update environment PATH variable
#
#-----------------------------------------------------------------------
sub solidRootDir
{
	my ($self,$name,$addpath) = @_;
	my $ps = $self->getPathSeparator();
	my $es = $self->getEnvSeparator();

	$self->getConfigParams()->{'solid_root_dir'} = $name if defined($name);
	# make sure path is terminated with separator
	if (substr($self->getConfigParams()->{'solid_root_dir'},-1,1) !~ m/[\/\\]/) { 
		$self->getConfigParams()->{'solid_root_dir'} .= $ps;
	}
	if (defined($addpath) && $addpath == 1) {
		$ENV{'PATH'} = $self->getConfigParams()->{'solid_root_dir'} . 'bin' . $es . $ENV{'PATH'};
	}
	return $self->getConfigParams()->{'solid_root_dir'};
}



#-----------------------------------------------------------------------
# $ob->solidPackage()
#-----------------------------------------------------------------------
#
# Solid installation package name 
# SolidDB::install() uses this package name as source by default
#
#-----------------------------------------------------------------------
sub solidPackage
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'solid_package'} = $name if defined($name);
	return $self->getConfigParams()->{'solid_package'};
}



#-----------------------------------------------------------------------
# $ob->solidLicenceFile($lic)
# $lic = $ob->solidLicenceFile()
#-----------------------------------------------------------------------
#
# Solid Licence File name and location
#
#-----------------------------------------------------------------------
sub solidLicenceFile
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'solid_licence_file'} = $name if defined($name);
	return $self->getConfigParams()->{'solid_licence_file'};
}


#-----------------------------------------------------------------------
# $ob->testbedEnvName($name)
# $name = $ob->testbedEnvName()
#-----------------------------------------------------------------------
#
# Testbed environment file name
#
#-----------------------------------------------------------------------
sub testbedEnvName
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'testbed_envname'} = $name if defined($name);
	return $self->getConfigParams()->{'testbed_envname'};
}


#-----------------------------------------------------------------------
# $ob->testbedBucket($name)
# $name = $ob->testbedBucket()
#-----------------------------------------------------------------------
#
# Default Testbed bucket
#
#-----------------------------------------------------------------------
sub testbedBucket
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'testbed_bucket'} = $name if defined($name);
	return $self->getConfigParams()->{'testbed_bucket'};
}



#-----------------------------------------------------------------------
# $ob->testbedHeadDir($dir)
# $dir = $ob->testbedHeadDir()
#-----------------------------------------------------------------------
#
# Testbed Head branch location
#
#-----------------------------------------------------------------------
sub testbedHeadDir
{
	my ($self,$name) = @_;
	my $ps = $self->getPathSeparator();

	$self->getConfigParams()->{'testbed_head_dir'} = $name if defined($name);
	# make sure path is terminated with separator
	if (substr($self->getConfigParams()->{'testbed_head_dir'},-1,1) !~ m/[\/\\]/) { 
		$self->getConfigParams()->{'testbed_head_dir'} .= $ps;
	}
	# abort if not set
	if (!defined($self->getConfigParams()->{'testbed_head_dir'})) {
		fatal("Environment::testbedHeadDir: directory not set\n");
	}
	return $self->getConfigParams()->{'testbed_head_dir'};
}


#-----------------------------------------------------------------------
# $ob->testbedHeadDir($dir)
# $dir = $ob->testbedHeadDir()
#-----------------------------------------------------------------------
#
# Testbed QA Approved branch location
#
#-----------------------------------------------------------------------
sub testbedQAApprovedDir
{
	my ($self,$name) = @_;
	my $ps = $self->getPathSeparator();

	$self->getConfigParams()->{'testbed_qa_approved_dir'} = $name if defined($name);
	# make sure path is terminated with separator
	if (substr($self->getConfigParams()->{'testbed_qa_approved_dir'},-1,1) !~ m/[\/\\]/) { 
		$self->getConfigParams()->{'testbed_qa_approved_dir'} .= $ps;
	}
	# abort if not set
	if (!defined($self->getConfigParams()->{'testbed_qa_approved_dir'})) {
		fatal("Environment::testbedQAApprovedDir: directory not set\n");
	}
	return $self->getConfigParams()->{'testbed_qa_approved_dir'};
}


#-----------------------------------------------------------------------
# $ob->cvsUser($usr)
# $usr = $ob->cvsUser()
#-----------------------------------------------------------------------
#
# User name to access CVS repository
#
#-----------------------------------------------------------------------
sub cvsUser
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'cvs_user'} = $name if defined($name);
	return $self->getConfigParams()->{'cvs_user'};
}


#-----------------------------------------------------------------------
# $ob->cvsPass($pass)
# $pass = $ob->cvsPass()
#-----------------------------------------------------------------------
#
# Password of cvsUser()
#
#-----------------------------------------------------------------------
sub cvsPass
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'cvs_pass'} = $name if defined($name);
	return $self->getConfigParams()->{'cvs_pass'};
}


#-----------------------------------------------------------------------
# $ob->cvsRepository($repos)
# $repos = $ob->cvsRepository()
#-----------------------------------------------------------------------
#
# Location of CVS repository
#
#-----------------------------------------------------------------------
sub cvsRepository
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'cvs_repository'} = $name if defined($name);
	return $self->getConfigParams()->{'cvs_repository'};
}


#-----------------------------------------------------------------------
# $ob->cvsBin($dir)
# $dir = $ob->cvsBin()
#-----------------------------------------------------------------------
#
# Location of CVS binary
#
#-----------------------------------------------------------------------
sub cvsBin
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'cvs_bin'} = $name if defined($name);
	return $self->getConfigParams()->{'cvs_bin'};
}



#-----------------------------------------------------------------------
# $ob->cvsHome($dir)
# $dir = $ob->cvsHome()
#-----------------------------------------------------------------------
#
# CVSROOT on local machine
#
#-----------------------------------------------------------------------
sub cvsHome
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'cvs_home'} = $name if defined($name);
	return $self->getConfigParams()->{'cvs_home'};
}


#-----------------------------------------------------------------------
# $ob->cvstag($tag)
# $tag = $ob->cvsTag()
#-----------------------------------------------------------------------
#
# Default CVS branch tag name
#
#-----------------------------------------------------------------------
sub cvsTag
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'cvs_tag'} = $name if defined($name);
	return $self->getConfigParams()->{'cvs_tag'};
}


#-----------------------------------------------------------------------
# $ob->antVersion($name)
# $name = $ob->antVersion()
#-----------------------------------------------------------------------
#
# Version name of Ant utility to copy from repository
#
#-----------------------------------------------------------------------
sub antVersion
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ant_version'} = $name if defined($name);
	return $self->getConfigParams()->{'ant_version'};
}


#-----------------------------------------------------------------------
# $ob->javaHome($dir[,$addpath])
#-----------------------------------------------------------------------
#
# Initialises home directory for Java 5
# Used by ant utility
# $addpath(0/1) specififes whether to update environment PATH variable
#
#-----------------------------------------------------------------------
sub javaHome
{
	my ($self,$dir,$addpath) = @_;
	my $ps = $self->getPathSeparator();
	my $es = $self->getEnvSeparator();
	
	$self->getConfigParams()->{'java_home'} = $dir if defined($dir);
	# make sure path is terminated with separator
	if (substr($self->getConfigParams()->{'java_home'},-1,1) !~ m/[\/\\]/) { 
		$self->getConfigParams()->{'java_home'} .= $ps;
	}
	if (defined($addpath) && $addpath == 1) {
		$ENV{'PATH'} = $self->getConfigParams()->{'java_home'} . 'bin' . $es . $ENV{'PATH'};
	}
	return $self->getConfigParams()->{'java_home'};
}


#-----------------------------------------------------------------------
# $ob->javaSixHome($dir[,$addpath])
#-----------------------------------------------------------------------
#
# Initialises home directory for Java 6
# Used by ant utility
#
#-----------------------------------------------------------------------
sub javaSixHome
{
	my ($self,$dir,$addpath) = @_;
	my $ps = $self->getPathSeparator();
	my $es = $self->getEnvSeparator();

	$self->getConfigParams()->{'java6_home'} = $dir if defined($dir);
	if (substr($self->getConfigParams()->{'java6_home'},-1,1) !~ m/[\/\\]/) { 
		$self->getConfigParams()->{'java6_home'} .= $ps;
	}
	if (defined($addpath) && $addpath == 1) {
		$ENV{'PATH'} = $self->getConfigParams()->{'java6_home'} . 'bin' . $es . $ENV{'PATH'};
	}
	return $self->getConfigParams()->{'java6_home'};
}



#-----------------------------------------------------------------------
# $ob->msSdkHome()
#-----------------------------------------------------------------------
#
# Initialises home directory of MS sdk
# Used by ant utility
#
#-----------------------------------------------------------------------
sub msSdkHome
{
	my ($self,$dir) = @_;
	$self->getConfigParams()->{'mssdk_home'} = $dir if defined($dir);
	return $self->getConfigParams()->{'mssdk_home'};
}


#-----------------------------------------------------------------------
# $ob->dotNetSdkHome()
#-----------------------------------------------------------------------
#
# Initialises home directory of dotnet sdk
# Used by ant utility
#
#-----------------------------------------------------------------------
sub dotNetSdkHome
{
	my ($self,$dir) = @_;
	$self->getConfigParams()->{'dotnetsdk_home'} = $dir if defined($dir);
	return $self->getConfigParams()->{'dotnetsdk_home'};
}


#-----------------------------------------------------------------------
# $ob->vstudioHome()
#-----------------------------------------------------------------------
#
# Initialises home directory of Visual Studio
# Used by ant utility
#
#-----------------------------------------------------------------------
sub vstudioHome
{
	my ($self,$dir) = @_;
	$self->getConfigParams()->{'vstudio_home'} = $dir if defined($dir);
	return $self->getConfigParams()->{'vstudio_home'};
}


1;

=head1 NAME

Environment - class to store environment configuration

=head1 SYNOPSIS

use IBM::UC::Environment;

#################
# class methods #
#################

 The Environment Module contains two constructor methods, one of which would be invoked in a main driver
 file, and a static method which returns the environment config object. The latter would be used by other
 modules to access the environment information as the object can only be created once.

 $ob = Environment->createFromFile($ini);
   where:
     $ini=configuration file

 $ob = Environment->createFromConfig($config)
  where:
   $config=object of class EnvironmentConfig

 $env = Environment::getEnvironment()
  Static method which returns instance of Environment class

 Environment::logf($msg[,$stdout])
  where: $msg=message to print, $stdout (0/1) specifies whether to also print to stdout
  Static method which prints $msg to logFile() and, optionally, stdout

 Environment::fatal($msg)
  where: $msg=message to print
  Static method which calls logf($msg), sends email to emailAdmin() and exits

#######################
# object data methods #
#######################

### get versions ###

 $os = $ob->getOSName()				# operating system name (e.g., "windows" or "unix")
 $ps = $ob->getPathSeparator()		# Return os-specific path separator
 $ps = $ob->getEnvSeparator()		# Return os-specific environment variable separator
 $email = $ob->emailAdmin()			# Email address of admin to whom emails are sent from fatal()
 $flag = $ob->emailOnError()		# Flag controlling whether email is sent in fatal() routine
 $dir = $ob->getStartDir()			# current directory at time driver app is launched
 $svr = $ob->smtpServer()			# SMTP Server host name
 $dbg = $ob->debugModeOn()			# debug mode on/off
 $dir = $ob->CDCSolidRootDir()		# Root directory of Transformation Server for DB2
 $dir = $ob->CDCDb2RootDir()		# Root directory of Transformation Server for Solid
 $dir = $ob->CDCInformixRootDir()	# Root directory of Transformation Server for Informix
 $bits = $ob->CDCBits()				# cpu architecture of hosting cdc server (32/64)
 $bits = $ob->accessServerRootDir()	# Root directory of Transformation Access Server Control
 $dir = $ob->solidRootDir()			# SolidD installation root directory
 $pck = $ob->solidPackage()			# Solid Install package name
 $lic = $ob->solidLicenceFile()		# Solid Licence file location
 $env = $ob->testbedEnvName()		# Testbed environment file name
 $bck = $ob->testbedBucket()		# Default testbed bucket
 $dir = $ob->testbedHeadDir()		# Location of Testbed Head directory
 $dir = $ob->testbedQAApprovedDir()	# Location of testbed QA_Approved directory
 $user = $ob->cvsUser()				# User name to access CVS repository
 $pass = $ob->cvsPass()				# User password to access CVS repository
 $repos = $ob->cvsRepository()		# CVS repository location
 $cvs = $ob->cvsBin()				# CVS binary location
 $home = $ob->cvsHome()				# CVSROOT on client side
 $tag = $ob->cvsTag()				# Default Tag name for CVS branch
 $ver = $ob->antVersion()			# Version name of Ant utility to copy from repository
 $dir = $ob->javaHome()				# Location of Java 5 
 $dir = $ob->javaSixHome()			# Location of Java 6
 $dir = $ob->msSdkHome()			# Location of MsSdk
 $dir = $ob->dotNetSdkHome()		# Location of dotnet Sdk
 $dir = $ob->vstudioHome()			# Location of Visual Studio

### set versions ###

 $ob->smtpServer('D06ML902')		
 $ob->debugModeOn(1)			 
 $ob->emailAdmin('xxx@yyy.com')
 $ob->emailOnError(1)
 $ob->CDCSolidRootDir('...',addpath)		 
 $ob->CDCDb2RootDir('...',addpath)		 
 $ob->CDCInformixRootDir('...',addpath)		 
 $ob->CDCBits(64)			
 $ob->accessServerRootDir('...',addpath)	
 $ob->solidRootDir('...',addpath)
 $ob->solidPackage('...')
 $ob->solidLicenceFile('...')
 $ob->testbedEnvName('...')
 $ob->testbedBucket('...')
 $ob->testbedHeadDir('...')		
 $ob->testbedQAApprovedDir('...')	
 $ob->cvsUser('...')
 $ob->cvsPass('...')
 $ob->cvsRepository('...')
 $ob->cvsBin('...')
 $ob->cvsHome('...')
 $ob->cvsTag('...')
 $ob->antVersion('...')
 $ob->javaHome('...')
 $ob->javaSixHome('...')
 $ob->msSdkHome('...')
 $ob->dotNetSdkHome('...')
 $ob->vstudioHome('...')

########################
# other object methods #
########################

=head1 DESCRIPTION

The Environment module stores 'static' environment information in a config object.

Initialisation of an Environment instance is via various configuration parameters. Valid 
configuration parameters and their default values follow (see EnvironmentConfig.pm):

 ---------------------------------------------------------------------------------------------------------
 Parameter		Description					Default value
 ---------------------------------------------------------------------------------------------------------
 debug			Debug mode (0/1)				0
 smtp_server		MTP server to process emails			D06DBE01
 email_admin		dmin contact					mooreof@ie.ibm.com
 cvs_user		User name with access to cvs repository		dmbuild
 cvs_pass		Password of cvs user				dmbuild
 cvs_repository		VS repository					:pserver:dmbuild\@dmccvs.torolab.ibm.com:/home/cvsuser/cvsdata
 cvs_bin		Location of cvs program				/usr/bin/cvs
									c:\program files\CVS Suite\WinCvs\cvsnt\cvs.exe
 cvs_home		local CVS home directory			/home/user/cvs
									c:\cvs
 cvs_tag		Default CVS branch name				HEAD
 ant_version		Version of the ant compiler to build		apache-ant-1.6.2
 cdc_solid_root_dir	Home directory of CDC for Solid			/home/user/Transformation Server for solidDB
									c:\program files\DataMirror\Transformation Server for solidDB
 cdc_db2_root_dir	Home directory of CDC for DB2			/home/user/Transformation Server for UDB
									c:\program files\DataMirror\Transformation Server for UDB
 cdc_bits		CPU architecture of Solid CDC Solid host	32
 access_server_root_dir	Access Server root directory			/home/user/DataMirror/Transformation Server Access Control
									c:\program files\DataMirror\Transformation Server Access Control
 solid_package		Solid package name/location to install		/mnt/mastersoftware/Databases/solidDB/build\ 0010/CZ9H0EN_solidDB-6.5-linux-x86.bin
									z:\Databases\solidDB\build 0010\CZ9H2EN_solidDB-6.5-w32.exe
 solid_root_dir		Installation directory for Solid		/home/user/solid
									c:\program files\solid
 solid_licence_file	Name/location of solid licence file		'solid.lic' in start directory
 testbed_envname	Testbed Environment file name			environment.xml
 testbed_bucket		Testbed bucket					TestBed_HEAD
 testbed_head_dir	Location of Testbed (head branch) 		.
 testbed_qa_approved_dirLocation of Testbed (QA Approved branch)	.
 java_home		Location of Java 5				/home/user/ibm-java2-i386-50
									c:\program files\java\jdk1.5.0_16\lib
 java6_home		Location of Java 6				/home/user/ibm-java-i386-60
									c:\program files\java\jdk1.6.0_12\lib
 # Windows specific
 mssdk_home		MS SDK location					c:\dev\Microsoft SDKs\Windows\v6.1
 dotnetsdk_home		Dotnet SDK location				C:\dev\Microsoft SDKs\Windows\v6.1
 vstudio_home		Visual studio home				c:\dev\devstudio9
 ---------------------------------------------------------------------------------------------------------

if initialisation is via a configuration ini file the Environment section must start with [ENVIRONMENT]
and end with [/ENVIRONMENT] or end of file, e.g.:

 [ENVIRONMENT]

 ; SMTP Server host name
 smtp_server=D06ML902

 ; Transformation server root directory
 cdc_solid_root_dir=/home/db2inst1/Transformation Server for solidDB

 ; bit size of processor hosting cdc server
 cdc_bits=32

 ; Access server root directory
 access_server_root_dir=/home/db2inst1/DataMirror/Transformation Server Access Control

 ; Testbed Head home directory
 testbed_head_dir=/home/db2inst1/workspace/TestBed_HEAD/

 etc.
 
=cut
