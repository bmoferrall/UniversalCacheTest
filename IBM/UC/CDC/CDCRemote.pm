########################################################################
# 
# File   :  CDCRemote.pm
# History:  Mar-2010 (bmof/ag) module created as part of Test Automation
#			project
#
########################################################################
#
# CDCRemote.pm is a sub-class of CDC.pm.
# It is designed to describe a CDC instance on a remote machine; 
# thus, it will have different (curtailed) behaviour to a normal CDC
# 
########################################################################
package CDCRemote;

use strict;

use IBM::UC::CDC;
use File::Path;
use File::Copy;
use UNIVERSAL qw(isa);

our @ISA = qw(CDC); # CDC super class


#-----------------------------------------------------------------------
# $ob = CDCRemote->createFromConfig($config,$db)
#-----------------------------------------------------------------------
# 
# Create CDCRemote object from existing CDCConfig object which is essentially a hash
# of parameter name/value pairs. Also takes RemoteDB object as second parameter.
# See POD for allowed parameter names
# e.g.
# $db = RemoteDB->createSimple('dbname','user','pass','schema',port)
# $cfg = { ts_name => 'src_ts', ts_port => '11101', ts_host => 'remotehost'};
# CDCRemote->createFromConfig(CDCConfig->createFromHash($cfg,$db));
# 
#-----------------------------------------------------------------------
sub createFromConfig
{
	my $class = shift;
	my $cdc_cfg = shift;
	my $db = shift;
	my $self = {};

	# Make sure we get valid RemoteDB object as input
	if (!defined($db)) {
		Environment::fatal("CDCRemote::createFromConfig requires RemoteDB instance as 2nd input\nExiting...\n");
	} elsif (ref($db) ne 'RemoteDB') {
		Environment::fatal("CDCRemote::createFromConfig: 2nd parameter not of type \"RemoteDB\"\nExiting...\n");
	}

	# Make sure we get valid cdc configuration as first parameter
	if (!defined($cdc_cfg)) {
		Environment::fatal("CDCRemote::createFromConfig requires CDC configuration as 1st input\nExiting...\n");
	} elsif (ref($cdc_cfg) ne 'CDCConfig') {
		Environment::fatal("CDCRemote::createFromConfig: cdc configuration not of type \"CDCConfig\"\nExiting...\n");
	}

	$self = $class->SUPER::new();
	# store reference to database in object data
	$self->database($db); 

	bless $self, $class;

	$self->init(); # set defaults
	Environment::logf(">>Creating Remote CDC instance for \"${\$db->dbType()}\" database...\n");

	# override defaults with parameters passed
	$self->getConfig()->initFromConfig($cdc_cfg->getParams());

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or 
		Environment::fatal("CDCRemote::createFromConfig: Error(s) occurred. Exiting...\n");

	Environment::logf(">>Done.\n");	
	return $self;
}


#-------------------------------------------------------------------------------------
# $ob = CDCRemote->createSimple($ts_name,$ts_port,$ts_host,$db)
#-------------------------------------------------------------------------------------
#
# Create CDCRemote object using fixed order parameters
# Parameters are instance name, instance port, instance host and RemoteDB object, e.g.
# $db = RemoteDB->createSimple('dbname','user','pass','schema',port)
# CDCRemote->createSimple('ts_src','11101','remotehost',$db)
#--------------------------------------------------------------------------------------
sub createSimple
{
	my $class = shift;
	my $cdc_name = shift;
	my $cdc_port = shift;
	my $cdc_host = shift;
	my $db = shift;
	my $self = {};

	# Make sure we get cdc name, port and host
	if (!defined($cdc_name)) {
		Environment::fatal("CDCRemote::createSimple requires instance name as 1st input\nExiting...\n");
	}
	if (!defined($cdc_port)) {
		Environment::fatal("CDCRemote::createSimple requires instance port as 2nd parameter\nExiting...\n");
	}
	if (!defined($cdc_host)) {
		Environment::fatal("CDCRemote::createSimple requires instance host as 3rd parameter\nExiting...\n");
	}

	# Make sure we get valid RemoteDB object as input
	if (!defined($db)) {
		Environment::fatal("CDCRemote::createSimple requires RemoteDB instance as 4th input\nExiting...\n");
	} elsif (ref($db) ne 'RemoteDB') {
		Environment::fatal("CDCRemote::createSimple: 4th parameter not of type \"RemoteDB\"\nExiting...\n");
	}

	$self = $class->SUPER::new();
	# store reference to database in object data
	$self->database($db); 

	bless $self, $class;

	Environment::logf(">>Creating Remote CDC instance for \"${\$db->dbType()}\" database...\n");
	$self->init(); # set defaults

	# override defaults with parameters passed
	$self->instanceName($cdc_name);
	$self->instancePort($cdc_port);
	$self->instanceHost($cdc_host);

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or 
		Environment::fatal("CDCRemote::createSimple: Error(s) occurred. Exiting...\n");
	
	Environment::logf(">>Done.\n");	
	return $self;
}


#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise Remote CDC object parameters with default values
#
#-----------------------------------------------------------------------
sub init
{
	my $self = shift;
	my $ps = $self->getEnv()->getPathSeparator();
	my $es = $self->getEnv()->getEnvSeparator();
	my $cp; # class path

	# Make sure we only initialise once,
	#    in case a user explicitly calls what is intended to be a private method
	if (!$self->initialised()) { 
		# Initialise some config parameters to default values
		$self->getConfig()->initFromConfig({ts_name => 'src_ts',
										    ts_port => '11101'});

		# Set classpath environment variable
		$cp = $self->getEnv()->CDCSolidRootDir() . "samples${ps}ucutils${ps}lib${ps}uc-utilities.jar";
		$cp = $self->getEnv()->CDCSolidRootDir() . "lib${ps}api.jar" . $es . $cp;
		$cp = $self->getEnv()->CDCSolidRootDir() . "lib${ps}ts.jar" . $es . $cp;
		$self->classPath($cp);

		# invoke super class' initialiser
		$self->SUPER::init();
		$self->initialised(1);
	}
}



#-----------------------------------------------------------------------
# $ob->install()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub install
{
	Environment::fatal("install() not implemented by CDCRemote\n");
}


#-----------------------------------------------------------------------
# $ob->create()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub create
{
	Environment::fatal("create() not implemented by CDCRemote\n");
}


#-----------------------------------------------------------------------
# $ob->delete()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub delete
{
	Environment::fatal("delete() not implemented by CDCRemote\n");
}


#-----------------------------------------------------------------------
# $ob->list()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub list
{
	Environment::fatal("list() not implemented by CDCRemote\n");
}


#-----------------------------------------------------------------------
# $ob->start()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub start
{
	Environment::fatal("start() not implemented by CDCRemote\n");
}


#-----------------------------------------------------------------------
# $ob->stop()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub stop
{
	Environment::fatal("stop() not implemented by CDCRemote\n");
}

1;


=head1 NAME

CDCRemote - Class designed to describe a CDC instance on a remote
            machine; thus, it will have different (curtailed) behavour
            to a normal CDC instance

=head1 SYNOPSIS

use IBM::UC::CDC::CDCRemote;

#################
# class methods #
#################

 $ob = CDCRemote->createFromConfig($cdc_cfg,$db);
   where:
     $cdc_cfg=configuration object of class CDCConfig describing cdc instance
     $db=database instance of class RemoteDB

This constructor initialises itself from a configuration object defining parameters 
for the CDC instance, and the encapsulated Remote database object.

 $ob = CDCRemote->createSimple($cdc_name, $cdc_port, $cdc_host, $db);
   where:
     $cdc_name=name of this cdc instance
     $cdc_port=port number for this cdc instance
     $cdc_host=host name where cdc instance lives
     $db=database instance of class RemoteDB

This constructor initialises itself with a cdc instance name, port number and
host name, and the encapsulated Remote database object. 

#######################
# object data methods #
#######################

### get versions ###

 See CDC super class for available get methods

### set versions ###

 See CDC super class for available set methods

########################
# other object methods #
########################


=head1 DESCRIPTION

The CDCRemote module is a sub class of CDC, and is designed to describe a
CDC instance on a remote machine. The object behaves differently to a normal
CDC instance in that the instance cannot be created, started, stopped, deleted,
etc.

Initialisation of the CDCRemote object's data can be done in several ways. Default values are used for 
object parameters not explicitly specified in the object's creation.

Valid configuration parameters and their default values follow (see CDCConfig.pm):

 ---------------------------------------------------------------------------------------------------------
 Parameter		Description					Default value
 ---------------------------------------------------------------------------------------------------------
 ts_name		CDC instance name				src_ts
 ts_port		CDC instance communication port			11101
 ts_host		CDC instance host name			localhost
 ts_home		CDC root directory				Environment module default 
 ---------------------------------------------------------------------------------------------------------

if initialisation is via a configuration ini file the format is as follows:

 [CDC]

 ; Instance name for transformation server
 ts_name=solsrc_ts

 ; Communication port for transformation server
 ts_port=11101

 ; Host name of transformation server
 ts_host=localhost
 
=head1 EXAMPLES


=cut
