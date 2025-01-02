########################################################################
# 
# File   :  CDCDb2.pm
# History:  Dec-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# CDCDb2.pm is a sub-class of CDC.pm.
# It provides routines to install CDC for DB2 and create, start, stop,
# delete instances
# 
########################################################################
package CDCDb2;

use strict;

use IBM::UC::CDC;
#use IBM::UC::Repository::CDCDb2Repository;
use File::Path;
use File::Copy;
use UNIVERSAL qw(isa);

our @ISA = qw(CDC); # CDC super class


#-----------------------------------------------------------------------
# $ob = CDCDb2->createFromConfig($config,$db2)
#-----------------------------------------------------------------------
# 
# Create CDCDb2 object from existing CDCConfig object which is essentially a hash
# of parameter name/value pairs. Also takes Db2DB object as second parameter.
# See POD for allowed parameter names
# e.g.
# $db2 = Db2DB->createSimple('/home/db2inst1/db2inst1/NODE0000/TEST','TEST','db2admin')
# $config_values = { ts_name => 'src_ts', ts_port => '11101'};
# CDCDb2->createFromConfig(CDCConfig->createFromHash($config_values,$db2));
# 
#-----------------------------------------------------------------------
sub createFromConfig
{
	my $class = shift;
	my $cdc_cfg = shift;
	my $db2 = shift;
	my $self = {};

	# Make sure we get valid DB2 object as input
	if (!defined($db2)) {
		Environment::fatal("CDCDb2::createFromConfig requires DB2 instance as 2nd input\nExiting...\n");
	} elsif (ref($db2) ne 'Db2DB') {
		Environment::fatal("CDCDb2::createFromConfig: 2nd parameter not of type \"Db2DB\"\nExiting...\n");
	}

	# Make sure we get valid cdc configuration as first parameter
	if (!defined($cdc_cfg)) {
		Environment::fatal("CDCDb2::createFromConfig requires CDC configuration as 1st input\nExiting...\n");
	} elsif (ref($cdc_cfg) ne 'CDCConfig') {
		Environment::fatal("CDCDb2::createFromConfig: cdc configuration not of type \"CDCConfig\"\nExiting...\n");
	}

	$self = $class->SUPER::new();
	# store reference to database in object data
	$self->database($db2); 

	bless $self, $class;

	$self->init(); # set defaults

	# override defaults with parameters passed
	$self->getConfig()->initFromConfig($cdc_cfg->getParams());

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or 
		Environment::fatal("CDCDb2::createFromConfig: Error(s) occurred. Exiting...\n");
	
	return $self;
}


#-------------------------------------------------------------------------------------
# $ob = CDCDb2->createSimple($ts_name,$ts_port,$db2)
#-------------------------------------------------------------------------------------
#
# Create CDCDb2 object using fixed order parameters
# Parameters are instance name, instance port and Db2DB object, e.g.
# $db2 = Db2DB->createSimple('/home/db2inst1/db2inst1/NODE0000/TEST','TEST','db2admin');
# CDCDb2->createSimple('ts_src','11101',$db2)
#--------------------------------------------------------------------------------------
sub createSimple
{
	my $class = shift;
	my $cdc_name = shift;
	my $cdc_port = shift;
	my $db2 = shift;
	my $self = {};

	# Make sure we get cdc name and port
	if (!defined($cdc_name)) {
		Environment::fatal("CDCDb2::createSimple requires instance name as 1st input\nExiting...\n");
	}
	if (!defined($cdc_port)) {
		Environment::fatal("CDCDb2::createSimple requires instance port as 2nd parameter\nExiting...\n");
	}

	# Make sure we get valid DB2 object as input
	if (!defined($db2)) {
		Environment::fatal("CDCDb2::createSimple requires DB2 instance as 3rd input\nExiting...\n");
	} elsif (ref($db2) ne 'Db2DB') {
		Environment::fatal("CDCDb2::createSimple: 3rd parameter not of type \"Db2DB\"\nExiting...\n");
	}

	$self = $class->SUPER::new();
	# store reference to database in object data
	$self->database($db2); 

	bless $self, $class;

	$self->init(); # set defaults

	# override defaults with parameters passed
	$self->instanceName($cdc_name);
	$self->instancePort($cdc_port);

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or 
		Environment::fatal("CDCDb2::createSimple: Error(s) occurred. Exiting...\n");
	
	return $self;
}


#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise Db2DB CDC object parameters with default values
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

		# Set classpath environment variable (jar's are all taken from CDC Solid installation)
		$cp = $self->getEnv()->CDCSolidRootDir() . "samples${ps}ucutils${ps}lib${ps}uc-utilities.jar";
		$cp = $self->getEnv()->CDCSolidRootDir() . "lib${ps}api.jar" . $es . $cp;
		$cp = $self->getEnv()->CDCSolidRootDir() . "lib${ps}ts.jar" . $es . $cp;
		$self->classPath($cp);

		# Initialise root directory for DB2 CDC
		$self->CDCRootDir($self->getEnv()->CDCDb2RootDir());
		# Add to environment path variable
#		$ENV{'PATH'} = $self->getEnv()->accessServerRootDir() . "bin" . $es . 
#						$self->getEnv()->CDCDb2RootDir() . "bin" . $es . $ENV{'PATH'};
	
		# invoke super class' initialiser
		$self->SUPER::init();
		$self->initialised(1);
	}
}

#-----------------------------------------------------------------------
# $ob->install_from_cvs()
#-----------------------------------------------------------------------
#
# Copy latest CDC code from CVS respository and build
#
#-----------------------------------------------------------------------
sub install_from_cvs
{
}


#-----------------------------------------------------------------------
# CDCDb2->install($install_to,$install_from)
# CDCDb2::install($install_to,$install_from)
#-----------------------------------------------------------------------
#
# Install CDC for DB2 from package (local or on server) to local machine
# Routine must be called as static class method. If it is called using
# a CDCDb2 object the first parameter (object reference) will be
# mistakenly taken as the install_to location.
# $install_to=installation directory
# $install_from=source installation package
# e.g.
# CDCDb2->install('/home/user/Transformation Server for UDB',
#                   '/mnt/msoftware/TS-DB2/ts-db2-6.5.bin')
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


	# If sub was called via CDCDb2->install rather than CDCDb2::install, perl will silently
	# pass class name as first parameter
	if (@_ && ($_[0] eq 'CDCDb2')) { shift; }
	($install_to,$install_from) = @_;

	# Both input parameters are required
	if (!defined($install_from) || !defined($install_to)) {
		Environment::fatal("CDCDb2::install: Expecting two parameters as input.\nExiting...\n");
	}
		
	# Make sure path ends with path separator
	$install_to .= $ps if (substr($install_to,-1,1) !~ m/[\/\\]/);

	($f,$p) = File::Basename::fileparse($install_from);
	Environment::fatal("Cannot find install file \"$p$f\"\nExiting...\n") if (!(-f $p.$f));
	File::Path::rmtree($install_to,0,1);
	mkpath($install_to) if (!(-d $install_to));

	# Add installation bin directory to environment path variable
	$ENV{'PATH'} = $install_to . 'bin' . $es . $ENV{'PATH'};
	# Set CDC for DB2 path in environment module
	Environment::getEnvironment()->CDCDb2RootDir($install_to);

	# Needs double back-slashes in response file
	if (Environment::getEnvironment()->getOSName() eq 'windows') { $install_to =~ s/\\/\\\\/g; }

	chdir(Environment::getEnvironment()->getStartDir());

#FIX-ME :  Those lines should be removed as they change the file system.
#This comment is exisiting because such modification is due on each install method
#implemented in the framework.
#	File::Copy::cp($p.$f, $f);
#	chmod(0755,$f) if (Environment::getEnvironment()->getOSName() ne 'windows');
	$contents = "LICENSE_ACCEPTED=TRUE\n";
	$contents .= "INSTALLER_UI=silent\n";
	$contents .= "USER_INSTALL_DIR=$install_to\n";
	# Need this line for windows (need double back-slashes)
	if (Environment::getEnvironment()->getOSName() eq 'windows') {
		$contents .= "USER_SHORTCUTS=C:\\\\Documents and Settings\\\\Administrator\\\\Start Menu\\\\Programs\\\\TS-UDB";
	}
	open(OUT, ">$response_file") or Environment::fatal("CDCDb2::install: Cannot write to \"$response_file\": $!\n");
	print OUT $contents . "\n";
	close(OUT);

#FIX-ME : The path given should allow an installation to proceed from there. No file copy should be
#required.
#	$command = ".$ps$f -f $response_file";
	$command = "$install_from -f " . Environment::getEnvironment()->getStartDir() . $response_file;
	Environment::logf("\n>>Installing CDC for DB2 in $install_to\n");
	system($command) and Environment::logf("Error occurred in CDCDb2::install\n");

#FIX-ME :  Those lines should be removed as they remove file from system
#This comment is exisiting because such modification is due on each install method
#implemented in the framework.
#	unlink($f);
}



#-----------------------------------------------------------------------
# $ob->uninstall()
#-----------------------------------------------------------------------
#
# Uninstall CDC for Db2DB
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
	my $dir = $self->CDCRootDir();
	my $savecwd = Cwd::getcwd();
	my $ps = $self->getEnv()->getPathSeparator();
	my $refreshLoaderPath = $self->getConfigParams()->{'ts_db_refresh_loader'};
	my $command;
	
	$dir = $self->getEnv()->CDCSolidRootDir() unless (defined($dir));
	chdir($dir);

    # create refresh loader path if necessary
	$refreshLoaderPath = $self->database()->dbDir()."..${ps}loader" unless (defined($refreshLoaderPath));
	unless (-e $refreshLoaderPath) {
		mkdir($refreshLoaderPath);
	}
	
	Environment::logf(">>Creating TS Instance \"" . $self->instanceName() . "\"...\n");
	$self->dmInstanceManager($dir . "lib${ps}lib" . $self->getEnv()->CDCBits(),
				 			 {cmd=>'add', owmeta=>'true', bits=>$self->getEnv()->CDCBits(),
				 			  tsname=>$self->instanceName(),tsport=>$self->instancePort(),
				 			  dbname=>$self->database()->dbName(),dbuser=>$self->database()->dbUser(),
				 			  dbpass=>$self->database()->dbPass(),
				 			  dbschema=>uc($self->database()->dbSchema()),
				 			  dbload=>$refreshLoaderPath});
	chdir($savecwd);
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
# Invoke dmts32 utility to start instance of CDC for DB2
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
# Invoke dmshutdown utility to stop instance of CDC for DB2
#
#-----------------------------------------------------------------------
sub stop
{
	my $self = shift;
	$self->SUPER::stop($self->CDCRootDir());
}

	
1;


=head1 NAME

CDCDb2 - Class to implement CDC/TS functionality for DB2 (sub class of CDC)
           Module will also install/uninstall CDC for DB2 databases

=head1 SYNOPSIS

use IBM::UC::CDC::CDCDb2;

#################
# class methods #
#################

 $ob = CDCDb2->createFromConfig($cdc_cfg,$db2);
   where:
     $cdc_cfg=configuration object of class CDCConfig describing cdc instance
     $db2=database instance of class Db2DB

This constructor initialises itself from a configuration object defining parameters 
for the CDC instance, and the encapsulated DB2 database object.

 $ob = CDCDb2->createSimple($cdc_name, $cdc_port, $db2);
   where:
     $cdc_name=name of this cdc instance
     $cdc_port=port number for this cdc instance
     $db2=database instance of class Db2DB

This constructor initialises itself with a cdc instance name and port number, and
the encapsulated DB2 database object. 

 CDCDb2->install([$i_to]) (or CDCDb2::install)
  Install CDC for DB2 from CVS repository, where:
  	$i_to is the destination installation directory and
  	Parameter can be excluded as it is defaulted in the Environment module
  	
 CDCDb2::uninstall()

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

 $ob->create();		# Create DB2 CDC instance
 $ob->delete();		# Delete DB2 CDC instance
 $ob->list();		# List available CDC instances
 $ob->start();		# Start DB2 CDC instance
 $ob->stop();		# Stop DB2 CDC instance

=head1 DESCRIPTION

The CDCDb2 module is a sub class of CDC, and implements functionality specific to DB2
CDC instances. It can be used to initialise, create, start, delete, and stop DB2 CDC
instances.

Initialisation of the CDCDb2 object's data can be done in several ways. Default values are used for 
object parameters not explicitly specified in the object's creation.

Valid configuration parameters and their default values follow (see CDCConfig.pm):

 ---------------------------------------------------------------------------------------------------------
 Parameter		Description					Default value
 ---------------------------------------------------------------------------------------------------------
 ts_name		CDC instance name				src_ts
 ts_port		CDC instance communication port			11101
 ts_home		CDC root directory				Environment module default 
 ---------------------------------------------------------------------------------------------------------

if initialisation is via a configuration ini file the CDC section must, by default, start with [CDC]
and end with [/CDC] or end of file, e.g.:

 [CDC]

 ; Instance name for transformation server
 ts_name=solsrc_ts

 ; Communication port for transformation server
 ts_port=11101

=head1 EXAMPLES

Following are some examples of how to instantiate and use a CDCDb2 object.

 # Create DB2 database object from simple parameters
 # Create CDCDb2 object from simple parameters
 sub create_cdc_from_config
 {
	my $source = Db2DB->createSimple('/home/db2inst1/db2inst1/NODE0000/TEST','TEST','db2admin')
	$source->start();	
	
	my $cdc_db2 = CDCDb2->createSimple('src_ts',11101,$source);
	$cdc_db2->create();
	$cdc_db2->start();
	.
	.
	.
	$cdc_db2->stop();
	$cdc_db2->delete();
	$source->stop();
 }


 # Create DatabaseConfig object from hash map and use it to create DB2 database object
 # Create CDCConfig object from hash map
 # Use both config objects to create CDC object
 sub create_cdc_from_config
 {
	my $db2_values = { 
		db_name => 'test', 
		db_schema => 'schema1',
	};
	my $source = Db2DB->createFromConfig(DatabaseConfig->createFromHash($db2_values));
	$source->start();	
	
	my $cdc_values = {
		ts_name => 'ts_source',
		ts_port => 11121,
	};
	my $cdc_db2 = CDCDb2->createFromConfig(CDCConfig->createFromHash($cdc_value),$source);
	$cdc_db2->create();
	$cdc_db2->start();
	.
	.
	.
	$cdc_db2->stop();
	$cdc_db2->delete();
	$source->stop();
 }


 # Create DB2 database object from ini file
 # Create CDCConfig object from same ini file
 # Use both config objects to create CDC object
 sub create_cdc_from_file
 {
	my $source = Db2DB->createFromFile('db2_instance.ini'); # Load database section of ini file
	$source->start();
	
	my $cdc_cfg = CDCConfig->new('db2_instance1.ini');
	$cdc_cfg->initFromConfigFile(); # Load cdc-specific section of ini file

	my $cdc_db2 = CDCDb2->createFromConfig($cdc_cfg,$source);
	$cdc_db2->create();
	$cdc_db2->start();
	.
	.
	.
	$cdc_db2->stop();
	$cdc_db2->delete();
	$source->stop();
 }

An example of automating the creation of source and target databases, setting up replication between
tables in the databases and verifying that replication has taken place would be as follows:

 # Create subscription and mirror between DB2 source and DB2 target
 # Source and target tables use the same database but different schemas
 sub replication_db2_to_db2
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
		cdc_db2_root_dir => '/home/db2inst1/Transformation Server for UDB/',
		ant_version => 'apache-ant-1.6.2',
		java_home => '/home/DownloadDirector/ibm-java2-i386-50/',
		java6_home => '/home/DownloadDirector/ibm-java-i386-60/',
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));

	# create and start source database
	$dbvals_src = { 
		db_dir => '/home/db2inst1/db2inst1/NODE0000/TEST',
		db_name => 'TEST',
		db_user => 'db2inst1',
		db_pass => 'db2inst1',
	};
	$db_src = Db2DB->createFromConfig(DatabaseConfig->createFromHash($dbvals_src));
	$db_src->start();
	# createDatabase also connects to database
	$db_src->createDatabase();
	# Create source schema
	$db_src->createSchema('db2inst1');

	# Start target and connect to it (already created above)
	$dbvals_tgt = { 
		db_dir => '/home/db2inst1/db2inst1/NODE0000/TEST',
		db_name => 'TEST',
		db_user => 'db2inst1',
		db_pass => 'db2inst1',
	};
	$db_tgt = Db2DB->createFromConfig(DatabaseConfig->createFromHash($dbvals_tgt));
	$db_tgt->start();
	# Since we didn't create database on target we need to connect to it to execute sql
	$db_tgt->connectToDatabase();

	# Create target schema (has to be different from source for subscriptions to work)
	$db_tgt->createSchema('db2inst2');

	# Set table names for source and target sql
	$db_src->dbTableName('src');
	$db_tgt->dbTableName('tgt');
	$db_src->execSql('db2_createsrc.sql');	# Create table 'src'
	$db_tgt->execSql('db2_createtgt.sql');	# Create table 'tgt'
	
	# create source CDC
	$cdc_src = CDCDb2->createSimple('db2src_ts',11101,$db_src);

	# create target CDC
	$cdc_tgt = CDCDb2->createSimple('db2tgt_ts',11102,$db_tgt);

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
		'db2src_ds',		# datastore name
		'Source datastore',	# datastore description
		'localhost',		# datastore host
		$cdc_src,		# cdc instance
	);
	$ds_tgt = $mConsole->createDatastoreSimple(
		'db2tgt_ds',		# datastore name
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

	$db_src->execSql('db2_insertsrc.sql');	# Insert rows into source table
	sleep(15);				# Allow mirroring to take effect
	$db_tgt->execSql('db2_readtgt.sql');	# Read target table

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
