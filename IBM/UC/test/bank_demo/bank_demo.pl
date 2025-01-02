#!/usr/bin/perl

# Driver script for Banking demonstration (December 2009)

use strict;

use IBM::UC::Environment;
use IBM::UC::Database::SolidDB;
use IBM::UC::Database::Db2DB;
use IBM::UC::CDC::CDCSolid;
use IBM::UC::CDC::CDCDb2;
use IBM::UC::AccessServer::AccessServer;
use Getopt::Long;
use Cwd;
use File::Copy;
use File::Copy::Recursive;

# $dbport and $bits can be overridden by passing in parameters -dbport and -bits
my ($dbport,$bits,$home) = (1323,32,'/home/db2inst1/');
my ($es,$ps,$cwd); # Environment and path separators, and current directory
my $hostname = $ENV{'HOSTNAME'};

# Installation packages
my $SOLID_PACKAGE_32 = 'solidDB6.5_x86.bin';
my $SOLID_PACKAGE_64 = 'solidDB6.5_x86_64.bin';
my $CDC_SOLID_PACKAGE = 'setup-linux-x86-solid.bin';
my $CDC_DB2_PACKAGE = 'setup-CDC-linux-x86-udb.bin';
my $ACCESS_SERVER_PACKAGE = 'dmaccess-6.3.1330.20-linux-x86-setup.bin';

# Installation locations
my $SOLID_INSTALL_DIR = $home . 'soliddb-6.5';
my $CDC_SOLID_INSTALL_DIR = $home . 'Transformation Server for solidDB';
my $CDC_DB2_INSTALL_DIR = $home . 'Transformation Server for UDB';
my $ACCESS_INSTALL_DIR = $home . "DataMirror/Transformation Server Access Control";


my @records_payments = (
	[1,999,"'IBM'","'Yahoo'",12300.45,"'POUND'","'Santander'","'BOE'",
					"'AIBK123874327487'","'AIBK123874329874'","'RECEIVED'"],
	[1,999,"'IBM'","'Google'",1955.29,"'DOLLAR'","'Santander'","'BOA'",
						"'AIBK123874327486'","'AIBK123874329874'","'RECEIVED'"],
	[1,999,"'IBM'","'ebay'",12123.59,"'EURO'","'Santander'","'BOI'",
						"'AIBK123874327485'","'AIBK123874329874'","'RECEIVED'"],
	[1,999,"'IBM'","'HP'",546.98,"'EURO'","'Santander'","'BOI'",
						"'AIBK123874327484'","'AIBK123874329874'","'RECEIVED'"],
	[1,999,"'IBM'","'Microsoft'",46454.56,"'DOLLAR'","'Santander'","'BOA'",
						"'AIBK123874327483'","'AIBK123874329874'","'RECEIVED'"],
	[1,999,"'IBM'","'Geodis'",65789.34,"'EURO'","'Santander'","'BOI'",
						"'AIBK123874327482'","'AIBK123874329874'","'RECEIVED'"],
);

my @records_info = (
	[1,"'Payment for inv 00001'","'12 Bakersfield Rd, London, BT1 4LS'","'Mulhuddart, Dublin, Ireland'",
						0.92,"'Message 1'"],
	[1,"'Payment for inv 00342'","'San Diego, CA, USA'","'Mulhuddart, Dublin, Ireland'",
						1.41,"'Message'"],
	[1,"'Payment for inv 01234'","'Blanchardstown, Dublin, Ireland'","'Mulhuddart, Dublin, Ireland'",
						1.0,"'Message 2'"],
	[1,"'Payment for inv 00045'","'Leixlip, Kildare, Ireland'","'Mulhuddart, Dublin, Ireland'",
						1.0,"'Message 3'"],
	[1,"'Payment for inv 00033'","'Sandyford, Dublin, Ireland'","'Mulhuddart, Dublin, Ireland'",
						1.41,"'Message 4'"],
	[1,"'Payment for inv 00004'","'Dublin 15, Ireland'","'Mulhuddart, Dublin, Ireland'",
						1.0,"'Message 5'"],
);


GetOptions("dbport=s" => \$dbport, "bits=s" => \$bits);
main();

sub main {
	my ($env_params,$sol_params,$db2_params);
	my ($solid,$db2);
	my ($cdc_src,$cdc_tgt);
	my ($as_cfg,$mConsole);
	my ($ds_src, $ds_tgt);
	my ($sql,$dir);

eval { # Trap errors
	$env_params = {
		debug => 1,
		smtp_server => 'D06DBE01',
    	email_admin => 'mooreof@ie.ibm.com',
		cdc_bits => $bits,
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_params));
	$ps = Environment::getEnvironment()->getPathSeparator();
	$es = Environment::getEnvironment()->getEnvSeparator();
	$cwd = Environment::getEnvironment()->getStartDir();
	Environment::getEnvironment()->javaHome($cwd . 'ibm-java2-i386-50');
	Environment::getEnvironment()->javaSixHome($cwd . 'ibm-java-i386-60');

	# Update Environment path variable to include java path
	$ENV{'JAVA_HOME'} = Environment::getEnvironment()->javaHome();
	$ENV{'JAVA6_HOME'} = Environment::getEnvironment()->javaSixHome();
	$ENV{'PATH'} = $ENV{'JAVA6_HOME'} . 'bin' . $es . $ENV{'PATH'};

	# Copy client driver
	if ($bits == 32) {
		File::Copy::Recursive::dircopy($cwd . 'clidriver32', $home . 'clidriver');
	} else {
		File::Copy::Recursive::dircopy('clidriver', $home);
	}

	# Install SolidDB
	if ($bits == 32) {
		SolidDB->install($SOLID_INSTALL_DIR, $cwd . "install${ps}${SOLID_PACKAGE_32}");
	} else {
		SolidDB->install($SOLID_INSTALL_DIR, $cwd . "install${ps}${SOLID_PACKAGE_64}");
	}

	# Create source Solid instance
	$sol_params = {
		db_dir => $home . "solid${ps}src",
		db_port => $dbport,
		db_host => 'localhost',
		db_inst => 'solid',
		solid_ini_template => 'solid_template.ini',
	};
	$solid = SolidDB->createComplex($sol_params);

	# Create target DB2 instance
	$db2_params = {
		db_dir => $home . "db2inst1${ps}NODE0000${ps}db2",
		db_name => 'db2',
		db_port => 50000,
		db_user => 'db2inst1',
		db_pass => 'db2inst1',
	};
	$db2 = Db2DB->createComplex($db2_params);

	# Update solid ini template file
	updateSolidIniFile($solid,$db2,'solid.ini');

	# Start solid
	$solid->start();
	# Import schema
	$solid->execSql("${cwd}sql${ps}solid.sql");
	# Solid installation directory
	$dir = Environment::getEnvironment()->solidRootDir();
	# Automatic aging
	$solid->execSql("${dir}procedures${ps}create_automatic_aging.sql");
	$solid->execSql("${dir}procedures${ps}start_automatic_aging.sql");
	sleep(5);
	$solid->execSql("${cwd}sql${ps}aging_rule.sql");

	# Install CDC for solid
	CDCSolid->install($CDC_SOLID_INSTALL_DIR, $cwd . "install${ps}${CDC_SOLID_PACKAGE}");
	# CDC for Solid installation directory
	$dir = Environment::getEnvironment()->CDCSolidRootDir();
	sleep(5);

	chdir($cwd);
	# Copy library patches
	File::Copy::cp("patch${ps}uc-utilities.jar", "${dir}samples${ps}ucutils${ps}lib${ps}");
	File::Copy::cp("patch${ps}ts.jar", "${dir}${ps}lib${ps}");
	File::Copy::cp("patch${ps}api2_UC65.jar", "${dir}${ps}lib${ps}");

	# Create and start CDC for Solid instance
	$cdc_src = CDCSolid->createSimple('solsrc_ts',11101,$solid);
	$cdc_src->create();
	$cdc_src->start();
	
	# Start DB2 manager and create target DB2 database/schema
	$db2->start();
	$db2->createDatabase();
	$db2->createSchema('db2inst1');
	$db2->execSql("${cwd}sql${ps}db2.sql");
	sleep(5);
	
	# Install CDC for DB2
	CDCDb2->install($CDC_DB2_INSTALL_DIR, $cwd . "install${ps}${CDC_DB2_PACKAGE}");

	# Create and start CDC for DB2 instance
	$cdc_tgt = CDCDb2->createSimple('db2tgt_ts',11102,$db2);
	$cdc_tgt->create();
	$cdc_tgt->start();

	sleep(10);

	# Install Access Server
	AccessServer->install($ACCESS_INSTALL_DIR, $cwd . "install${ps}${ACCESS_SERVER_PACKAGE}");

	# Access server configuration 
	$as_cfg = {ac_host => 'localhost',	# Access server host
			 	  ac_port => '10101',	# Access server port
				  ac_user => 'Admin',	# Access server user
				  ac_pass => 'admin123'};	# Access server password
	
	# Create mConsole/Access server instance
	$mConsole = AccessServer->createFromConfig(AccessServerConfig->createFromHash($as_cfg));
	$mConsole->startAccessServer();
	sleep(3);

	$mConsole->createAdminUser();

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
	
	# Assign source and target datastores
	$mConsole->source($ds_src);
	$mConsole->target($ds_tgt);

	# Assign datastore users
	$mConsole->assignDatastoreUser($ds_src);
	$mConsole->assignDatastoreUser($ds_tgt);

	# Create two source->target subscriptions
	$mConsole->createSubscription('payments');
	$mConsole->createSubscription('audits');	
	# Set source and target table names and create two source->target mappings
	$solid->dbTableName('WHOLE_SALE_PAYMENTS');
	$db2->dbTableName('WHOLE_SALE_PAYMENTS');
	$mConsole->addMapping('payments');
	$solid->dbTableName('PAYMENT_AUDIT_TRAIL');
	$db2->dbTableName('PAYMENT_AUDIT_TRAIL');
	$mConsole->addMapping('audits');

	# Swap source and target and create two target->source subscriptions
	$mConsole->source($ds_tgt); 
	$mConsole->target($ds_src);
	$mConsole->createSubscription('denial');	
	$mConsole->createSubscription('refresh');	
	# Set source and target table names and create two target->source mappings
	$solid->dbTableName('DENIAL_LIST');
	$db2->dbTableName('DENIAL_LIST');
	$mConsole->addMapping('denial');
	$solid->dbTableName('WHOLE_SALE_PAYMENTS');
	$db2->dbTableName('WHOLE_SALE_PAYMENTS');
	$mConsole->addMapping('refresh');

	pause("Remap tables on payments and refresh subscriptions using 'prevent recursion', 
			then create filters and press <enter> when ready to continue");

	$mConsole->flagForRefresh($ds_tgt,$db2->dbSchema().'.DENIAL_LIST','denial');
	$mConsole->refreshSubscription($ds_tgt,'denial');

	# Restore original source and targets
	$mConsole->source($ds_src);
	$mConsole->target($ds_tgt);

	# start mirroring for payments and audit trail
	$mConsole->startMirroring('payments audits');

	for (my $i=1; $i<2; $i++) {
		batchInsert_db2($db2,$i);
	}

	pause(">>db2 payments table updated");

	$sql = "insert into ts_refresh values ('refresh', 0, '', 0)";
	$solid->execSqlStmt($sql);
	pause(">>ts_refresh updated");
	
	for (my $i=2; $i<11; $i++) {
		batchInsert($solid,$i);
		pause(">>Insert round $i of 10 complete, press any key to continue");
		batchUpdate($solid);
		pause(">>Update round $i of 10 complete, press any key to continue");
	}
	batchUpdate($solid);
	pause(">>Updating some more... 11");
	batchUpdate($solid);
	pause(">>Updating some more... 12");

	print ">>Done.\n";
	print "\nPress <enter> to start cleanup...\n";

};
# Error thrown in eval {...}
if ($@) { Environment::logf("\n\nErrors found: $@\n"); }

	$mConsole->stopMirroring('payments audits'); # Stop mirroring
	$mConsole->deleteSubscription('payments'); # Delete subscription
	$mConsole->deleteSubscription('audits'); # Delete subscription

	# Delete datastores
	$mConsole->deleteDatastore($ds_tgt);
	$mConsole->deleteDatastore($ds_src);

	$mConsole->stopAccessServer();

	# stop and delete cdc instances
	$cdc_src->stop();
	$cdc_tgt->stop();
	$cdc_src->delete();
	$cdc_tgt->delete();

	# shut down databases
	$solid->stop();
	unlink($cwd . $solid->templateName()); # Delete temp. ini file
	$db2->stop();
}


sub batchInsert
{
	my $solid = shift;
	my $iloop = shift;
	my $cnt = 0;
	my $sql;
	my $rec;
	my $command;
	my $size = @records_payments;
	

	foreach $rec (@records_payments) {
		$cnt++;
		$rec->[0] = ($size*($iloop-1)) + $cnt;
		$sql = "insert into WHOLE_SALE_PAYMENTS values (${\join(',',@$rec)})";
		$solid->execSqlStmt($sql);
	}

	$cnt = 0;
	foreach $rec (@records_info) {
		$cnt++;
		$rec->[0] = ($size*($iloop-1)) + $cnt;
		$sql = "insert into DETAILED_TRANSACTION_INFORMATION values (${\join(',',@$rec)})";
		$solid->execSqlStmt($sql);
	}
}

sub batchInsert_db2
{
	my $db2 = shift;
	my $iloop = shift;
	my $cnt = 0;
	my $sql;
	my $rec;
	my $command;
	my $size = @records_payments;

	foreach $rec (@records_payments) {
		$cnt++;
		$rec->[0] = ($size*($iloop-1)) + $cnt;
		$sql = "insert into WHOLE_SALE_PAYMENTS values (${\join(',',@$rec)})";
		$db2->execSqlStmt($sql);
	}
}

sub batchUpdate
{
	my $solid = shift;
	my $sql;

	$sql = "update WHOLE_SALE_PAYMENTS  set current_state='COMPLETE' where current_state='REROUTING_PAYMENT'";
	$solid->execSqlStmt($sql);
	$sql = "update WHOLE_SALE_PAYMENTS set current_state='REROUTING_PAYMENT' where current_state='SUCCESS_DENIAL_LIST_LOOKUP'";
	$solid->execSqlStmt($sql);
	$sql = "update WHOLE_SALE_PAYMENTS set current_state='SUCCESS_DENIAL_LIST_LOOKUP' where current_state='PENDING_DENIAL_LIST_LOOKUP'";
	$solid->execSqlStmt($sql);
	$sql = "update WHOLE_SALE_PAYMENTS set current_state='PENDING_DENIAL_LIST_LOOKUP' where current_state='SUCCESS_FUNDS_AVAILABILITY'";
	$solid->execSqlStmt($sql);
	$sql = "update WHOLE_SALE_PAYMENTS set current_state='SUCCESS_FUNDS_AVAILABILITY' where current_state='PENDING_FUNDS_AVAILABILITY'";
	$solid->execSqlStmt($sql);
	$sql = "update WHOLE_SALE_PAYMENTS set current_state='PENDING_FUNDS_AVAILABILITY' where current_state='ACCOUNT_VERIFICATION'";
	$solid->execSqlStmt($sql);
	$sql = "update WHOLE_SALE_PAYMENTS set current_state='ACCOUNT_VERIFICATION' where current_state='RECEIVED'";
	$solid->execSqlStmt($sql);
}


# update ports, driver string and shared library home in solid ini file
sub updateSolidIniFile
{
	my $solid = shift;
	my $db2 = shift;
	my $ini = shift;
	my $contents;
	
	if (-f $ini) {
		open(INIFILE, '<', $ini) || die("Couldn't open \"$ini\": $!\n");
		$contents = join("",<INIFILE>);
		close(INIFILE);
		$contents =~ s/<_port_>/$solid->dbPort()/eg;
		$contents =~ s/<_db2_port_>/$db2->dbPort()/eg;
		$contents =~ s/<_db2_db_>/uc($db2->dbName())/eg;
		$contents =~ s/<_host_>/$hostname/eg;
		$contents =~ s/<_shared_library_home_>/$home."clidriver${ps}lib${ps}libdb2.so"/eg;
		open(INIFILE, '>', $solid->templateName()) || 
			die("Couldn't open \"${\$solid->templateName()}\": $!\n");
		print INIFILE $contents;
		close(INIFILE);
	} else {
		die "Cannot find solid ini file \"$ini\".\nExiting...\n";
	}
}

sub pause
{
	my $msg = shift || "Press <enter> to continue\n";
	my $inp;
	print $msg;
	$inp = <STDIN>;
}
