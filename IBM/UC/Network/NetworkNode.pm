########################################################################
# 
# File   :  NetworkNode.pm
# History:  Apr-2010 (alg) module created as part of Test Automation
#			project
#
########################################################################
#
# NetworkNode provides a bunch of methods that trigger perl scripts
# on a remote machine.
# 
########################################################################

package NetworkNode;

use strict;
use warnings;

use IBM::UC::Network::Inet;
use IBM::UC::UCConfig::NetworkNodeConfig;
use IBM::UC::Environment;

my $installCdcUdbScriptName   = 'installCdcUdb.pl';
my $uninstallCdcUdbScriptName = 'uninstallCdcUdb.pl';
my $createTsUdbScriptName     = 'createTsUdb.pl';
my $deleteTsUdbScriptName     = 'deleteTsUdb.pl';
my $startTsUdbScriptName      = 'startTsUdb.pl';
my $stopTsUdbScriptName       = 'stopTsUdb.pl';
my $installDb2ScriptName      = 'installDb2.pl';
my $uninstallDb2ScriptName    = 'uninstallDb2.pl';
my $startDb2InstScriptName    = 'startDb2Inst.pl';
my $stopDb2InstScriptName     = 'stopDb2Inst.pl';
my $startDb2ScriptName        = 'startDb2.pl';
my $stopDb2ScriptName         = 'stopDb2.pl';
my $createDb2DbScriptName     = 'createDb2Database.pl';
my $deleteDb2DbScriptName     = 'deleteDb2Database.pl';
my $runDb2RunstatScriptName   = 'runDb2Runstat.pl';

#------------------------------------------------------------------------------
# NetworkNode->new()
#------------------------------------------------------------------------------
#
# Private.
#
# Constructor.
#
#------------------------------------------------------------------------------
sub new {
	my $class = shift;
	my $self = { CONFIG => new NetworkNodeConfig() };
	bless( $self, $class );
	return $self;
}

#------------------------------------------------------------------------------
# $node = NetworkNode->createFromConfig($networNodeCfg)
#------------------------------------------------------------------------------
#
# Public.
#
# Create a NetworkNode object.
#
# my $networNodeCfg = NetworkNodeConfig->createFromHash($nodeCfg);
# my $node = NetworkNode->createFromConfig($networNodeCfg);
#
#------------------------------------------------------------------------------
sub createFromConfig {
	print "NetworkNode::createFromConfig\n";

	my $class      = shift;
	my $remote_cfg = shift;
	my $self       = $class->new();

	# Make sure we get valid cdc configuration as first parameter
	if ( !defined($remote_cfg) ) {
		Environment::fatal(
"NetworkNode::createFromConfig requires CDC configuration as 1st input\nExiting...\n"
		);
	}
	elsif ( ref($remote_cfg) ne 'NetworkNodeConfig' ) {
		Environment::fatal(
"NetworkNode::createFromConfig: cdc configuration not of type \"cdcConfig\"\nExiting...\n"
		);
	}

	# store reference to database in object data

	bless $self, $class;

	# override defaults with parameters passed
	$self->getConfig()->initFromConfig( $remote_cfg->getParams() );

	# Check that config is fully initialised
	$self->getConfig()->checkRequired()
	  or Environment::fatal(
		"NetworkNode::createFromConfig: Error(s) occurred. Exiting...\n");

	return $self;
}

#-----------------------------------------------------------------------
# $cfg = $node->getConfig()
#-----------------------------------------------------------------------
#
# Public.
#
# Get configuration object (class cdcConfig)
#
#-----------------------------------------------------------------------
sub getConfig {
	my $self = shift;
	return $self->{'CONFIG'};
}

#------------------------------------------------------------------------------
# $ref = $node->getConfigParams()
#------------------------------------------------------------------------------
#
# Public.
#
# Get reference to configuration parameters hash.
#
#------------------------------------------------------------------------------
sub getConfigParams {
	my $self = shift;
	return $self->getConfig()->getParams();
}

#------------------------------------------------------------------------------
# $node-?sendPackage($package, $toDir)
#------------------------------------------------------------------------------
#
# Public.
#
# Send the given package of data to the given dir in the remote machine.
#
#------------------------------------------------------------------------------
sub sendPackage {
	print "CdcNetworkNode::sendPackage\n";

	my $self    = shift;
	my $package = shift;
	my $toDir   = shift;
	my $cfg     = $self->getConfigParams();

	Inet::ftp_connect( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );
	Inet::ftp_put( $package, $toDir );
	Inet::ftp_disconnect();
}

#------------------------------------------------------------------------------
# $node->installDb2($db2DbObjectRef, $db2InstallerDir);
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that installs db2 on the remote
# machine. The executed script is on the remote machine and only triggered from
# local.
#
#------------------------------------------------------------------------------
sub installDb2 {
	print "CdcNetworkNode::installDb2\n";

	my $self            = shift;
	my $db2Db           = shift;
	my $db2InstallerDir = shift;
	my $cfg             = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );

	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$installDb2ScriptName "
	  . $db2InstallerDir;
	$command .= " " . $db2Db->dbDir();
	$command .= " " . $cfg->{'remoteCdcSolidRootDir'};
	
	Inet::rsh_execute($command);

	Inet::rsh_close();
}

#------------------------------------------------------------------------------
# $node->uninstallDb2($db2DbObjectRef, $db2InstallerDir)
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that uninstalls db2 on the remote
# machine. The executed script is on the remote machine and only triggered from
# local.
#
#------------------------------------------------------------------------------
sub uninstallDb2 {
	print "CdcNetworkNode::uninstallDb2\n";

	my $self            = shift;
	my $db2Db           = shift;
	my $db2InstallerDir = shift;
	my $cfg             = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );

	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$uninstallDb2ScriptName "
	  . $db2InstallerDir;
	$command .= " " . $db2Db->dbDir();
	$command .= " " . $cfg->{'remoteCdcSolidRootDir'};
	
	Inet::rsh_execute($command);

	Inet::rsh_close();
}

#------------------------------------------------------------------------------
# $node->startDb2($db2DbObjectRef)
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that start db2 on the remote
# machine. The executed script is on the remote machine and only triggered from
# local.
#
#------------------------------------------------------------------------------
sub startDb2 {
	print "CdcNetworkNode::startDb2\n";

	my $self  = shift;
	my $db2Db = shift;
	my $cfg   = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );

	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$startDb2ScriptName "
	  . $db2Db->dbDir();
	$command .= " " . $db2Db->dbUser();
	$command .= " " . $db2Db->dbPass();
	$command .= " " . $cfg->{'remoteCdcSolidRootDir'};
	
	Inet::rsh_execute($command);

	Inet::rsh_close();
}

#------------------------------------------------------------------------------
# $node->stopDb2($db2DbObjectRef)
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that stop db2 on the remote
# machine. The executed script is on the remote machine and only triggered from
# local.
#
#------------------------------------------------------------------------------
sub stopDb2 {
	print "CdcNetworkNode::stopDb2\n";

	my $self  = shift;
	my $db2Db = shift;
	my $cfg   = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );

	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$stopDb2ScriptName "
	  . $db2Db->dbDir();
	$command .= " " . $db2Db->dbUser();
	$command .= " " . $db2Db->dbPass();
	$command .= " " . $cfg->{'remoteCdcSolidRootDir'};
	
	Inet::rsh_execute($command);

	Inet::rsh_close();
}

#------------------------------------------------------------------------------
# $node->createDb2Database($db2DbObjectRef)
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that creates a db2 db on the remote
# machine. The executed script is on the remote machine and only triggered from
# local.
#
#------------------------------------------------------------------------------
sub createDb2Database {
	print "CdcNetworkNode::createDb2Instance\n";

	my $self  = shift;
	my $db2Db = shift;
	my $cfg   = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );

	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$createDb2DbScriptName "
	  . $db2Db->dbDir();
	$command .= " " . $db2Db->dbName();
	$command .= " " . $db2Db->dbUser();
	$command .= " " . $db2Db->dbPass();
	$command .= " " . $db2Db->dbPort();
	$command .= " " . $db2Db->dbSchema();
	$command .= " " . $cfg->{'remoteCdcSolidRootDir'};

	Inet::rsh_execute($command);
}

#------------------------------------------------------------------------------
# $node->deleteDb2Database($db2DbObjectRef)
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that deletes a db2 db on the remote
# machine. The executed script is on the remote machine and only triggered from
# local.
#
#------------------------------------------------------------------------------
sub deleteDb2Database {
	print "CdcNetworkNode::deleteDb2Instance\n";

	my $self  = shift;
	my $db2Db = shift;
	my $cfg   = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );

	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$deleteDb2DbScriptName "
	  . $db2Db->dbDir();
	$command .= " " . $db2Db->dbName();
	$command .= " " . $db2Db->dbUser();
	$command .= " " . $db2Db->dbPass();
	$command .= " " . $db2Db->dbPort();
	$command .= " " . $cfg->{'remoteCdcSolidRootDir'};

	Inet::rsh_execute($command);
}

#------------------------------------------------------------------------------
# $node->installCdcUdb($cdcUdbObjRef, $cdcinstallerPath)
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that install CDC for UDB on the remote
# machine. The executed script is on the remote machine and only triggered from
# local.
#
#------------------------------------------------------------------------------
sub installCdcUdb {
	print "CdcNetworkNode::installCdcDb2\n";

	my $self   = shift;
	my $cdcUdb = shift;
	my $cdcDir = shift;
	my $cfg    = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );

	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$installCdcUdbScriptName "
	  . $cdcDir;
	$command .= " " . $cdcUdb->CDCRootDir();
	$command .= " " . $cfg->{'remoteCdcSolidRootDir'};
	
	Inet::rsh_execute($command);

	Inet::rsh_close();
}

#------------------------------------------------------------------------------
# $node->uninstallCdcUdb($cdcUdbObjRef)
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that uninstall CDC for UDB on the 
# remote machine. The executed script is on the remote machine and only 
# triggered from local.
#
#------------------------------------------------------------------------------
sub uninstallCdcUdb {
	Environment::logf "CdcNetworkNode::uninstallCdcDb2\n";

	my $self   = shift;
	my $cdcUdb = shift;
	my $cfg    = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );

	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$uninstallCdcUdbScriptName "
	  . $cdcUdb->CDCRootDir();
	  $command .= " " . $cfg->{'remoteCdcSolidRootDir'};
	  
	Inet::rsh_execute($command);

	Inet::rsh_close();
}

#------------------------------------------------------------------------------
# $node->createTsUdb($cdcUdbObjRef)
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that create an instance of CDC for UDB  
# on the remote machine. The executed script is on the remote machine and only 
# triggered from local.
#
#------------------------------------------------------------------------------
sub createTsUdb {
	Environment::logf "CdcNetworkNode::createTsDb2\n";

	my $self   = shift;
	my $cdcUdb = shift;
	my $cfg    = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );

	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$createTsUdbScriptName "
	  . $cdcUdb->CDCRootDir();
	$command .= " " . $cdcUdb->instanceName();
	$command .= " " . $cdcUdb->instancePort();
	$command .= " " . $cdcUdb->database()->dbDir();
	$command .= " " . $cdcUdb->database()->dbName();
	$command .= " " . $cdcUdb->database()->dbUser();
	$command .= " " . $cdcUdb->database()->dbPass();
	$command .= " " . $cdcUdb->database()->dbPort();
	$command .= " " . $cdcUdb->database()->dbSchema();
	$command .= " " . $cdcUdb->getConfigParams()->{'ts_db_refresh_loader'};
	$command .= " " . $cdcUdb->getEnv()->CDCBits();
	$command .= " " . $cfg->{'remoteCdcSolidRootDir'};

	Inet::rsh_execute($command);

	Inet::rsh_close();
}

#------------------------------------------------------------------------------
# $node->deleteTsUdb($cdcUdbObjRef)
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that delete an instance of CDC for UDB  
# on the remote machine. The executed script is on the remote machine and only 
# triggered from local.
#
#------------------------------------------------------------------------------
sub deleteTsUdb {
	Environment::logf "CdcNetworkNode::deleteTsDb2\n";

	my $self   = shift;
	my $cdcUdb = shift;
	my $cfg    = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );

	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$deleteTsUdbScriptName "
	  . $cdcUdb->CDCRootDir();
	$command .= " " . $cdcUdb->instanceName();
	$command .= " " . $cdcUdb->instancePort();
	$command .= " " . $cdcUdb->database()->dbDir();
	$command .= " " . $cdcUdb->database()->dbName();
	$command .= " " . $cdcUdb->database()->dbUser();
	$command .= " " . $cdcUdb->database()->dbPass();
	$command .= " " . $cdcUdb->database()->dbPort();
	$command .= " " . $cdcUdb->database()->dbSchema();
	$command .= " " . $cdcUdb->getConfigParams()->{'ts_db_refresh_loader'};
	$command .= " " . $cdcUdb->getEnv()->CDCBits();
	$command .= " " . $cfg->{'remoteCdcSolidRootDir'};

	Inet::rsh_execute($command);

	Inet::rsh_close();
}

#------------------------------------------------------------------------------
# $node->startTsUdb($cdcUdbObjRef)
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that start an instance of CDC for UDB  
# on the remote machine. The executed script is on the remote machine and only 
# triggered from local.
#
#------------------------------------------------------------------------------
sub startTsUdb {
	Environment::logf "CdcNetworkNode::startTsDb2\n";

	my $self   = shift;
	my $cdcUdb = shift;
	my $cfg    = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );

	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$startTsUdbScriptName "
	  . $cdcUdb->CDCRootDir();
	$command .= " " . $cdcUdb->instanceName();
	$command .= " " . $cdcUdb->instancePort();
	$command .= " " . $cdcUdb->database()->dbDir();
	$command .= " " . $cdcUdb->database()->dbName();
	$command .= " " . $cdcUdb->database()->dbUser();
	$command .= " " . $cdcUdb->database()->dbPass();
	$command .= " " . $cdcUdb->database()->dbPort();
	$command .= " " . $cdcUdb->database()->dbSchema();
	$command .= " " . $cdcUdb->getConfigParams()->{'ts_db_refresh_loader'};
	$command .= " " . $cdcUdb->getEnv()->CDCBits();
	$command .= " " . $cfg->{'remoteCdcSolidRootDir'};

	Inet::rsh_execute($command);

	Inet::rsh_close();
}

#------------------------------------------------------------------------------
# $node->stopTsUdb($cdcUdbObjRef)
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that stop an instance of CDC for UDB  
# on the remote machine. The executed script is on the remote machine and only 
# triggered from local.
#
#------------------------------------------------------------------------------
sub stopTsUdb {
	Environment::logf "CdcNetworkNode::stopTsDb2\n";

	my $self   = shift;
	my $cdcUdb = shift;
	my $cfg    = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );

	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$stopTsUdbScriptName "
	  . $cdcUdb->CDCRootDir();
	$command .= " " . $cdcUdb->instanceName();
	$command .= " " . $cdcUdb->instancePort();
	$command .= " " . $cdcUdb->database()->dbDir();
	$command .= " " . $cdcUdb->database()->dbName();
	$command .= " " . $cdcUdb->database()->dbUser();
	$command .= " " . $cdcUdb->database()->dbPass();
	$command .= " " . $cdcUdb->database()->dbPort();
	$command .= " " . $cdcUdb->database()->dbSchema();
	$command .= " " . $cdcUdb->database()->dbDirClean();
	$command .= " " . $cdcUdb->getEnv()->CDCBits();
	$command .= " " . $cfg->{'remoteCdcSolidRootDir'};

	Inet::rsh_execute($command);

	Inet::rsh_close();
}

#------------------------------------------------------------------------------
# $node->runDb2Runstat($cdcUdbObjRef, $tableName)
#------------------------------------------------------------------------------
#
# Public.
#
# Lauch the execution of a remote script that execute 'db2 runstat' on the 
# given table on the remote machine. The executed script is on the remote  
# machine and only triggered from local.
#
#------------------------------------------------------------------------------
sub runDb2Runstat {
	Environment::logf "CdcNetworkNode::runDb2Command\n";
	
	my $self   = shift;
	my $cdcUdb = shift;
	my $table  = shift;
	my $cfg    = $self->getConfigParams();
	my $command;
	my $ps = Environment->getEnvironment()->getPathSeparator();

	Inet::rsh_open( $cfg->{'ip'}, $cfg->{'uid'}, $cfg->{'pwd'} );
	$command = "perl -I "
	  . $cfg->{'frameworkPath'} . " -w "
	  . $cfg->{'rScriptsPath'}
	  . $ps
	  . "$runDb2RunstatScriptName "
	  . $table;
	$command .= " " . $cdcUdb->database()->dbName();
	$command .= " " . $cdcUdb->database()->dbUser();
	$command .= " " . $cdcUdb->database()->dbPass();

	Inet::rsh_execute($command);
	Inet::rsh_close();
}

1;
