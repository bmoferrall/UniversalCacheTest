#!/usr/bin/perl

use strict;

use IBM::UC::Environment;
use IBM::UC::Database::SolidDB;
use IBM::UC::Database::Db2DB;
use IBM::UC::Database::InformixDB;
use IBM::UC::CDC::CDCSolid;
use IBM::UC::CDC::CDCDb2;
use IBM::UC::CDC::CDCInformix;
use IBM::UC::AccessServer::AccessServer;
use IBM::UC::TestBed;
use Switch;




switch ($ARGV[0]) {
	case "sol_to_sol" { replication_sol_to_sol(); }
	case "sol_to_db2" { replication_sol_to_db2(); }
	case "db2_to_db2" { replication_db2_to_db2(); }
	case "sol_to_ids" { replication_sol_to_ids(); }
	else { print "Please specify one of the following options\n\t/
			(sol_to_sol|sol_to_db2|db2_to_db2|sol_to_ids)\ne.g. replication_test.pl sol_to_sol\n" }
}


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
		email_admin => 'mooreof@ie.ibm.com',
		solid_root_dir => "C:\\Program Files\\IBM\\solidDB\\solidDB6.5\\",
		solid_licence_file => "C:\\autoInstalls\\solid.lic",
        java_home => "C:\\Program Files\\Java\\ibm-java2-sdk-50-win-i386\\",
        java6_home => "C:\\Program Files\\Java\\ibm-java-sdk-60-win-i386\\sdk",
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));
    $ENV{'JAVA_HOME'} = Environment::getEnvironment()->javaHome();
	$ENV{'JAVA6_HOME'} = Environment::getEnvironment()->javaSixHome();
	$ENV{'PATH'} = $ENV{'JAVA6_HOME'} . 'bin' . ';' . $ENV{'PATH'};
	
	# create and start source database
	$dbvals_src = { 
		db_port => '2315', 
		db_dir => "C:\\solid\\sol_src",
	};
	$db_src = SolidDB->createFromConfig(DatabaseConfig->createFromHash($dbvals_src));
	$db_src->start();

	# create and start target database
	$dbvals_tgt = { 
		db_port => '2316', 
		db_dir => "c:\\solid\\sol_tgt",
	};
	$db_tgt = SolidDB->createFromConfig(DatabaseConfig->createFromHash($dbvals_tgt));
	$db_tgt->start();

	# Set table name to replace placeholder %TABLE% in '*.sql'
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
		email_admin => 'mooreof@ie.ibm.com',
		cdc_solid_root_dir => $ENV{'HOME'} . '/Transformation Server for solidDB/',
		cdc_db2_root_dir => $ENV{'HOME'} . '/Transformation Server for UDB/',
		solid_root_dir => $ENV{'HOME'} . '/soliddb-6.5/',
		solid_licence_file => $ENV{'HOME'} . '/automation_workspace/Nightlies/solid.lic',
		java_home => $ENV{'HOME'} . '/ibm-java2-i386-50/',
		java6_home => $ENV{'HOME'} . '/ibm-java-i386-60/',
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));

	# create and start source database
	$dbvals_src = { 
		db_port => '2315', 
		db_dir => $ENV{'HOME'} . '/solid/sol_src',
	};
	$db_src = SolidDB->createFromConfig(DatabaseConfig->createFromHash($dbvals_src));
	$db_src->start();

	# create and start target database
	$dbvals_tgt = { 
		db_dir => $ENV{'HOME'} . '/db2inst1/NODE0000/TEST',
		db_name => 'TEST',
		db_user => 'db2inst1',
		db_pass => 'sacha12c',
	};
	$db_tgt = Db2DB->createFromConfig(DatabaseConfig->createFromHash($dbvals_tgt));
	$db_tgt->start();
	# Create database also connects to database
	$db_tgt->createDatabase();
	# Create schema
	$db_tgt->createSchema('db2inst1');

	# Set table name to replace placeholder %TABLE% in '*.sql'
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


# Create subscription and mirror between Solid source and Informix target
sub replication_sol_to_ids
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
		email_admin => 'mooreof@ie.ibm.com',
		solid_root_dir => "C:\\Program Files\\IBM\\solidDB\\solidDB6.5\\",
		solid_licence_file => "C:\\autoInstalls\\solid.lic",
		cdc_solid_root_dir => "C:\\Program Files\\DataMirror\\Transformation Server for solidDB\\",
		cdc_informix_root_dir => "C:\\Program Files\\DataMirror\\Transformation Server for Informix\\",
        java_home => "C:\\Program Files\\Java\\ibm-java2-sdk-50-win-i386\\",
        java6_home => "C:\\Program Files\\Java\\ibm-java-sdk-60-win-i386\\sdk",
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));
    $ENV{'JAVA_HOME'} = Environment::getEnvironment()->javaHome();
	$ENV{'JAVA6_HOME'} = Environment::getEnvironment()->javaSixHome();
	$ENV{'PATH'} = $ENV{'JAVA6_HOME'} . 'bin' . ';' . $ENV{'PATH'};

	# create and start source database
	$dbvals_src = { 
		db_port => '2315', 
		db_dir => "C:\\solid\\sol_src",
	};
	$db_src = SolidDB->createFromConfig(DatabaseConfig->createFromHash($dbvals_src));
	$db_src->start();

	# create and start target database
    $db_tgt = InformixDB->createSimple('informix',
		                               'INFORMIX123',
		                               "c:\\ids_dest",
		                               "INFORMIX_SERVER",                       
		                               "idsTst_db",
		                               9088,
		                               'informix');
	$db_tgt->start();

	# Set table name to replace placeholder %TABLE% in '*.sql'
	$db_src->dbTableName('src');
	$db_src->execSql('sol_createsrc.sql');	# Create table 'src'

	# Create database also connects to database
	$db_tgt->createDatabase($db_tgt->dbName());

	# Create schema
	$db_tgt->dbSchema('informix');
    $db_tgt->dbTableName('tgt');
	$db_tgt->execSqlStmt("create table tgt (id integer, fname char(50), sname char(50), address char(75), country char(25))");

    pause();	
	# create source CDC
	$cdc_src = CDCSolid->createSimple('solsrc_ts',11101,$db_src);
	$cdc_src->create();
	$cdc_src->start();
	
	sleep(10);
	
	# create target CDC
	$cdc_tgt = CDCInformix->createSimple('idstgt_ts',10210,$db_tgt);
	$cdc_tgt->create();
	$cdc_tgt->start();
    pause();
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
		                                       'idstgt_ds',		# datastore name
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
#	$db_tgt->execSql('db2_readtgt.sql');	# Read target table
	$db_tgt->execSqlStmt("select * from tgt");

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
		sleep(10);
		$cdc_src->delete();
	}
	if (defined($cdc_tgt)) {
		$cdc_tgt->stop();
		sleep(10);
		$cdc_tgt->delete();
	}

	# shut down databases
	$db_src->stop() if (defined($db_src));
	$db_tgt->stop() if (defined($db_tgt));
}



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
		email_admin => 'mooreof@ie.ibm.com',
		cdc_solid_root_dir => $ENV{'HOME'} . '/Transformation Server for solidDB/',
		cdc_db2_root_dir => $ENV{'HOME'} . '/Transformation Server for UDB/',
		java_home => $ENV{'HOME'} . '/ibm-java2-i386-50/',
		java6_home => $ENV{'HOME'} . '/ibm-java-i386-60/',
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));

	# create and start source database
	$dbvals_src = { 
		db_dir => $ENV{'HOME'} . '/db2inst1/NODE0000/TEST',
		db_name => 'TEST',
		db_user => 'db2inst1',
		db_pass => 'db2inst1',
	};
	$db_src = Db2DB->createFromConfig(DatabaseConfig->createFromHash($dbvals_src));
	$db_src->start();
	# createDatabase also connects to database
	$db_src->createDatabase();
	# Create schema
	$db_src->createSchema('db2inst1');

	# Start target and connect to it (already created above)
	$dbvals_tgt = { 
		db_dir => $ENV{'HOME'} . '/db2inst1/NODE0000/TEST',
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

	# Set table name to replace placeholder %TABLE% in '*.sql'
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
