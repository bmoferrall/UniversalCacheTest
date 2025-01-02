#!/usr/bin/perl

use strict;

use IBM::UC::Environment;
use IBM::UC::Database::SolidDB;
use IBM::UC::Database::Db2DB;
use IBM::UC::CDC::CDCSolid;
use IBM::UC::CDC::CDCDb2;
use IBM::UC::AccessServer::AccessServer;
use IBM::UC::TestBed;
use Switch;




switch ($ARGV[0]) {
	case "sol_to_sol" { replication_sol_to_sol(); }
	else { print "Please specify one of the following options\n\t/
			(sol_to_sol)\ne.g. replication_test.pl sol_to_sol\n" }
}


# Create subscription and mirror between Solid source and Solid target
sub replication_sol_to_sol
{
	my $inp;
	my ($env_cfg,$solsrc_cfg,$soltgt_cfg);
	my ($db_src, $db_tgt);
	my ($cdcsrc_cfg, $cdctgt_cfg, $cdc_src, $cdc_tgt);
	my ($as_cfg, $mConsole);
	my ($dssrc_cfg, $dstgt_cfg, $ds_src, $ds_tgt);
	my $sub = 'subname';

eval { # trap errors so we can clean up before exiting

	$env_cfg = EnvironmentConfig->new('sol_to_sol.ini');
	$env_cfg->initFromConfigFile("\\[ENVIRONMENT\\]","\\[/ENVIRONMENT\\]");
	Environment->createFromConfig($env_cfg);

	# create and start source database
	$solsrc_cfg = DatabaseConfig->new('sol_to_sol.ini');
	$solsrc_cfg->initFromConfigFile("\\[DATABASE_SRC\\]","\\[/DATABASE_SRC\\]");
	$db_src = SolidDB->createFromConfig($solsrc_cfg);
	$db_src->start();

	# create and start target database
	$soltgt_cfg = DatabaseConfig->new('sol_to_sol.ini');
	$soltgt_cfg->initFromConfigFile("\\[DATABASE_TGT\\]","\\[/DATABASE_TGT\\]");
	$db_tgt = SolidDB->createFromConfig($soltgt_cfg);
	$db_tgt->start();

	# Set table name to replace placeholder %TABLE% in '*.sql'
	$db_src->execSql('sol_createsrc.sql');	# Create table 'src'
	$db_tgt->execSql('sol_createtgt.sql');	# Create table 'tgt'
	
	# create source CDC
	$cdcsrc_cfg = CDCConfig->new('sol_to_sol.ini');
	$cdcsrc_cfg->initFromConfigFile("\\[CDC_SRC\\]","\\[/CDC_SRC\\]");
	$cdc_src = CDCSolid->createFromConfig($cdcsrc_cfg,$db_src);

	# create target CDC
	$cdctgt_cfg = CDCConfig->new('sol_to_sol.ini');
	$cdctgt_cfg->initFromConfigFile("\\[CDC_TGT\\]","\\[/CDC_TGT\\]");
	$cdc_tgt = CDCSolid->createFromConfig($cdctgt_cfg,$db_tgt);

	# create and start source/target cdc's
	$cdc_src->create();
	$cdc_tgt->create();
	$cdc_src->start();
	$cdc_tgt->start();

	# Access server configuration 
	$as_cfg = AccessServerConfig->new('sol_to_sol.ini');
	$as_cfg->initFromConfigFile("\\[ACCESSSERVER\\]","\\[/ACCESSSERVER\\]");
	
	# Create mConsole/Access server instance
	$mConsole = AccessServer->createFromConfig($as_cfg);

	# create datastores
	$dssrc_cfg = DatastoreConfig->new('sol_to_sol.ini');
	$dssrc_cfg->initFromConfigFile("\\[DS_SRC\\]","\\[/DS_SRC\\]");
	$ds_src = $mConsole->createDatastoreFromConfig($dssrc_cfg,$cdc_src);
	$dstgt_cfg = DatastoreConfig->new('sol_to_sol.ini');
	$dstgt_cfg->initFromConfigFile("\\[DS_TGT\\]","\\[/DS_TGT\\]");
	$ds_tgt = $mConsole->createDatastoreFromConfig($dstgt_cfg,$cdc_tgt);
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

	pause("Press <enter> to start cleanup\n");

};

# Error thrown in eval {...}
if ($@) { Environment::logf("\n\nErrors found: $@\n"); }

	# CLEANUP

	if (defined($mConsole)) {
		$mConsole->stopMirroring($sub);     	# Stop mirroring
		$mConsole->deleteMapping($sub);     	# Delete mapping
		$mConsole->deleteSubscription($sub);	# Delete subscription

		# Delete datastores
		$mConsole->deleteDatastore($ds_tgt) if defined($ds_tgt);
		$mConsole->deleteDatastore($ds_src) if defined($ds_src);
	}
	# stop and delete cdc instances
	if (defined($cdc_src)) {
		$cdc_src->stop();
		$cdc_src->delete();
	}
	if (defined($cdc_tgt)) {
		$cdc_tgt->stop();
		$cdc_tgt->delete();
	}

	# shut down databases
	$db_src->stop() if (defined($db_src));
	$db_tgt->stop() if (defined($db_tgt));
}



sub pause
{
	my $msg = shift || "Press <enter> to continue\n";
	my $inp;
	print $msg;
	$inp = <STDIN>;
}
