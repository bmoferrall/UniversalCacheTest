########################################################################
# 
# File   :  AccessServer.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# AccessServer provides similar functionality to Management console
# 
########################################################################
package AccessServer;

use strict;

use IBM::UC::Environment;
use IBM::UC::UCConfig::AccessServerConfig;
use IBM::UC::AccessServer::Datastore;
use File::Path;
use File::Copy;
use Cwd;
use Data::Dumper;



#-----------------------------------------------------------------------
# $ob = AccessServer->createSimple($host,$port,$user,$pass)
#-----------------------------------------------------------------------
# 
# Create AccessServer object using fixed order parameters
# All parameters are optional, but those present must be in the correct order
# of parameter name/value pairs. Parameters left out will be given default
# values (see POD for details).
# AccessServer->createSimple('localhost',10101,'Admin','admin123');
# 
#-----------------------------------------------------------------------
sub createSimple
{
	my $class = shift;
	my $as_host = shift;
	my $as_port = shift;
	my $as_user = shift;
	my $as_pass = shift;

	my $self = {
		CONFIG => AccessServerConfig->new(), # Access server configuration object
		SUBNAME => 'Subscription', # Default subscription name
		SRC  => undef, # source instance
		TGT  => undef, # target instance
	};
	bless $self, $class;

	$self->init(); # set defaults

	# override defaults with parameters passed
	if (defined($as_pass)) { $self->accessHost($as_pass); }
	if (defined($as_user)) { $self->accessHost($as_user); }
	if (defined($as_port)) { $self->accessHost($as_port); }
	if (defined($as_host)) { $self->accessHost($as_host); }

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or 
		Environment::fatal("AccessServer::createSimple: Error(s) occurred. Exiting...\n");

	return $self;
}


#-----------------------------------------------------------------------
# $ob = AccessServer->createFromConfig($config)
#-----------------------------------------------------------------------
# 
# Create AccessServer object from existing AccessServerConfig object which is essentially 
# a hash of parameter name/value pairs for Access Server.
# e.g.
# $config_values = { ac_host => 'localhost', ac_port => '10101',
#					  ac_user => 'Admin', ac_pass => 'admin123'};
# AccessServer->createFromConfig(AccessServerConfig->createFromHash($config_values));
# 
#-----------------------------------------------------------------------
sub createFromConfig
{
	my $class = shift;
	my $as_cfg = shift;

	my $self = {
		CONFIG => AccessServerConfig->new(), # Access server configuration object
		SUBNAME => 'Subscription', # Default subscription name
		SRC  => undef, # source datastore
		TGT  => undef, # target datastore
	};
	bless $self, $class;

	# Make sure we get valid Access server configuration object
	if (!defined($as_cfg)) {
		Environment::fatal("AccessServer::createFromConfig requires Access Server configuration as 1st parameter\nExiting...\n");
	} elsif (ref($as_cfg) ne 'AccessServerConfig') {
		Environment::fatal("AccessServer::createFromConfig: configuration object not of type \"AccessServerConfig\"\nExiting...\n");
	}
	$self->init(); # set defaults

	# override defaults with parameters passed
	$self->getConfig()->initFromConfig($as_cfg->getParams());	

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or 
		Environment::fatal("AccessServer::createFromConfig: Error(s) occurred. Exiting...\n");

	return $self;
}



#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise AccessServer object parameters with default values
#
#-----------------------------------------------------------------------
sub init
{
	my $self = shift;

	# Make sure we only initialise once,
	#    in case a user explicitly calls what is intended to be a private method
	if (!$self->initialised()) { 
		# Initialise some config parameters to default values
		$self->getConfig()->initFromConfig({ac_host => 'localhost',
											ac_port => '10101',
											ac_user => 'Admin',
											ac_pass => 'admin123'});
		$self->initialised(1);
	}
}


#-----------------------------------------------------------------------
# $ob->setAccessParams()
#-----------------------------------------------------------------------
#
# Initialise instance manager with Access Server parameters
#
#-----------------------------------------------------------------------
sub setAccessParams
{
	my $self = shift;
	my $cmd;
	my $savecwd = Cwd::getcwd();
	my $ps = $self->getEnv()->getPathSeparator();

	chdir($self->getEnv()->CDCSolidRootDir());
	$cmd = ".${ps}bin${ps}dmsetaccessserverparams -H " . $self->accessHost() .
			" -P " . $self->accessPort() . " -u " . $self->accessUser() .
			" -p " . $self->accessPass();
	Environment::logf("\n>>COMMAND: $cmd\n");
	system($cmd) and Environment::logf("***Error occurred in AccessServer::setAccessParams***\n");
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ds = $ob->createDatastoreSimple($name,$desc,$host,$cdc)
#-----------------------------------------------------------------------
#
# Instantiates an object of class Datastore from simple parameters and
# invokes the createDatastore() method. Returns datastore object
# Parameters are datastore name, datastore description, datastore host,
# and the CDC instance associated with datastore, e.g.
# $ob->createDatastoreSimple('src_ds','Source','localhost',$cdc)
#
#-----------------------------------------------------------------------
sub createDatastoreSimple
{
	my $self = shift;
	my $ds_name = shift;
	my $ds_desc = shift;
	my $ds_host = shift;
	my $cdc = shift;
	my $ds;
	
	$self->setAccessParams();
	$ds = Datastore->createSimple($ds_name,$ds_desc,$ds_host,$cdc);
	$self->createDatastore($ds);
	return $ds;	
}


#-----------------------------------------------------------------------
# $ds = $ob->createDatastoreFromConfig($cfg,$cdc)
#-----------------------------------------------------------------------
#
# Instantiates an object of class Datastore and
# invokes the createDatastore() method. Returns datastore object
# Parameters are a config object of class DatastoreConfig and the CDC instance 
# associated with datastore, e.g.
# $ds_vals = { ds_name => 'src_ds', ds_desc => 'source', ds_host => 'localhost' }
# $ob->createDatastoreFromConfig(DatastoreConfig->createFromHash($ds_vals),$cdc)
#
#-----------------------------------------------------------------------
sub createDatastoreFromConfig
{
	my $self = shift;
	my $ds_cfg = shift;
	my $cdc = shift;
	my $ds;
	
	$self->setAccessParams();
	$ds = Datastore->createFromConfig($ds_cfg,$cdc);
	$self->createDatastore($ds);
	return $ds;	
}


#-----------------------------------------------------------------------
# $ob->createDatastore($ds)
#-----------------------------------------------------------------------
#
# Creates a datastore using the access server utility dmcreatedatastore.
# Takes an object of class Datastore as input
#
#-----------------------------------------------------------------------
sub createDatastore
{
	my $self = shift;
	my $ds = shift; # datastore object 
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();

	if (!defined($ds) or (ref($ds) ne 'Datastore')) {
		Environment::fatal("AccessServer::createDatastore: expecting parameter of type Datastore\nExiting...\n");
	}
	
	chdir($self->getEnv()->accessServerRootDir());
	sleep(12);
	$command = ".${ps}bin${ps}dmcreatedatastore " . $ds->datastoreName() . 
				" \"" . $ds->datastoreDesc() . "\" " .
				$ds->datastoreHost() . " " . $ds->getCdc()->instancePort();
	Environment::logf(">>Creating datastore...\n");
	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in AccessServer::createDatastore***\n");
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->deleteDatastore($ds)
#-----------------------------------------------------------------------
#
# Deletes a datastore using the access server utility dmdeletedatastore.
# Takes an object of class Datastore as input
#
#-----------------------------------------------------------------------
sub deleteDatastore
{
	my $self = shift;
	my $ds = shift; # datastore object
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();
	
	if (!defined($ds) or (ref($ds) ne 'Datastore')) {
		Environment::fatal("AccessServer::deleteDatastore: expecting parameter of type Datastore\nExiting...\n");
	}

	chdir($self->getEnv()->accessServerRootDir());
	$command = ".${ps}bin${ps}dmdeletedatastore " . $ds->datastoreName();
	Environment::logf(">>Deleting datastore...\n");
	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in AccessServer::deleteDatastore***\n");
	sleep(5);
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->assignDatastoreUser($ds)
#-----------------------------------------------------------------------
#
# Assigns an access server user to a datastore using the Access Server
# utility dmaddconnection
# Takes an object of class Datastore as input
#
#-----------------------------------------------------------------------
sub assignDatastoreUser
{
	my $self = shift;
	my $ds = shift; # datastore object
	my $savecwd = Cwd::getcwd();
	my $command;
	my $cp;
	my $ps = $self->getEnv()->getPathSeparator();
	my $es = $self->getEnv()->getEnvSeparator();

	if (!defined($ds) or (ref($ds) ne 'Datastore')) {
		Environment::fatal("AccessServer::assignDatastoreUser: expecting parameter of type Datastore\nExiting...\n");
	}
	
	chdir($self->getEnv()->accessServerRootDir());

	# Add patch jar to classpath
	$cp = $self->getEnv()->CDCSolidRootDir() . "lib${ps}api2_uc65.jar" . $es . $ds->getCdc()->classPath();

	$command =	"java -Djava.library.path=\"" . $self->getEnv()->CDCSolidRootDir() . "lib\" " .
#	$command =	"java " .
				"-cp \"$cp\" com.datamirror.commandline.AddConnection2 " .
				$self->accessUser() . " " .	$ds->datastoreName() . " " . 
				$ds->getCdc()->database()->dbName() .
				" " . $ds->getCdc()->database()->dbUser() .
				" " . $ds->getCdc()->database()->dbPass() . " false true false true";

	Environment::logf("\n>>Assigning user to datastore \"${\$ds->datastoreName()}\"...\n");
	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in AccessServer::assignDatastoreUser***\n");
	chdir($savecwd);
}


# Prior version of above method (will revert to this when bug has been fixed)
sub assignDatastoreUserOld
{
	my $self = shift;
	my $ds = shift; # datastore object
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();

	if (!defined($ds) or (ref($ds) ne 'Datastore')) {
		Environment::fatal("AccessServer::assignDatastoreUser: expecting parameter of type Datastore\nExiting...\n");
	}
	
	chdir($self->getEnv()->accessServerRootDir());
	$command = ".${ps}bin${ps}dmaddconnection " . $self->accessUser() . " " .
				$ds->datastoreName() . " " . $ds->getCdc()->database()->dbSchema() .
				" " . $ds->getCdc()->database()->dbUser() .
				" " . $ds->getCdc()->database()->dbPass() . " true true false false";
	Environment::logf("\n>>Assigning user to datastore \"${\$ds->datastoreName()}\"...\n");
	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in AccessServer::assignDatastoreUser***\n");
	chdir($savecwd);
}



#-----------------------------------------------------------------------
# $ob->createSubscription([$name])
#-----------------------------------------------------------------------
#
# Creates a subscription using the subscription manager. Source and target datastores
# must have been set by user beforehand using source() and target().
# Takes an optional subscription name as input
#
#-----------------------------------------------------------------------
sub createSubscription
{
	my $self = shift;
	my $subname = shift; # subscription name (optional parameter)
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();

	if (!defined($subname)) { $subname = $self->subName(); }
	if (!defined($self->source()) or !defined($self->target())) {
		Environment::fatal("AccessServer::createSubscription: source and/or target datastores not set\nExiting...\n");
	}

	# Change to CDC for Solid root directory (where access parameters are stored)
	chdir($self->getEnv()->CDCSolidRootDir());
	Environment::logf("\n>>Creating Subscription \"$subname\"...\n");
	$self->dmSubscriptionManager({cmd=>'create',subname=>$subname,
									srcds=>$self->source()->datastoreName(),
									tgtds=>$self->target()->datastoreName(),
									dbuser=>$self->target()->getCdc()->database()->dbUser(),
									dbpass=>$self->target()->getCdc()->database()->dbPass()});

	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->createSubscription([$name])
#-----------------------------------------------------------------------
#
# Deletes a subscription using the subscription manager. Source and target datastores
# must have been set by user beforehand using source() and target().
# Takes an optional subscription name as input
#
#-----------------------------------------------------------------------
sub deleteSubscription
{
	my $self = shift;
	my $subname = shift; # subscription name (optional parameter)
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();

	if (!defined($subname)) { $subname = $self->subName(); }
	if (!defined($self->source()) or !defined($self->target())) {
		Environment::fatal("AccessServer::deleteSubscription: source and/or target datastores not set\nExiting...\n");
	}

	# Change to CDC for Solid root directory (where access parameters are stored)
	chdir($self->getEnv()->CDCSolidRootDir());
	Environment::logf("\n>>Deleting Subscription \"$subname\"...\n");
	$self->dmSubscriptionManager({cmd=>'delete',subname=>$subname,
									srcds=>$self->source()->datastoreName(),
									tgtds=>$self->target()->datastoreName()});

	chdir($savecwd);
}



#-----------------------------------------------------------------------
# $ob->listSubscriptions()
#-----------------------------------------------------------------------
#
# List subscriptions
#
#-----------------------------------------------------------------------
sub listSubscriptions
{
	my $self = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();

	# Change to CDC for Solid root directory (where access parameters are stored)
	chdir($self->getEnv()->CDCSolidRootDir());
	Environment::logf("\n>>Listing Subscriptions...\n");
	$self->dmSubscriptionManager({cmd=>'list'});

	chdir($savecwd);
}



#-----------------------------------------------------------------------
# $ob->flagForRefresh($ds,$tbl,[$subname])
#-----------------------------------------------------------------------
#
# Flags a subscription table for refresh, where:
# $ds=datastore
# $tbl=table name
# $subname=subscription name (optional) 
#
#-----------------------------------------------------------------------
sub flagForRefresh
{
	my $self = shift;
	my $ds = shift;
	my $tbl = shift;
	my $subname = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();

	if (!defined($ds) or ref($ds) ne 'Datastore') {
		Environment::fatal("AccessServer::flagForRefresh: Expecting Datastore object as parameter\nExiting...\n");
	}
	if (!defined($tbl)) {
		Environment::fatal("AccessServer::flagForRefresh: Expecting table name as parameter\nExiting...\n");
	}
	if (!defined($subname)) { $subname = $self->subName(); }

	chdir($self->source()->getCdc()->CDCRootDir());
	Environment::logf("\nFlagging \"$tbl\" in subscription \"$subname\" for refresh...\n");
	$command = ".${ps}bin${ps}dmflagforrefresh -I " . $ds->getCdc()->instanceName() . 
				' -s ' . $subname . ' -t ' . $tbl;
	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in AccessServer::flagForRefresh***\n");
	sleep(5);
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->refreshSubscription($ds,[$subname])
#-----------------------------------------------------------------------
#
# Initiate a refresh of a table in a subscription, where:
# $ds=datastore
# $subname=subscription name (optional) 
#
#-----------------------------------------------------------------------
sub refreshSubscription
{
	my $self = shift;
	my $ds = shift;
	my $subname = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();

	if (!defined($ds) or ref($ds) ne 'Datastore') {
		Environment::fatal("AccessServer::refreshSubscription: Expecting Datastore object as parameter\nExiting...\n");
	}
	if (!defined($subname)) { $subname = $self->subName(); }

	chdir($self->source()->getCdc()->CDCRootDir());
	Environment::logf("\nRefreshing subscription \"$subname\"...\n");
	$command = ".${ps}bin${ps}dmrefresh -I " . $ds->getCdc()->instanceName() . 
				' -s ' . $subname;
	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in AccessServer::refreshSubscription***\n");
	sleep(5);
	chdir($savecwd);
}





#-----------------------------------------------------------------------
# $ob->addMapping([$name,$srctbl,$tgttbl])
#-----------------------------------------------------------------------
#
# Creates a mapping between source and target database tables using
# the subscription manager.
# Source and target datastores must have been set by user beforehand 
# using source() and target().
# Optional parameters are subscription name, source table name and target
# table name
#
#-----------------------------------------------------------------------
sub addMapping
{
	my $self = shift;
	my $subname = shift; # subscription name (optional parameter)
	my $srctbl = shift; # source table
	my $tgttbl = shift; # target table
	my $savecwd = Cwd::getcwd();
	my $command;

	if (!defined($subname)) { $subname = $self->subName(); }
	if (!defined($srctbl)) { 
		$srctbl =   $self->source()->getCdc()->database()->dbSchema() . '.' .
					$self->source()->getCdc()->database()->dbTableName();
	}
	if (!defined($tgttbl)) { 
		$tgttbl =   $self->target()->getCdc()->database()->dbSchema() . '.' .
					$self->target()->getCdc()->database()->dbTableName(); 
	}
	if (!defined($self->source()) or !defined($self->target())) {
		Environment::fatal("AccessServer::addMapping: source and/or target datastores not set\nExiting...\n");
	}

	# Change to CDC for Solid root directory (where access parameters are stored)
	chdir($self->getEnv()->CDCSolidRootDir());
	Environment::logf("\n>>Adding mapping for subscription \"$subname\"...\n");
	$self->dmSubscriptionManager({cmd=>'addmapping',subname=>$subname,
									srcds=>$self->source()->datastoreName(),
									tgtds=>$self->target()->datastoreName(),
									srctbl=>$srctbl,tgttbl=>$tgttbl});

	chdir($savecwd);
}

#-----------------------------------------------------------------------
# $ob->addMappingsFromFile([$mapfile,$subname])
#-----------------------------------------------------------------------
#
# Batch mode for addMapping (loads mappings to be carried out from a file)
# Source and target datastores must have been set by user beforehand 
# using source() and target().
# Optional parameters is subscription name
#
#-----------------------------------------------------------------------
sub addMappingsFromFile
{
	my $self = shift;
	my $mapfile = shift; # file from which to load mappings
	my $subname = shift; # subscription name
	my $savecwd = Cwd::getcwd();
	my $command;

	if (!defined($mapfile)) {
		Environment::fatal("AccessServer::addMappingsFromFile: Expecting File name as first parameter\nExiting...\n");
	}
	if (!defined($subname)) { $subname = $self->subName(); }

	if (!defined($self->source()) or !defined($self->target())) {
		Environment::fatal("AccessServer::addMapping: source and/or target datastores not set\nExiting...\n");
	}

	# Change to CDC for Solid root directory (where access parameters are stored)
	chdir($self->getEnv()->CDCSolidRootDir());
	Environment::logf("\n>>Adding mappings from file \"$mapfile\" for subscription \"$subname\"...\n");
	$self->dmSubscriptionManager({cmd=>'addmapping',subname=>$subname,
									srcds=>$self->source()->datastoreName(),
									tgtds=>$self->target()->datastoreName(),
									mapfile=>$mapfile});

	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->deleteMapping([$name])
#-----------------------------------------------------------------------
#
# Deletes mapping added using addMapping().
#
#-----------------------------------------------------------------------
sub deleteMapping
{
	my $self = shift;
	my $subname = shift;

	if (!defined($subname)) { $subname = $self->subName(); }
}


#-------------------------------------------------------------------------------------
# $ob->dmSubscriptionManager($refParam)
#-------------------------------------------------------------------------------------
#
# Invoke subscription manager
# $refParam is a reference to a hash of parameter name/value pairs. 
# Parameter names are:
# cmd=(addmapping|create|delete), subname (subscription name), 
# srcds (source datastore name), tgtds (target datastore name), mapfile (mapping file),
# srctbl (source table), tgttbl (target table), dbuser (databse user), 
# dbpass (database password)
# e.g.
# $ob->dmSubscriptionManager({cmd=>'addmapping',srcds=>'src_ds',tgtds=>'tgt_ds',
#							  srctbl=>'DBA.src',tgttbl=>'DBA.tgt'});
#
#--------------------------------------------------------------------------------------
sub dmSubscriptionManager
{
	my $self = shift;
	my $refParam = shift; # Hash reference of parameter name/values
	my $command;

	$command = "java -cp \"" . $self->classPath() . "\" " .
				"com.datamirror.ts.commandlinetools.script.subscriptionmanager.SubscriptionManager ";

	if ($refParam->{'cmd'}) { $command .= $refParam->{'cmd'} . ' '; }
	if ($refParam->{'subname'}) { $command .= '-name ' . $refParam->{'subname'} . ' '; }
	if ($refParam->{'srcds'}) { $command .= '-src ' . $refParam->{'srcds'} . ' '; }
	if ($refParam->{'tgtds'}) { $command .= '-tgt ' . $refParam->{'tgtds'} . ' '; }
	if ($refParam->{'mapfile'}) { $command .= '-mapfile ' . $refParam->{'mapfile'} . ' '; }
	if ($refParam->{'srctbl'}) { $command .= '-srctable ' . $refParam->{'srctbl'} . ' '; }
	if ($refParam->{'tgttbl'}) { $command .= '-tgttable ' . $refParam->{'tgttbl'} . ' '; }
	if ($refParam->{'dbuser'}) { $command .= '-dbuser ' . $refParam->{'dbuser'} . ' '; }
	if ($refParam->{'dbpass'}) { $command .= '-dbpass ' . $refParam->{'dbpass'} . ' '; }

	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in AccessServer::dmSubscriptionManager***\n");
}



#-----------------------------------------------------------------------
# $ob->startMirroring([$subname])
#-----------------------------------------------------------------------
#
# Invoke dmstartmirror utility to start mirroring for the named 
# subscription
# Takes optional subscription name as parameter
#
#-----------------------------------------------------------------------
sub startMirroring
{
	my $self = shift;
	my $subname = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();

	if (!defined($subname)) { $subname = $self->subName(); }
	if (!defined($self->source()) or !defined($self->target())) {
		Environment::fatal("AccessServer::startMirroring: source and/or target datastores not set\nExiting...\n");
	}

	chdir($self->source()->getCdc()->CDCRootDir());
	Environment::logf("\nStarting mirroring for subscription \"$subname\"...\n");
	$command = ".${ps}bin${ps}dmstartmirror -I " . $self->source()->getCdc()->instanceName() . 
				' -s ' . $subname;
	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in AccessServer::startMirroring***\n");
	sleep(5);
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->stopMirroring([$subname])
#-----------------------------------------------------------------------
#
# Invoke dmendreplication utility to stop mirroring for the named 
# subscription
# Takes optional subscription name as parameter
#
#-----------------------------------------------------------------------
sub stopMirroring
{
	my $self = shift;
	my $subname = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();

	if (!defined($subname)) { $subname = $self->subName(); }
	if (!defined($self->source()) or !defined($self->target())) {
		Environment::fatal("AccessServer::startMirroring: source and/or target datastores not set\nExiting...\n");
	}

	chdir($self->source()->getCdc()->CDCRootDir());
	Environment::logf("\nStopping mirroring for subscription \"$subname\"...\n");
	$command = ".${ps}bin${ps}dmendreplication -I " . $self->source()->getCdc()->instanceName() . 
				' -s ' . $subname;
	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in AccessServer::stopMirroring***\n");
	sleep(5);
	chdir($savecwd);
}



#-----------------------------------------------------------------------
# $ob->startAccessServer()
#-----------------------------------------------------------------------
#
# Invokes Access Server utility dmaccessserver to start Access Server
# as background server
#
#-----------------------------------------------------------------------
sub startAccessServer
{
	my $self = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();
	
	chdir($self->getEnv()->accessServerRootDir());
	if ($self->getEnv()->getOSName() eq 'windows') {
#		$command = "start /b .${ps}bin${ps}dmaccessserver";
		$command = "net start \"DataMirror Transformation Server Access Server\"";
	} else {
		$command = ".${ps}bin${ps}dmaccessserver &";
	}
	Environment::logf("\n>>Starting access server in the background...\n");
	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in AccessServer::startAccessServer***\n");
	sleep(3);
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->stopAccessServer()
#-----------------------------------------------------------------------
#
# Stop Access Server
#
#-----------------------------------------------------------------------
sub stopAccessServer
{
	my $self = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();
	
	chdir($self->getEnv()->accessServerRootDir());
	if ($self->getEnv()->getOSName() eq 'windows') {
		$command = "net stop \"DataMirror Transformation Server Access Server\"";
	} else {
		$command = "ps -ef | grep -v grep | grep dmaccess | awk '{print \$2}' | xargs kill -9";
	}
	Environment::logf("\n>>Stopping access server...\n");
	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in AccessServer::stopAccessServer***\n");
	sleep(3);
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->restartAccessServer()
#-----------------------------------------------------------------------
#
# Restart Access Server
#
#-----------------------------------------------------------------------
sub restartAccessServer
{
	my $self = shift;

	$self->stopAccessServer();
	$self->startAccessServer();
}



#-----------------------------------------------------------------------
# $ob->createAdminUser()
#-----------------------------------------------------------------------
#
# Create default Administrator account for Access Server
#
#-----------------------------------------------------------------------
sub createAdminUser
{
	my $self = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();
	
	chdir($self->getEnv()->accessServerRootDir());
	$command = ".${ps}bin${ps}dmcreateuser " . $self->accessUser() . ' ' . $self->accessUser() .
				' ' . $self->accessUser() . ' ' . $self->accessPass() . ' SYSADMIN TRUE FALSE TRUE';
	Environment::logf("\n>>Creating Admin user account for Access Server...\n");
	Environment::logf(">>COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in AccessServer::createAdminUser***\n");
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# AccessServer->install($install_to,$install_from)
# AccessServer::install($install_to,$install_from)
#-----------------------------------------------------------------------
#
# Install Access Server from package (local or on server) to local machine
# $install_to=installation directory
# $install_from=source installation package
# e.g.
# AccessServer->install('/home/user/DataMirror/Transformation Server Access Control',
#                   '/mnt/msoftware/AccessServer/dmaccess-6.3.bin')
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


	# If sub was called via AccessServer->install rather than AccessServer::install, perl will silently
	# pass class name as first parameter
	if (@_ && ($_[0] eq 'AccessServer')) { shift; }
	($install_to,$install_from) = @_;

	# Both input parameters are required
	if (!defined($install_from) || !defined($install_to)) {
		Environment::fatal("AccessServer::install: Expecting two parameters as input.\nExiting...\n");
	}
		
	# Make sure path ends with path separator
	$install_to .= $ps if (substr($install_to,-1,1) !~ m/[\/\\]/);

	($f,$p) = File::Basename::fileparse($install_from);
	Environment::fatal("Cannot find install file \"$p$f\"\nExiting...\n") if (!(-f $p.$f));
#	File::Path::rmtree($install_to,0,1);
	mkpath($install_to) if (!(-d $install_to));

	# Set Access Server path in environment module
	Environment::getEnvironment()->accessServerRootDir($install_to);

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
		$contents .= "USER_SHORTCUTS=C:\\\\Documents and Settings\\\\Administrator\\\\Start Menu\\\\Programs\\\\AccessServer";
	}
	open(OUT, ">$response_file") or Environment::fatal("AccessServer::install: Cannot write to \"$response_file\": $!\n");
	print OUT $contents . "\n";
	close(OUT);

	$command = ".$ps$f -f $response_file";
	Environment::logf("\n>>Installing Access Server in $install_to\n");
	system($command);# and Environment::logf("Error occurred in AccessServer::install\n");
	unlink($f);

	# Add installation bin directory to environment path variable
	$ENV{'PATH'} = $install_to . 'bin' . $es . $ENV{'PATH'};
}


#-----------------------------------------------------------------------
# AccessServer->install_mmc($install_to,$install_from)
# AccessServer::install_mmc($install_to,$install_from)
#-----------------------------------------------------------------------
#
# Install Management Console from package (local or on server) to local machine
# $install_to=installation directory
# $install_from=source installation package
# e.g.
# AccessServer->install_mmc('/home/user/DataMirror/Management Console',
#                   	'/mnt/msoftware/AccessServer/dmaccess-6.3.bin')
#
#-----------------------------------------------------------------------
sub install_mmc
{
	my $install_to;
	my $install_from;
	my $response_file = "response.ini";
	my $contents;
	my $command;
	my $ps = Environment::getEnvironment()->getPathSeparator();
	my $es = Environment::getEnvironment()->getEnvSeparator();
	my ($f,$p);


	# If sub was called via AccessServer->install_mmc rather than AccessServer::install_mmc, perl will silently
	# pass class name as first parameter
	if (@_ && ($_[0] eq 'AccessServer')) { shift; }
	($install_to,$install_from) = @_;

	# Both input parameters are required
	if (!defined($install_from) || !defined($install_to)) {
		Environment::fatal("AccessServer::install_mmc: Expecting two parameters as input.\nExiting...\n");
	}
		
	# Make sure path ends with path separator
	$install_to .= $ps if (substr($install_to,-1,1) !~ m/[\/\\]/);

	($f,$p) = File::Basename::fileparse($install_from);
	Environment::fatal("Cannot find install file \"$p$f\"\nExiting...\n") if (!(-f $p.$f));
#	File::Path::rmtree($install_to,0,1);
	mkpath($install_to) if (!(-d $install_to));

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
		$contents .= "USER_SHORTCUTS=C:\\\\Documents and Settings\\\\Administrator\\\\Start Menu\\\\Programs\\\\MMC";
	}
	open(OUT, ">$response_file") or Environment::fatal("AccessServer::install_mmc: Cannot write to \"$response_file\": $!\n");
	print OUT $contents . "\n";
	close(OUT);

	$command = ".$ps$f -f $response_file";
	Environment::logf("\n>>Installing Access Server in $install_to\n");
	system($command);# and Environment::logf("Error occurred in AccessServer::install_mmc\n");
	unlink($f);
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
# $cfg = $ob->getConfig()
#-----------------------------------------------------------------------
#
# Get configuration object (class AccessServerConfig)
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
# $ds = $ob->source()
# $ob->source($ds)
#-----------------------------------------------------------------------
#
# Get/set object representing source datastore (class Datastore)
#
#-----------------------------------------------------------------------
sub source
{
	my ($self,$ds) = @_;
	if (defined($ds) && (ref($ds) ne 'Datastore')) {
		Environment::fatal("AccessServer::source: expecting parameter of type Datastore\nExiting...\n");
	}
	$self->{'SRC'} = $ds if defined($ds);
	return $self->{'SRC'};
}


#-----------------------------------------------------------------------
# $ds = $ob->target()
# $ob->target($ds)
#-----------------------------------------------------------------------
#
# Get/set object representing target datastore (class Datastore)
#
#-----------------------------------------------------------------------
sub target
{
	my ($self,$ds) = @_;
	if (defined($ds) && (ref($ds) ne 'Datastore')) {
		Environment::fatal("AccessServer::target: expecting parameter of type Datastore\nExiting...\n");
	}
	$self->{'TGT'} = $ds if defined($ds);
	return $self->{'TGT'};
}


#-----------------------------------------------------------------------
# $name = $ob->subName()
# $ob->subName($name)
#-----------------------------------------------------------------------
#
# Get/set active subscription name
#
#-----------------------------------------------------------------------
sub subName
{
	my ($self,$name) = @_;
	$self->{'SUBNAME'} = $name if defined($name);
	return $self->{'SUBNAME'};
}


#-----------------------------------------------------------------------
# $host = $ob->accessHost()
# $ob->accessHost($host)
#-----------------------------------------------------------------------
#
# Get/set Access Server Host
#
#-----------------------------------------------------------------------
sub accessHost
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ac_host'} = $name if defined($name);
	return $self->getConfigParams()->{'ac_host'};
}


#-----------------------------------------------------------------------
# $port = $ob->accessPort()
# $ob->accessPort($port)
#-----------------------------------------------------------------------
#
# Get/set Access Server port number
#
#-----------------------------------------------------------------------
sub accessPort
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ac_port'} = $name if defined($name);
	return $self->getConfigParams()->{'ac_port'};
}


#-----------------------------------------------------------------------
# $user = $ob->accessUser()
# $ob->accessUser($user)
#-----------------------------------------------------------------------
#
# Get/set Access Server user name
#
#-----------------------------------------------------------------------
sub accessUser
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ac_user'} = $name if defined($name);
	return $self->getConfigParams()->{'ac_user'};
}


#-----------------------------------------------------------------------
# $pass = $ob->accessPass()
# $ob->accessPass($pass)
#-----------------------------------------------------------------------
#
# Get/set Access Server user password
#
#-----------------------------------------------------------------------
sub accessPass
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ac_pass'} = $name if defined($name);
	return $self->getConfigParams()->{'ac_pass'};
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
	$self->source()->getCdc()->classPath($name) if defined($name);
	return $self->source()->getCdc()->classPath();
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

AccessServer - Wrapper class encapsulating Management Console functions

=head1 SYNOPSIS

use IBM::UC::AccessServer::AccessServer;


#################
# Class methods #
#################

 $ob = AccessServer->createFromConfig($as_cfg);
   where:
     $as_cfg=Access server configuration object of class AccessServerConfig

 $ob = AccessServer->createSimple([$as_host, $as_port, $as_user, $as_pass]);
   where:
     $as_host=Access server host name (optional parameter)
     $as_port=Access server host port (optional parameter)
     $as_user=Access server user name (optional parameter)
     $as_pass=Access server password (optional parameter)

 # Install access server
 AccessServer->install($install_to, $install_from) or AccessServer::install
  where:
   $install_to=installation directory
   $install_from=source installation package
   
#######################
# object data methods #
#######################

### get versions ###

 $env = $ob->getEnv()
 $src = $ob->source()
 $tgt = $ob->target()
 $nm = $ob->subName()
 $ach = $ob->accessHost()
 $acp = $ob->accessPort()
 $acu = $ob->accessUser()
 $acp = $ob->accessPass()
 $cp = $ob->classPath()

### set versions ###

 $ob->subName('name')
 $ob->accessHost('localhost')
 $ob->accessPort(11011)
 $ob->accessUser('admin')
 $ob->accessPass('admin')
 $ob->classPath('xxx')


########################
# other object methods #
########################

 $ob = createDatastoreFromConfig($ds_cfg,$cdc); 		# Create datastore where:
								# 	$ds_cfg=config. object (DatastoreConfig) describing datastore
								# 	$cdc=CDC instance (e.g. CDCSolid, CDCDb2)
 $ob = createDatastoreSimple($ds_name,$ds_desc,$ds_host,$cdc); 	# Create datastore where:
								# 	$ds_name=datastore name
								# 	$ds_desc=datastore description
								# 	$ds_host=datastore host
								# 	$cdc=CDC instance (e.g. CDCSolid, CDCDb2)
 $ob->deleteDatastore($ds)		# Delete datastore $ds
 $ob->assignDatastoreUser($ds)		# Assign user to datastore $ds
 $ob->createSubscription([$name])	# Create named subscription ($name optional)
 $ob->deleteSubscription([$name])	# Delete named subscription ($name optional)
 $ob->flagForRefresh($ds,$tbl,[$name])	# Flag table in subscription for refresh, where:
 					# $ds=datastore
 					# $tbl=table to flag for refresh
 					# $name=subscription name (optional)
 $ob->refreshSubscription($ds,[$name])	# Initiate a refresh for subscription, where:
 					# $ds=datastore
 					# $name=subscription name (optional)
 $ob->addMapping([$name,$srct,$tgtt])	# Add mapping to subscription, where:
 					#  $name=subscription name (optional)
 					#  $srct=source table (optional)
 					#  $tgtt=target table (optional)
 $ob->deleteMapping([$name])		# Delete mapping for named subscription ($name optional)
 $ob->startMirroring([$name])		# Start mirroring for named subscription ($name optional)
 $ob->stopMirroring([$name])		# Stop mirroring for named subscription ($name optional)
 $ob->deleteMapping([$name])		# Delete mapping for named subscription
 $ob->startAccessServer()		# Start access server
 $ob->stopAccessServer()		# Stop access server
 $ob->restartAccessServer()		# Restart access server
 $ob->createAdminUser()		# Create Administrator user account

=head1 DESCRIPTION

The AccessServer module is intended to encapsulate the functionality of Management console:
create source and target datastores, create subscriptions and mappings, start/stop
replication, start/stop access server.

Initialisation of an AccessServer instance is via configuration parameters describing Access Server 
properties:

Valid configuration parameters and their default values follow (see AccessServerConfig.pm):

 ---------------------------------------------------------------------------------------------------------
 Parameter		Description						Default value
 ---------------------------------------------------------------------------------------------------------
 ac_host		Host name/ip address of access server			localhost
 ac_port		Communication port of access server			10101
 ac_user		User name with rights to use access server		Admin
 ac_pass		User password						admin123
 ---------------------------------------------------------------------------------------------------------

if initialisation is via a configuration ini file the AccessServer section must, by default, start with [ACCESSSERVER]
and end with [/ACCESSSERVER] or end of file, e.g.:

 [ACCESSSERVER]

 ; Host name/ip address for access server
 ac_host=localhost

 ; Communication port for access server
 ac_port=10101

 ; User/Password for access server
 ac_user=Admin
 ac_pass=admin123


=head1 EXAMPLES

An example of automating the creation of source and target databases, setting up replication between
tables in the databases and verifying that replication has taken place would be as follows:

 # Create subscription and mirror between Solid source and DB2 target
 sub replication_sol_to_db2
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
		db_dir => '/home/db2inst1/db2inst1/NODE0000/TEST',
		db_name => 'TEST',
		db_user => 'db2inst1',
		db_pass => 'db2inst1',
	};
	$db_tgt = Db2DB->createFromConfig(DatabaseConfig->createFromHash($dbvals_tgt));
	$db_tgt->start();
	# Create database also connects to database
	$db_tgt->createDatabase();
	# Create target schema
	$db_tgt->createSchema('db2inst1');

	# Set source and target table names for sql files
	# %TABLE% in sql file will be replaced with name here
	$db_src->dbTableName('src');
	$db_tgt->dbTableName('tgt');
	$db_src->execSql('sol_createsrc.sql');	# Create table 'src'
	$db_tgt->execSql('db2_createtgt.sql');	# Create table 'tgt'
	
	# create source CDC
	$cdc_src = CDCSolid->createSimple('solsrc_ts',11101,$db_src);

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
		'solsrc_ds',		# datastore name
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

	$db_src->execSql('sol_insertsrc.sql');	# Insert rows into source table
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

=cut
