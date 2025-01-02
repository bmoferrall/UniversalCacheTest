########################################################################
# 
# File   :  CDCInformix.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#            project
#
########################################################################
#
# CDCInformix.pm is a sub-class of CDC.pm.
# It provides routines to install CDC for InformixDB and create, start, stop,
# delete instances
# 
########################################################################
package CDCInformix;

use strict;

use IBM::UC::CDC;
#use IBM::UC::Repository::CDCInformixRepository;
use File::Path;
use File::Copy;
use UNIVERSAL qw(isa);

our @ISA = qw(CDC); # CDC super class

#-----------------------------------------------------------------------
# $ob = CDCInformix->createFromConfig($config,$solid)
#-----------------------------------------------------------------------
# 
# Create CDCInformix object from existing CDCConfig object which is essentially a hash
# of parameter name/value pairs. Also takes InformixDB object as second parameter.
# See POD for allowed parameter names
# e.g.
# $informix = InformixDB->createSimple('/home/db2inst1/solid/src',2315);
# $config_values = { ts_name => 'src_ts', ts_port => '11101'};
# $informixCDC = CDCInformix->createFromConfig(CDCConfig->createFromHash($config_values,$informix));
# 
#-----------------------------------------------------------------------
sub createFromConfig
{
    my $class = shift;
    my $cdc_cfg = shift;
    my $informix = shift;
    my $self = {};

    # Make sure we get valid informix object as input
    if (!defined($informix)) {
        Environment::fatal("CDCInformix::createFromConfig requires informix instance as 2nd input\nExiting...\n");
    } elsif (ref($informix) ne 'InformixDB') {
        Environment::fatal("CDCInformix::createFromConfig: 2nd parameter not of type \"InformixDB\"\nExiting...\n");
    }

    # Make sure we get valid cdc configuration as first parameter
    if (!defined($cdc_cfg)) {
        Environment::fatal("CDCInformix::createFromConfig requires CDC configuration as 1st input\nExiting...\n");
    } elsif (ref($cdc_cfg) ne 'CDCConfig') {
        Environment::fatal("CDCInformix::createFromConfig: cdc configuration not of type \"CDCConfig\"\nExiting...\n");
    }

    $self = $class->SUPER::new();
    # store reference to database in object data
    $self->database($informix); 

    bless $self, $class;

    $self->init(); # set defaults

    # override defaults with parameters passed
    $self->getConfig()->initFromConfig($cdc_cfg->getParams());

    # Check that config is fully initialised    
    $self->getConfig()->checkRequired() or 
        Environment::fatal("CDCInformix::createFromConfig: Error(s) occurred. Exiting...\n");
    
    return $self;
}


#-------------------------------------------------------------------------------------
# $ob = CDCInformix->createSimple($ts_name,$ts_port,$informix)
#-------------------------------------------------------------------------------------
#
# Create CDCInformix object using fixed order parameters
# Parameters are instance name, instance port and InformixDB object, e.g.
# $informix = InformixDB->createSimple('/home/db2inst1/solid/src',2315);
# CDCInformix->createSimple('ts_src','11101',$informix)
#--------------------------------------------------------------------------------------
sub createSimple
{
    my $class = shift;
    my $cdc_name = shift;
    my $cdc_port = shift;
    my $informix = shift;
    my $self = {};

    # Make sure we get cdc name and port
    if (!defined($cdc_name)) {
        Environment::fatal("CDCInformix::createSimple requires instance name as 1st input\nExiting...\n");
    }
    if (!defined($cdc_port)) {
        Environment::fatal("CDCInformix::createSimple requires instance port as 2nd parameter\nExiting...\n");
    }

    # Make sure we get valid informix object as input
    if (!defined($informix)) {
        Environment::fatal("CDCInformix::createSimple requires informix instance as 3rd input\nExiting...\n");
    } elsif (ref($informix) ne 'InformixDB') {
        Environment::fatal("CDCInformix::createSimple: 3rd parameter not of type \"InformixDB\"\nExiting...\n");
    }

    $self = $class->SUPER::new();
    # store reference to database in object data
    $self->database($informix); 

    bless ($self, $class);

    $self->init(); # set defaults

    # override defaults with parameters passed
    $self->instanceName($cdc_name);
    $self->instancePort($cdc_port);

    # Check that config is fully initialised    
    $self->getConfig()->checkRequired() or 
        Environment::fatal("CDCInformix::createSimple: Error(s) occurred. Exiting...\n");
    return $self;
}


#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise InformixDB CDC object parameters with default values
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
    # in case a user explicitly calls what is intended to be a private method
    if (!$self->initialised()) { 
        # Initialise some config parameters to default values
        $self->getConfig()->initFromConfig({ts_name => 'src_ts',
                                            ts_port => '10201'});

        # Set classpath environment variable (jars are all taken from CDC for solidDB's installation
        $cp = $self->getEnv()->CDCSolidRootDir() . "samples${ps}ucutils${ps}lib${ps}uc-utilities.jar";
        $cp = $self->getEnv()->CDCSolidRootDir() . "lib${ps}api.jar" . $es . $cp;
        $cp = $self->getEnv()->CDCSolidRootDir() . "lib${ps}ts.jar" . $es . $cp;
        $self->classPath($cp);

        # Initialise root directory for Informix CDC
        $self->CDCRootDir($self->getEnv()->CDCInformixRootDir());

        # Add to environment path variable
        $ENV{'PATH'} = $self->getEnv()->accessServerRootDir() .  "bin" .  $es . 
                       $self->getEnv()->CDCInformixRootDir() .  "bin" .  $es .
                       $ENV{'PATH'};
    
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
#sub install_from_cvs
#{
#    my $install_to;
#    my $cdc_repos = CDCInformixRepository->new();
#    my $es = Environment::getEnvironment()->getEnvSeparator();
#
#    # If sub was called via CDCInformix->install rather than CDCInformix::install, perl will silently
    # pass class name as first parameter
#    if (@_ && ($_[0] eq 'CDCInformix')) { shift; }
#    ($install_to) = @_;
    
#    Environment::getEnvironment()->CDCInformixRootDir($install_to) if (defined($install_to));

#    $cdc_repos->copy();
#    $cdc_repos->build();

    # Add installation directory to environment path variable
#    $ENV{'PATH'} = Environment::getEnvironment()->CDCInformixRootDir() . 'bin' . $es . $ENV{'PATH'};
#}

#-----------------------------------------------------------------------
# CDCInformix->install($install_to,$install_from)
# CDCInformix::install($install_to,$install_from)
#-----------------------------------------------------------------------
#
# Install CDC for Informix from package (local or on server) to local machine
# Routine must be called as static class method. If it is called using
# a CDCInformix object the first parameter (object reference) will be
# mistakenly taken as the install_to location.
# $install_to=installation directory
# $install_from=source installation package
# e.g.
# CDCInformix->install('/home/user/Transformation Server for solidDB',
#                   '/mnt/msoftware/TS-Informix/ts-solid-6.5.bin')
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

    # If sub was called via CDCInformix->install rather than CDCInformix::install, perl will silently
    # pass class name as first parameter

    if (@_ && ($_[0] eq 'CDCInformix')) { shift; }
        ($install_to,$install_from) = @_;

    # Both input parameters are required
    if (!defined($install_from) || !defined($install_to)) {
        Environment::fatal("CDCInformix::install: Expecting two parameters as input.\nExiting...\n");
    }
        
    # Make sure path ends with path separator
    $install_to .= $ps if (substr($install_to,-1,1) !~ m/[\/\\]/);

    ($f,$p) = File::Basename::fileparse($install_from);
    Environment::fatal("Cannot find install file \"$p$f\"\nExiting...\n") if (!(-f $p.$f));
    File::Path::rmtree($install_to,0,1);
    mkpath($install_to) if (!(-d $install_to));

    # Add installation bin directory to environment path variable
    $ENV{'PATH'} = $install_to . 'bin' . $es . $ENV{'PATH'};
    
    # Set CDC for Informix path in environment module
    Environment::getEnvironment()->CDCInformixRootDir($install_to);

    # Needs double back-slashes in response file
    if (Environment::getEnvironment()->getOSName() eq 'windows') { $install_to =~ s/\\/\\\\/g; }

    chdir(Environment::getEnvironment()->getStartDir());
    File::Copy::cp($p.$f, $f);
    chmod(0755,$f) if (Environment::getEnvironment()->getOSName() ne 'windows');
    $contents = "LICENSE_ACCEPTED=TRUE\n" . 
                "INSTALLER_UI=silent\n" .
                "USER_INSTALL_DIR=$install_to\n";

    # Need this line for windows (need double back-slashes)
    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $contents .= "USER_SHORTCUTS=C:\\\\Documents and Settings\\\\Administrator\\\\Start Menu\\\\Programs\\\\Transformation Server for Informix";
    }

    open(OUT, ">$response_file") or Environment::fatal("CDCInformix::install: Cannot write to \"$response_file\": $!\n");
    print OUT $contents . "\n";
    close(OUT);
    
    if (Environment::getEnvironment()->getOSName() eq 'windows') { 
        # can't do a silent installation on windows
        #$command = "$f -f $response_file";
        $command = "$f";
    }
    else {
        $command = ".$ps$f -f $response_file";
    }
   
    Environment::logf("\n>>Installing CDC for Informix in $install_to\n");
    system($command) and Environment::logf("Error occurred in CDCInformix::install\n");
    unlink($f);
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
    my $bits = $self->getEnv()->CDCBits();
    
    $dir = $self->getEnv()->CDCSolidRootDir() unless (defined($dir));
    chdir($dir);
    
    Environment::logf(">>Creating TS Instance \"" . $self->instanceName() . "\"...\n");
    $self->dmInstanceManager($dir . "lib${ps}lib${bits}",
                             {
                              cmd=>'add',
                              bits=>$self->getEnv()->CDCBits(),
                              owmeta=>'true',  
                              tsname=>$self->instanceName(),
                              tsport=>$self->instancePort(),
                              dbserver=>$self->database()->instanceName(),
                              dbport=>$self->database()->dbPort(),
                              dbhost=>$self->database()->dbHost(),
                              dbname=>$self->database()->dbName(),
                              dbuser=>$self->database()->dbUser(),
                              dbpass=>$self->database()->dbPass(),
                              dbschema=>$self->database()->dbSchema()
                             }
                            );
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
# $ob->start()
#-----------------------------------------------------------------------
#
# Invoke dmts32 utility to start instance of CDC for Informix
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
# Invoke dmshutdown utility to stop instance of CDC for Informix
#
#-----------------------------------------------------------------------
sub stop
{
    my $self = shift;
    $self->SUPER::stop($self->CDCRootDir());
}
    
1;

=head1 NAME

CDCInformix - Class to implement CDC/TS functionality for Informix (sub class of CDC)
           Module will also install/uninstall CDC for Informix databases

=head1 SYNOPSIS

use IBM::UC::CDC::CDCInformix;

#################
# class methods #
#################

 $ob = CDCInformix->createFromConfig($cdc_cfg,$informix);
   where:
     $cdc_cfg=configuration object of class CDCConfig describing cdc instance
     $solid=database instance of class InformixDB

This constructor initialises itself from a configuration object defining parameters 
for the CDC instance, and the encapsulated Informix database object.

 $ob = CDCInformix->createSimple($cdc_name, $cdc_port, $solid);
   where:
     $cdc_name=name of this cdc instance
     $cdc_port=port number for this cdc instance
     $informix=database instance of class InformixDB

This constructor initialises itself with a cdc instance name and port number, and
the encapsulated Informix database object. 

 CDCInformix->install([$i_to]) (or CDCInformix::install)
  Install CDC for Informix from CVS repository, where:
      $i_to is the destination installation directory and
      Parameter can be excluded as it is defaulted in the Environment module
      
 CDCInformix::uninstall()

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

 $ob->create();        # Create Informix CDC instance
 $ob->delete();        # Delete Informix CDC instance
 $ob->list();        # List available CDC instances
 $ob->start();        # Start Informix CDC instance
 $ob->stop();        # Stop Informix CDC instance

=head1 DESCRIPTION

The CDCInformix module is a sub class of CDC, and implements functionality specific to Informix
CDC instances. It can be used to initialise, create, start, delete, and stop Informix CDC
instances.

Initialisation of the CDCInformix object's data can be done in several ways. Default values are used for 
object parameters not explicitly specified in the object's creation.

Valid configuration parameters and their default values follow (see CDCConfig.pm):

 ---------------------------------------------------------------------------------------------------------
 Parameter        Description                    Default value
 ---------------------------------------------------------------------------------------------------------
 ts_name        CDC instance name                src_ts
 ts_port        CDC instance communication port  10901
 ts_root        CDC root directory               Environment module default 
 ---------------------------------------------------------------------------------------------------------

if initialisation is via a configuration ini file the AccessServer section must start with [CDC]
and end with [DATASTORE] or end of file, e.g.:

 [CDC]

 ; Instance name for transformation server
 ts_name=solsrc_ts

 ; Communication port for transformation server
 ts_port=11101

=head1 EXAMPLES

Following are some examples of how to instantiate and use a CDCInformix object.

 # Create Informix database object from simple parameters
 # Create InformixCDC object from simple parameters
 sub create_cdc_from_config
 {
    my $source = InformixDB->createSimple('/home/user/informix','src',3333);
    $source->start();    
    
    my $cdc_sol = CDCInformix->createSimple('src_ts',11101,$source);
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
    my $source = InformixDB->createFromConfig(DatabaseConfig->createFromHash($sol_values));
    $source->start();    
    
    my $cdc_values = {
        ts_name => 'ts_source',
        ts_port => 11121,
    };
    my $cdc_sol = CDCInformix->createFromConfig(CDCConfig->createFromHash($cdc_value),$source);
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
    my $source = InformixDB->createFromFile('solid_instance.ini'); # Load database section of ini file
    $source->start();
    
    my $cdc_cfg = CDCConfig->new('solid_instance1.ini');
    $cdc_cfg->initFromConfigFile(stag, etag); # Load cdc-specific section of ini file

    my $cdc_sol = CDCInformix->createFromConfig($cdc_cfg,$source);
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

 # Create subscription and mirror between Informix source and Informix target
 sub replication_inf_to_inf
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
    $db_src = InformixDB->createFromConfig(DatabaseConfig->createFromHash($dbvals_src));
    $db_src->start();

    # create and start target database
    $dbvals_tgt = { 
        db_port => '2316', 
        db_dir => '/home/db2inst1/solid/sol_tgt',
    };
    $db_tgt = InformixDB->createFromConfig(DatabaseConfig->createFromHash($dbvals_tgt));
    $db_tgt->start();

    # Set source and target table names for sql files
    # %TABLE% in sql files will be replaced with table names specified here
    $db_src->dbTableName('src');
    $db_tgt->dbTableName('tgt');
    $db_src->execSql('sol_createsrc.sql');    # Create table 'src'
    $db_tgt->execSql('sol_createtgt.sql');    # Create table 'tgt'
    
    # create source CDC
    $cdc_src = CDCInformix->createSimple('solsrc_ts',11101,$db_src);

    # create target CDC
    $cdc_tgt = CDCInformix->createSimple('soltgt_ts',11102,$db_tgt);

    # create and start source/target cdc's
    $cdc_src->create();
    $cdc_tgt->create();
    $cdc_src->start();
    $cdc_tgt->start();

    # Access server configuration 
    $as_cfg = {ac_host => 'localhost',    # Access server host
                   ac_port => '10101',    # Access server port
                  ac_user => 'Admin',    # Access server user
                  ac_pass => 'admin123'};    # Access server password
    
    # Create mConsole/Access server instance
    $mConsole = AccessServer->createFromConfig(AccessServerConfig->createFromHash($as_cfg));

    # create datastores
    $ds_src = $mConsole->createDatastoreSimple(
        'solsrc_ds',        # datastore name
        'Source datastore',    # datastore description
        'localhost',        # datastore host
        $cdc_src,        # cdc instance
    );
    $ds_tgt = $mConsole->createDatastoreSimple(
        'soltgt_ds',        # datastore name
        'Target datastore',    # datastore description
        'localhost',        # datastore host
        $cdc_tgt,        # cdc instance
    );
    $mConsole->source($ds_src);    # assign source datastore
    $mConsole->target($ds_tgt);    # assign target datastore
    
    $mConsole->assignDatastoreUser($ds_src);
    $mConsole->assignDatastoreUser($ds_tgt);

    $mConsole->createSubscription($sub);    # Create subscription between source and target datastores
    $mConsole->addMapping($sub);            # Add default mapping to subscription
    $mConsole->startMirroring($sub);        # Start mirroring

    $db_src->execSql('sol_insertsrc.sql');    # Insert rows into source table
    sleep(15);                # Allow mirroring to take effect
    $db_tgt->execSql('sol_readtgt.sql');    # Read target table

 };

 # Error thrown in eval {...}
 if ($@) { Environment::logf("\n\nErrors found: $@\n"); }

    # CLEANUP

    $mConsole->stopMirroring($sub);         # Stop mirroring
    $mConsole->deleteMapping($sub);         # Delete mapping
    $mConsole->deleteSubscription($sub);    # Delete subscription

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
