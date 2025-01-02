########################################################################
# 
# File   :  CDC.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# CDC.pm is a super-class to implement CDC functionality.
# 
########################################################################
package CDC;

use strict;

use IBM::UC::Environment;
use IBM::UC::UCConfig::CDCConfig;
use Data::Dumper;
use Cwd;


#-----------------------------------------------------------------------
# $ob = CDC->new()
#-----------------------------------------------------------------------
#
# Create CDC object
#
#-----------------------------------------------------------------------
sub new
{
	my $class = shift;
	my $self = {
		DATABASE => undef, # reference to encapsulated database
		CONFIG  => new CDCConfig(),
	};
	bless $self, $class;

	return $self;
}


#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise CDC object
#
#-----------------------------------------------------------------------
sub init
{
	my $self = shift;
	$self->instanceHost('localhost');
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
	
	Environment::logf(Dumper($self));
}


#-----------------------------------------------------------------------
# $ob->install()
#-----------------------------------------------------------------------
#
# Empty method to be implemented in sub-class
#
#-----------------------------------------------------------------------
sub install
{
	Environment::fatal("install not implemented in CDC class\n");
}


#-----------------------------------------------------------------------
# $ob->uninstall()
#-----------------------------------------------------------------------
#
# Empty method to be implemented in sub-class
#
#-----------------------------------------------------------------------
sub uninstall
{
	Environment::fatal("uninstall not implemented in CDC class\n");
}


#-----------------------------------------------------------------------
# $ob->create([$dir])
#-----------------------------------------------------------------------
#
# Invoke instance manager to create CDC instance with parameters
# supplied during object's creation, where:
# $dir=CDC directory (optional)
#
#-----------------------------------------------------------------------
sub create
{
	my $self = shift;
	my $dir = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();

	$dir = $self->getEnv()->CDCSolidRootDir() unless (defined($dir));
	chdir($dir);
	Environment::logf(">>Creating TS Instance \"" . $self->instanceName() . "\"...\n");
	$self->dmInstanceManager($dir . "lib${ps}lib" . $self->getEnv()->CDCBits(),
				 			 {cmd=>'add', owmeta=>'true', bits=>$self->getEnv()->CDCBits(),
				 			  tsname=>$self->instanceName(),
  							  tsport=>$self->instancePort(), dbport=>$self->database()->dbPort()});
	chdir($savecwd);
}

#-----------------------------------------------------------------------
# $ob->delete([$dir])
#-----------------------------------------------------------------------
#
# Invoke instance manager to delete CDC instance with parameters
# supplied during object's creation, where:
# $dir=CDC directory (optional)
#
#-----------------------------------------------------------------------
sub delete
{
	my $self = shift;
	my $dir = shift;
	my $ps = $self->getEnv()->getPathSeparator();
	my $savecwd = Cwd::getcwd();

	$dir = $self->getEnv()->CDCSolidRootDir() unless (defined($dir));
	chdir($dir);
	Environment::logf(">>Deleting TS Instance \"" . $self->instanceName() . "\"...\n");
	$self->dmInstanceManager($dir . "lib${ps}lib" . $self->getEnv()->CDCBits(),
							 {cmd=>'delete', bits=>$self->getEnv()->CDCBits(),
							  tsname=>$self->instanceName()});
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->list([$dir])
#-----------------------------------------------------------------------
#
# Invoke instance manager to list available CDC instances, where:
# $dir=CDC directory (optional)
#
#-----------------------------------------------------------------------
sub list
{
	my $self = shift;
	my $dir = shift;
	my $ps = $self->getEnv()->getPathSeparator();
	my $savecwd = Cwd::getcwd();

	$dir = $self->getEnv()->CDCSolidRootDir() unless (defined($dir));
	chdir($dir);
	Environment::logf("Listing instances...\n");
	$self->dmInstanceManager($dir . "lib${ps}lib" . $self->getEnv()->CDCBits(), {cmd=>'list'});
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->update($newname,[$dir])
#-----------------------------------------------------------------------
#
# Invoke instance manager to rename a CDC instance, where:
# $newname=new name for CDC instance
# $dir=CDC directory (optional)
#
#-----------------------------------------------------------------------
sub update
{
	my $self = shift;
	my $newname = shift;
	my $dir = shift;
	my $ps = $self->getEnv()->getPathSeparator();
	my $savecwd = Cwd::getcwd();
	my $ret;

	$dir = $self->getEnv()->CDCSolidRootDir() unless (defined($dir));
	chdir($dir);
	Environment::logf("Updating instance \"" . $self->instanceName() . "\"...\n");
	$ret = $self->dmInstanceManager($dir . "lib${ps}lib" . $self->getEnv()->CDCBits(),
										 {cmd=>'update', tsname=>$self->instanceName(), newname=>$newname});
	if ($ret) {
		$self->instanceName($newname);
	}
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->start([$dir])
#-----------------------------------------------------------------------
#
# Invoke dmts32 utility to start CDC instance, where:
# $dir=CDC directory (optional)
#
#-----------------------------------------------------------------------
sub start
{
	my $self = shift;
	my $dir = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();
	my $prog = ($self->getEnv()->CDCBits() == 32) ? 'dmts32' : 'dmts64';

	$dir = $self->getEnv()->CDCSolidRootDir() unless (defined($dir));
	chdir($dir);

	Environment::logf("Starting TS Instance \"" . $self->instanceName() . "\"...\n");
	if ($self->getEnv()->getOSName() eq 'windows') {
		$command = "start /b bin${ps}${prog} -I " . $self->instanceName();
	} else {
		$command = ".${ps}bin${ps}${prog} -I " . $self->instanceName() . " &";
	}
	Environment::logf(">>COMMAND: $command\n");
	system($command) and  Environment::logf("***Error occurred in CDC::start***\n");
	sleep(10);
	Environment::logf("\n");
	sleep(5);
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->stop([$dir])
#-----------------------------------------------------------------------
#
# Invoke dmshutdown utility to stop instance of CDC, where:
# $dir=CDC directory (optional)
#
#-----------------------------------------------------------------------
sub stop
{
	my $self = shift;
	my $dir = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();

	$dir = $self->getEnv()->CDCSolidRootDir() unless (defined($dir));
	chdir($dir);
	Environment::logf("Shutting down TS Instance \"" . $self->instanceName() . "\"...\n");
	$command = ".${ps}bin${ps}dmshutdown -I " . $self->instanceName();
	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in CDC::stop***\n");
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->dmInstanceManager($libpath,$refParam)
#-----------------------------------------------------------------------
#
# Invoke instance manager where $libpath is the path to java libraries
# used by the instance manager and $refParam is a reference to a
# hash of parameter name/value pairs. Parameter names are:
# cmd=(add|delete|list), tsname, tsport, dbhost, dbname, dbuser, dbpass,
# dbschema, dbport, dbload, owmeta
# e.g.
# $ob->dmInstanceManager('./cdcsolid/lib',{cmd=>'add',tsname=>'ts_src',
#						 					tsport=>11101,dbport=>2315});
#
#-----------------------------------------------------------------------
sub dmInstanceManager
{
	my $self = shift;
	my $libdir = shift; # library path
	my $refParam = shift; # Hash reference of parameter name/values
	my $command;
	my $ret;

	$command = "java -Djava.library.path=\"$libdir\" -cp \"" . $self->classPath() . 
#	$command = "java -cp \"" . $self->classPath() . 
                   "\" com.datamirror.ts.commandlinetools.script.instancemanager.InstanceManager ";
	if ($refParam->{'cmd'}) { $command .= $refParam->{'cmd'} . ' '; }
	if ($refParam->{'bits'} && $refParam->{'bits'} == 64) { $command .= '-64 '; }
	if ($refParam->{'owmeta'} && $refParam->{'owmeta'} eq 'true') { $command .= '-overwritemeta '; }
	if ($refParam->{'tsname'}) { $command .= '-name ' . $refParam->{'tsname'} . ' '; }
	if ($refParam->{'tsport'}) { $command .= '-port ' . $refParam->{'tsport'} . ' '; }
	if ($refParam->{'dbhost'}) { $command .= '-dbhost ' . $refParam->{'dbhost'} . ' '; }
	if ($refParam->{'dbname'}) { $command .= '-dbname ' . $refParam->{'dbname'} . ' '; }
	if ($refParam->{'dbuser'}) { $command .= '-dbuser ' . $refParam->{'dbuser'} . ' '; }
	if ($refParam->{'dbpass'}) { $command .= '-dbpass ' . $refParam->{'dbpass'} . ' '; }
	if ($refParam->{'dbschema'}) { $command .= '-dbschema ' . $refParam->{'dbschema'} . ' '; }
	if ($refParam->{'dbport'}) { $command .= '-dbport ' . $refParam->{'dbport'} . ' '; }
	if ($refParam->{'dbload'}) { $command .= '-refreshloader ' . $refParam->{'dbload'} . ' '; }
    if ($refParam->{'dbserver'}) { $command .= '-idsserver ' . $refParam->{'dbserver'} . ' '; }
	if ($refParam->{'newname'}) { $command .= '-newname ' . $refParam->{'newname'} . ' '; }
	Environment::logf(">>COMMAND: $command\n");
	$ret = system($command);
	$ret and Environment::logf("***Error occurred in CDC::dmInstanceManager***\n");
	return($ret ? 0 : 1);
}


#############################################################
# GET/SET METHODS
#############################################################

#-----------------------------------------------------------------------
# $env = $ob->getEnv()
#-----------------------------------------------------------------------
#
# Get environment instance
#
#-----------------------------------------------------------------------
sub getEnv
{
	my $self = shift;
	return Environment::getEnvironment();
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
# $cfg = $ob->getConfig()
#-----------------------------------------------------------------------
#
# Get configuration object (class CDCConfig)
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
# $name = $ob->instanceName()
# $ob->instanceName($name)
#-----------------------------------------------------------------------
#
# Get/set CDC instance name
#
#-----------------------------------------------------------------------
sub instanceName
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ts_name'} = $name if defined($name);
	return $self->getConfigParams()->{'ts_name'};
}


#-----------------------------------------------------------------------
# $port = $ob->instancePort()
# $ob->instancePort($port)
#-----------------------------------------------------------------------
#
# Get/set CDC communication port
#
#-----------------------------------------------------------------------
sub instancePort
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ts_port'} = $name if defined($name);
	return $self->getConfigParams()->{'ts_port'};
}


#-----------------------------------------------------------------------
# $host = $ob->instanceHost()
# $ob->instanceHost($host)
#-----------------------------------------------------------------------
#
# Get/set CDC host name
#
#-----------------------------------------------------------------------
sub instanceHost
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ts_host'} = $name if defined($name);
	return $self->getConfigParams()->{'ts_host'};
}


#-----------------------------------------------------------------------
# $dir = $ob->CDCRootDir()
# $ob->CDCRootDir($dir)
#-----------------------------------------------------------------------
#
# Get/set CDC root directory
#
#-----------------------------------------------------------------------
sub CDCRootDir
{
	my ($self,$dir) = @_;
	$self->getConfigParams()->{'ts_root'} = $dir if defined($dir);
	return $self->getConfigParams()->{'ts_root'};
}

#-----------------------------------------------------------------------
# $db = $ob->database()
# $ob->database($db)
#-----------------------------------------------------------------------
#
# Get/set database associated with CDC instance
#
#-----------------------------------------------------------------------
sub database
{
	my ($self,$db) = @_;
	$self->{'DATABASE'} = $db if defined($db);
	return $self->{'DATABASE'};
}



#-----------------------------------------------------------------------
# $path = $ob->classPath()
# $ob->classPath($path)
#-----------------------------------------------------------------------
#
# Get/set java Class path for java utilities
#
#-----------------------------------------------------------------------
sub classPath
{
	my ($self,$name) = @_;
	$self->{'CLASSPATH'} = $name if defined($name);
	return $self->{'CLASSPATH'};
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


1;


=head1 NAME

CDC - (Super) class to implement common CDC/TS functionality as well as installation routines

=head1 SYNOPSIS

use IBM::UC::CDC;

#################.
# class methods #.
#################.

 $ob = CDC->new();

The constructor creates an instance encapsulating an empty CDCConfig object which must be populated by
a subclass.



#######################.
# object data methods #.
#######################.

### get versions ###

 $env = $ob->getEnv()
 $cfg = $ob->getConfig()
 $param = $ob->getConfigParams()
 $name = $ob->instanceName()
 $port = $ob->instancePort()
 $host = $ob->instanceHost()
 $dir = $ob->CDCRootDir()
 $db = $ob->database()
 $cp = $ob->classPath()

### set versions ###

 $ob->instanceName('src_ts')
 $ob->instancePort(11101)
 $ob->instanceHost('localhost')
 $ob->CDCRootDir('/home/user/Transformation for solidDB')
 $ob->database($db)
 $ob->classPath('xxx')


########################.
# other object methods #.
########################.

 CDC::install();  	# Install CDC
 CDC::uninstall();	# Uninstall CDC
 $ob->create([$d]); # Create CDC instance, where $d=CDC root directory (optional)
 $ob->delete([$d]);	# Delete CDC instance, where $d=CDC root directory (optional)
 $ob->list([$d]);	# List available CDC instances, where $d=CDC root directory (optional)
 $ob->update($newname,[$d]);	# Update instance name to new name
 $ob->start([$d]);	# Start CDC instance, where $d=CDC root directory (optional)
 $ob->stop([$d]);	# Stop CDC instance, where $d=CDC root directory (optional)
 $ob->printout();	# Prints out readable version of object's contents (for debug purposes)

=head1 DESCRIPTION

The CDC module is a super class encapsulating common functionality for CDCs. Specific
CDC functionality (DB2, Solid) is implemented in respective sub-classes (CDCDb2, CDCSolid, etc.).

=head1 EXAMPLES

See CDCSolid and CDCDb2 classes for examples of use.

=cut
