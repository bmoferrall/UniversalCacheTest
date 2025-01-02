#!/usr/bin/perl

use strict;

use IBM::UC::Environment;
use IBM::UC::Database::SolidDB;
use IBM::UC::Database::InformixDB;
use IBM::UC::CDC::CDCSolid;
use IBM::UC::CDC::CDCInformix;
use IBM::UC::AccessServer::AccessServer;


print "*********************************************\n";
print "THIS ROUTINE PERFORMS A MIRROR FROM A INFORMIX\n";
print "SOURCE TO AN SOLID TARGET\n";
print "*********************************************\n\n\n";
sleep(3);
mirrorInformixToSolid();


sub mirrorInformixToSolid
{
	my ($envCfg, $dbSrcCfg, $dbTgtCfg);
	my ($dbSrc, $dbTgt, $tblNameSrc, $tblNameTgt);
	my ($cdcSrcCfg, $cdcTgtCfg, $cdcSrc, $cdcTgt);
	my ($asCfg, $mConsole);
	my ($dsSrcCfg, $dsTgtCfg, $dsSrc, $dsTgt);
	my $os = $Config::Config{'osname'} =~ /^MSWin/i ? 'windows' : 'other';
	my $sub = 'subname';
	my $ps; # Path separator
	my $es; # Environment separator

eval { # trap errors so we can clean up before exiting

	# Configure environment
	$envCfg = EnvironmentConfig->new('environment.ini');
	if ($os eq 'windows') {
		$envCfg->initFromConfigFile("\\[ENVIRONMENT_WIN\\]","\\[/ENVIRONMENT_WIN\\]");
	} else {
		$envCfg->initFromConfigFile("\\[ENVIRONMENT_LIN\\]","\\[/ENVIRONMENT_LIN\\]");
	}
	Environment->createFromConfig($envCfg);
	$es = Environment->getEnvironment()->getEnvSeparator();
	$ps = Environment->getEnvironment()->getPathSeparator();
    $ENV{'JAVA_HOME'} = Environment::getEnvironment()->javaHome();
	# Add java 5 compiler location to Environment PATH
	$ENV{'PATH'} = $ENV{'JAVA_HOME'} . 'bin' . $es . $ENV{'PATH'};

	# create and start source database
	$dbSrcCfg = DatabaseConfig->new('ids_to_sol.ini');
	$dbSrcCfg->initFromConfigFile("\\[DATABASE_SRC\\]","\\[/DATABASE_SRC\\]");
	$dbSrc = InformixDB->createFromConfig($dbSrcCfg);
	$dbSrc->start();
	$dbSrc->createDatabase($dbSrc->dbName());

	# create and start target database
	$dbTgtCfg = DatabaseConfig->new('ids_to_sol.ini');
	$dbTgtCfg->initFromConfigFile("\\[DATABASE_TGT\\]","\\[/DATABASE_TGT\\]");
	$dbTgt = SolidDB->createFromConfig($dbTgtCfg);
	$dbTgt->start();

	# Register source and target table names 
	$dbSrc->dbTableName('SRC');
	$dbTgt->dbTableName('TGT');

	# Store full table names (including schema name) for reuse
	$tblNameSrc = $dbSrc->dbTableName();
	$tblNameTgt = $dbTgt->dbSchema() . '.' . $dbTgt->dbTableName();
	
	# Create source table 'SRC'
	$dbSrc->execSqlStmt("create table $tblNameSrc (id integer, name char(50))");
	# Create target table 'TGT' with same structure as 'SRC'
	$dbTgt->execSqlStmt("create table $tblNameTgt (id integer, name char(50))");

	# create source CDC
	$cdcSrcCfg = CDCConfig->new('ids_to_sol.ini');
	$cdcSrcCfg->initFromConfigFile("\\[CDC_SRC\\]","\\[/CDC_SRC\\]");
	$cdcSrc = CDCInformix->createFromConfig($cdcSrcCfg,$dbSrc);

	# create target CDC
	$cdcTgtCfg = CDCConfig->new('ids_to_sol.ini');
	$cdcTgtCfg->initFromConfigFile("\\[CDC_TGT\\]","\\[/CDC_TGT\\]");
	$cdcTgt = CDCSolid->createFromConfig($cdcTgtCfg,$dbTgt);

	# create and start source/target cdc's
	$cdcSrc->create();
	$cdcTgt->create();
	$cdcSrc->start();
	$cdcTgt->start();

	pause("Please ensure that Access Server is running in the background\nPress <enter> to continue...\n");

	# Access server configuration
	$asCfg = AccessServerConfig->new('ids_to_sol.ini');
	$asCfg->initFromConfigFile("\\[ACCESSSERVER\\]","\\[/ACCESSSERVER\\]");
	
	# Create mConsole/Access server instance
	$mConsole = AccessServer->createFromConfig($asCfg);

	# create datastores
	$dsSrcCfg = DatastoreConfig->new('ids_to_sol.ini');
	$dsSrcCfg->initFromConfigFile("\\[DS_SRC\\]","\\[/DS_SRC\\]");
	$dsSrc = $mConsole->createDatastoreFromConfig($dsSrcCfg,$cdcSrc);
	$dsTgtCfg = DatastoreConfig->new('ids_to_sol.ini');
	$dsTgtCfg->initFromConfigFile("\\[DS_TGT\\]","\\[/DS_TGT\\]");
	$dsTgt = $mConsole->createDatastoreFromConfig($dsTgtCfg,$cdcTgt);
	$mConsole->source($dsSrc);	# assign source datastore
	$mConsole->target($dsTgt);	# assign target datastore
	
	$mConsole->assignDatastoreUser($dsSrc);
	$mConsole->assignDatastoreUser($dsTgt);

	$mConsole->createSubscription($sub);	# Create subscription between source and target datastores
	$mConsole->addMapping($sub);        	# Add default mapping to subscription
	$mConsole->startMirroring($sub);    	# Start mirroring

	# Insert some rows into the source table
	$dbSrc->execSqlStmt("insert into $tblNameSrc values (1,'One')");
	$dbSrc->execSqlStmt("insert into $tblNameSrc values (2,'Two')");
	$dbSrc->execSqlStmt("insert into $tblNameSrc values (3,'Three')");

	# Pause to allow mirroring to take effect
	sleep(10);

	# Read contents of target table
	$dbTgt->execSqlStmt("select * from $tblNameTgt");
	# Display results of sql command
	displayResults($dbTgt->dbDir() . $dbTgt->dbSqlOutputFile());

	pause("\nPress <enter> to start cleanup...\n");

};

# Error thrown in eval {...}
if ($@) { Environment::logf("\n\nErrors found: $@\n"); }

	# CLEANUP

	if (defined($mConsole)) {
		$mConsole->stopMirroring($sub);     	# Stop mirroring
		$mConsole->deleteMapping($sub);     	# Delete mapping
		$mConsole->deleteSubscription($sub);	# Delete subscription

		# Delete datastores
		$mConsole->deleteDatastore($dsTgt) if defined($dsTgt);
		$mConsole->deleteDatastore($dsSrc) if defined($dsSrc);
	}
	# stop and delete cdc instances
	if (defined($cdcSrc)) {
		$cdcSrc->stop();
		$cdcSrc->delete();
	}
	if (defined($cdcTgt)) {
		$cdcTgt->stop();
		$cdcTgt->delete();
	}

	# shut down databases
	$dbSrc->stop() if (defined($dbSrc));
	$dbTgt->stop() if (defined($dbTgt));
}




# Display contents of sql log file in notepad(windows)/gedit(linux)
sub displayResults
{
	my $logfile = shift;
	
	if (Environment->getEnvironment()->getOSName() eq 'windows') {
		system("notepad $logfile");
	} else {
		system("gedit $logfile");
	}
}



sub pause
{
	my $msg = shift || "Press <enter> to continue\n";
	my $inp;
	print $msg;
	$inp = <STDIN>;
}
