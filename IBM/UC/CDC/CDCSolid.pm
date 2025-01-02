########################################################################
# 
# File   :  CDCSolid.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# CDCSolid.pm is a sub-class of CDC.pm.
# It provides routines to install CDC for SolidDB and create, start, stop,
# delete instances
# 
########################################################################
package CDCSolid;

use strict;

use IBM::UC::CDC;
use IBM::UC::Repository::CDCSolidRepository;
use File::Path;
use File::Copy;
use UNIVERSAL qw(isa);

our @ISA = qw(CDC); # CDC super class


#-----------------------------------------------------------------------
# $ob = CDCSolid->createFromConfig($config,$solid)
#-----------------------------------------------------------------------
# 
# Create CDCSolid object from existing CDCConfig object which is essentially a hash
# of parameter name/value pairs. Also takes SolidDB object as second parameter.
# See POD for allowed parameter names
# e.g.
# $solid = SolidDB->createSimple('/home/db2inst1/solid/src',2315);
# $config_values = { ts_name => 'src_ts', ts_port => '11101'};
# CDCSolid->createFromConfig(CDCConfig->createFromHash($config_values,$solid));
# 
#-----------------------------------------------------------------------
sub createFromConfig
{
	my $class = shift;
	my $cdc_cfg = shift;
	my $solid = shift;
	my $self = {};

	# Make sure we get valid solid object as input
	if (!defined($solid)) {
		Environment::fatal("CDCSolid::createFromConfig requires solid instance as 2nd input\nExiting...\n");
	} elsif (ref($solid) ne 'SolidDB') {
		Environment::fatal("CDCSolid::createFromConfig: 2nd parameter not of type \"SolidDB\"\nExiting...\n");
	}

	# Make sure we get valid cdc configuration as first parameter
	if (!defined($cdc_cfg)) {
		Environment::fatal("CDCSolid::createFromConfig requires CDC configuration as 1st input\nExiting...\n");
	} elsif (ref($cdc_cfg) ne 'CDCConfig') {
		Environment::fatal("CDCSolid::createFromConfig: cdc configuration not of type \"CDCConfig\"\nExiting...\n");
	}

	$self = $class->SUPER::new();
	# store reference to database in object data
	$self->database($solid); 

	bless $self, $class;

	$self->init(); # set defaults

	# override defaults with parameters passed
	$self->getConfig()->initFromConfig($cdc_cfg->getParams());

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or 
		Environment::fatal("CDCSolid::createFromConfig: Error(s) occurred. Exiting...\n");
	
	return $self;
}


#-------------------------------------------------------------------------------------
# $ob = CDCSolid->createSimple($ts_name,$ts_port,$solid)
#-------------------------------------------------------------------------------------
#
# Create CDCSolid object using fixed order parameters
# Parameters are instance name, instance port and SolidDB object, e.g.
# $solid = SolidDB->createSimple('/home/db2inst1/solid/src',2315);
# CDCSolid->createSimple('ts_src','11101',$solid)
#--------------------------------------------------------------------------------------
sub createSimple
{
	my $class = shift;
	my $cdc_name = shift;
	my $cdc_port = shift;
	my $solid = shift;
	my $self = {};

	# Make sure we get cdc name and port
	if (!defined($cdc_name)) {
		Environment::fatal("CDCSolid::createSimple requires instance name as 1st input\nExiting...\n");
	}
	if (!defined($cdc_port)) {
		Environment::fatal("CDCSolid::createSimple requires instance port as 2nd parameter\nExiting...\n");
	}

	# Make sure we get valid solid object as input
	if (!defined($solid)) {
		Environment::fatal("CDCSolid::createSimple requires solid instance as 3rd input\nExiting...\n");
	} elsif (ref($solid) ne 'SolidDB') {
		Environment::fatal("CDCSolid::createSimple: 3rd parameter not of type \"SolidDB\"\nExiting...\n");
	}

	$self = $class->SUPER::new();
	# store reference to database in object data
	$self->database($solid); 

	bless $self, $class;

	$self->init(); # set defaults

	# override defaults with parameters passed
	$self->instanceName($cdc_name);
	$self->instancePort($cdc_port);

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or 
		Environment::fatal("CDCSolid::createSimple: Error(s) occurred. Exiting...\n");
	
	return $self;
}


#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise SolidDB CDC object parameters with default values
# Set up java class path used by some CDC utilities and udpate
# path environment variable
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

		# Initialise root directory for Solid CDC
		$self->CDCRootDir($self->getEnv()->CDCSolidRootDir());
		# Add to environment path variable
		$ENV{'PATH'} = $self->getEnv()->accessServerRootDir() . "bin" . $es . 
						$self->getEnv()->CDCSolidRootDir() . "bin" . $es . $ENV{'PATH'};
	
		# invoke super class' initialiser
		$self->SUPER::init();
		$self->initialised(1);
	}
}


#-----------------------------------------------------------------------
# $ob->install_from_cvs([$install_to])
#-----------------------------------------------------------------------
#
# Copy latest CDC code from CVS respository and build, where:
# $install_to=installation directory (optional)
# If not provided, cdc is installed to default location in Environment.pm
#
#-----------------------------------------------------------------------
sub install_from_cvs
{
	my $install_to;
	my $cdc_repos = CDCSolidRepository->new();
	my $es = Environment::getEnvironment()->getEnvSeparator();

	# If sub was called via CDCSolid->install rather than CDCSolid::install, perl will silently
	# pass class name as first parameter
	if (@_ && ($_[0] eq 'CDCSolid')) { shift; }
	($install_to) = @_;
	
	Environment::getEnvironment()->CDCSolidRootDir($install_to) if (defined($install_to));

	$cdc_repos->copy();
	$cdc_repos->build();

	# Add installation directory to environment path variable
#	$ENV{'PATH'} = Environment::getEnvironment()->CDCSolidRootDir() . 'bin' . $es . $ENV{'PATH'};
}



#-----------------------------------------------------------------------
# CDCSolid->install($install_to,$install_from)
# CDCSolid::install($install_to,$install_from)
#-----------------------------------------------------------------------
#
# Install CDC for Solid from package (local or on server) to local machine
# Routine must be called as static class method. If it is called using
# a CDCSolid object the first parameter (object reference) will be
# mistakenly taken as the install_to location.
# $install_to=installation directory
# $install_from=source installation package
# e.g.
# CDCSolid->install('/home/user/Transformation Server for solidDB',
#                   '/mnt/msoftware/TS-Solid/ts-solid-6.5.bin')
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


	# If sub was called via CDCSolid->install rather than CDCSolid::install, perl will silently
	# pass class name as first parameter
	if (@_ && ($_[0] eq 'CDCSolid')) { shift; }
	($install_to,$install_from) = @_;

	# Both input parameters are required
	if (!defined($install_from) || !defined($install_to)) {
		Environment::fatal("CDCSolid::install: Expecting two parameters as input.\nExiting...\n");
	}
		
	# Make sure path ends with path separator
	$install_to .= $ps if (substr($install_to,-1,1) !~ m/[\/\\]/);

	($f,$p) = File::Basename::fileparse($install_from);
	Environment::fatal("Cannot find install file \"$p$f\"\nExiting...\n") if (!(-f $p.$f));
	File::Path::rmtree($install_to,0,1);
	mkpath($install_to) if (!(-d $install_to));

	# Set CDC for Solid path in environment module
	Environment::getEnvironment()->CDCSolidRootDir($install_to);
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
	# Need this line for windows (need double back-slashes)
	if (Environment::getEnvironment()->getOSName() eq 'windows') {
		$contents .= "USER_SHORTCUTS=C:\\\\Documents and Settings\\\\Administrator\\\\Start Menu\\\\Programs\\\\TS-SolidDB";
	}
	open(OUT, ">$response_file") or Environment::fatal("CDCSolid::install: Cannot write to \"$response_file\": $!\n");
	print OUT $contents . "\n";
	close(OUT);

	$command = ".$ps$f -f $response_file";
	Environment::logf("\n>>Installing CDC for Solid in $install_to\n");
	system($command) and Environment::logf("Error occurred in CDCSolid::install\n");
	unlink($f);
}



#-----------------------------------------------------------------------
# $ob->uninstall()
#-----------------------------------------------------------------------
#
# Uninstall CDC for SolidDB
#
#-----------------------------------------------------------------------
sub uninstall
{
}


#-----------------------------------------------------------------------
# $ob->create()
#-----------------------------------------------------------------------
#
# Invoke instance manager to create CDC instance with parameters
# supplied during object's creation
#
#-----------------------------------------------------------------------
sub create
{
	my $self = shift;
	$self->SUPER::create($self->CDCRootDir());
}


#-----------------------------------------------------------------------
# $ob->delete()
#-----------------------------------------------------------------------
#
# Invoke instance manager to delete CDC instance with parameters
# supplied during object's creation
#
#-----------------------------------------------------------------------
sub delete
{
	my $self = shift;
	$self->SUPER::delete($self->CDCRootDir());
}


#-----------------------------------------------------------------------
# $ob->list()
#-----------------------------------------------------------------------
#
# Invoke instance manager to list available CDC instances
#
#-----------------------------------------------------------------------
sub list
{
	my $self = shift;
	$self->SUPER::list($self->CDCRootDir());
}


#-----------------------------------------------------------------------
# $ob->start()
#-----------------------------------------------------------------------
#
# Invoke dmts32 utility to start instance of CDC for Solid
#
#-----------------------------------------------------------------------
sub start
{
	my $self = shift;
	$self->SUPER::start($self->CDCRootDir());
}


#-----------------------------------------------------------------------
# $ob->stop()
#-----------------------------------------------------------------------
#
# Invoke dmshutdown utility to stop instance of CDC for Solid
#
#-----------------------------------------------------------------------
sub stop
{
	my $self = shift;
	$self->SUPER::stop($self->CDCRootDir());
}

	
1;


=head1 NAME

CDCSolid - Class to implement CDC/TS functionality for Solid (sub class of CDC)
           Module will also install/uninstall CDC for Solid databases

=head1 SYNOPSIS

use IBM::UC::CDC::CDCSolid;

#################
# class methods #
#################

 $ob = CDCSolid->createFromConfig($cdc_cfg,$solid);
   where:
     $cdc_cfg=configuration object of class CDCConfig describing cdc instance
     $solid=database instance of class SolidDB

This constructor initialises itself from a configuration object defining parameters 
for the CDC instance, and the encapsulated Solid database object.

 $ob = CDCSolid->createSimple($cdc_name, $cdc_port, $solid);
   where:
     $cdc_name=name of this cdc instance
     $cdc_port=port number for this cdc instance
     $solid=database instance of class SolidDB

This constructor initialises itself with a cdc instance name and port number, and
the encapsulated Solid database object. 

 CDCSolid->install([$i_to]) (or CDCSolid::install)
  Install CDC for Solid from CVS repository, where:
  	$i_to is the destination installation directory and
  	Parameter can be excluded as it is defaulted in the Environment module
  	
 CDCSolid::uninstall()

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

 $ob->create();		# Create Solid CDC instance
 $ob->delete();		# Delete Solid CDC instance
 $ob->list();		# List available CDC instances
 $ob->start();		# Start Solid CDC instance
 $ob->stop();		# Stop Solid CDC instance

=head1 DESCRIPTION

The CDCSolid module is a sub class of CDC, and implements functionality specific to Solid
CDC instances. It can be used to initialise, create, start, delete, and stop Solid CDC
instances.

Initialisation of the CDCSolid object's data can be done in several ways. Default values are used for 
object parameters not explicitly specified in the object's creation.

Valid configuration parameters and their default values follow (see CDCConfig.pm):

 ---------------------------------------------------------------------------------------------------------
 Parameter		Description					Default value
 ---------------------------------------------------------------------------------------------------------
 ts_name		CDC instance name				src_ts
 ts_port		CDC instance communication port			11101
 ts_root		CDC root directory				Environment module default 
 ---------------------------------------------------------------------------------------------------------

if initialisation is via a configuration ini file the CDC section must, by default, start with [CDC]
and end with [/CDC] or end of file, e.g.:

 [CDC]

 ; Instance name for transformation server
 ts_name=solsrc_ts

 ; Communication port for transformation server
 ts_port=11101

=head1 EXAMPLES

Following are some examples of how to instantiate and use a CDCSolid object.

 # Create solid database object from simple parameters
 # Create SolidCDC object from simple parameters
 sub create_cdc_from_config
 {
	my $source = SolidDB->createSimple('/home/user/solid','src',2315);
	$source->start();	
	
	my $cdc_sol = CDCSolid->createSimple('src_ts',11101,$source);
	$cdc_sol->create();
	$cdc_sol->start();
	.
	.
	.
	$cdc_sol->stop();
	$cdc_sol->delete();
	$source->stop();
 }


 # Create DatabaseConfig object from hash map and use it to create solid database object
 # Create CDCConfig object from hash map
 # Use both config objects to create CDC object
 sub create_cdc_from_config
 {
	my $sol_values = { 
		db_port => '2317', 
		db_dir => 'sol_source',
	};
	my $source = SolidDB->createFromConfig(DatabaseConfig->createFromHash($sol_values));
	$source->start();	
	
	my $cdc_values = {
		ts_name => 'ts_source',
		ts_port => 11121,
	};
	my $cdc_sol = CDCSolid->createFromConfig(CDCConfig->createFromHash($cdc_value),$source);
	$cdc_sol->create();
	$cdc_sol->start();
	.
	.
	.
	$cdc_sol->stop();
	$cdc_sol->delete();
	$source->stop();
 }


 # Create solid database object from ini file
 # Create CDCConfig object from same ini file
 # Use both config objects to create CDC object
 sub create_cdc_from_file
 {
	my $source = SolidDB->createFromFile('solid_instance.ini'); # Load database section of ini file
	$source->start();
	
	my $cdc_cfg = CDCConfig->new('solid_instance1.ini');
	$cdc_cfg->initFromConfigFile(); # Load cdc-specific section of ini file

	my $cdc_sol = CDCSolid->createFromConfig($cdc_cfg,$source);
	$cdc_sol->create();
	$cdc_sol->start();
	.
	.
	.
	$cdc_sol->stop();
	$cdc_sol->delete();
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
