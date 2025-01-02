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



print "*********************************************\n";
print "THIS ROUTINE PERFORMS A SMOKE TEST IN TESTBED\n";
print "FOR A SOLID SOURCE AND A DB2 TARGET\n";
print "*********************************************\n\n\n";
sleep(3);
testbed_smoke_sol_to_db2();




sub testbed_smoke_sol_to_db2
{
	my $inp;
	my ($env_parms,$db2_params);
	my ($db_src, $db_tgt);
	my ($cdc_src, $cdc_tgt);
	my ($as_cfg, $mConsole);
	my ($ds_src, $ds_tgt);
	my ($testbed,$tb_parms);
	my $home = $ENV{'HOME'};
	my $es;


eval { # trap errors so we can clean up before exiting

	# Initialise some environment parameters 
	 $env_parms = {
		debug => 1,
		smtp_server => 'D06DBE01',
		email_admin => 'mooreof@ie.ibm.com',
		email_on_error => 0,
		solid_root_dir => $home . "/soliddb-6.5",
		solid_licence_file => $home . "/soliddb-6.5/solid.lic", 
		cdc_solid_root_dir => $home . "/Transformation Server for solidDB/",
	    access_server_root_dir => $home . "/DataMirror/Transformation Server Access Control/",
        java_home => $home . "/ibm-java2-i386-50/", # Java 5 home directory
		cdc_db2_root_dir => $home . '/Transformation Server for UDB/',
		testbed_head_dir => $home . '/workspace/TestBed_HEAD/',
		testbed_qa_approved_dir => $home . '/workspace/QA_Approved/',
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));
	$es = Environment->getEnvironment()->getEnvSeparator();
    $ENV{'JAVA_HOME'} = Environment::getEnvironment()->javaHome();
	# Add java 5 compiler location to Environment PATH
	$ENV{'PATH'} = $ENV{'JAVA_HOME'} . 'bin' . $es . $ENV{'PATH'};


	# create and start source database
	$db_src = SolidDB->createSimple($home . '/solid/src',2315);
	$db_src->start();
	
	# create source CDC
	$cdc_src = CDCSolid->createSimple('solsrc_ts',11101,$db_src);

	# create and start target database
	my $db2_params = {
		db_dir => $home . '/db2inst1/NODE0000/TEST',
		db_name => 'TEST',
		db_user => 'db2inst1',
		db_pass => 'sacha12c',
	};
	$db_tgt = Db2DB->createComplex($db2_params);
	$db_tgt->start();
	# Create target database, connect to it
	$db_tgt->createDatabase();
	# Create schema 
	$db_tgt->createSchema('db2schema');
	
	# create target CDC
	$cdc_tgt = CDCDb2->createSimple('db2tgt_ts',11102,$db_tgt);

	# create and start source/target cdc's
	$cdc_src->create();
	$cdc_tgt->create();

	$cdc_src->start();
	$cdc_tgt->start();

	# Access server configuration 
	# (config will be reused in TestBed, hence not using AccessServer->createSimple())
	$as_cfg = {ac_host => 'localhost', # Access server host
	 			ac_port => '10101', # Access server port
				ac_user => 'Admin', # Access server user
				ac_pass => 'admin123'}; # Access server password
	
	# Create mConsole/Access server instance
	$mConsole = AccessServer->createFromConfig(AccessServerConfig->createFromHash($as_cfg));

	# create datastores
	$ds_src = $mConsole->createDatastoreSimple(
		'solsrc_ds', # datastore name
		'Source datastore', # datastore description
		'localhost', # datastore host
		$cdc_src, # cdc instance
	);
	$ds_tgt = $mConsole->createDatastoreSimple(
		'db2tgt_ds', # datastore name
		'Target datastore', # datastore description
		'localhost', # datastore host
		$cdc_tgt,  # cdc instance
	);
	$mConsole->source($ds_src); # assign source datastore
	$mConsole->target($ds_tgt); # assign target datastore
	
	# Following commands currently not working
	$mConsole->assignDatastoreUser($ds_src);
	$mConsole->assignDatastoreUser($ds_tgt);

	# Testbed initialsed from access server config only, common testbed config stuff is 
	# initialised in Environment config
	$testbed = TestBed->new(AccessServerConfig->createFromHash($as_cfg));

	# Assign source and target datastores
	$testbed->source($ds_src);
	$testbed->target($ds_tgt);

	$testbed->writeEnvironment(); # Write environment.xml file

	pause();
		
	# Testbed config for run() routine (all these parameters have defaults)
	$tb_parms = {tb_user => 'mooreof', # user name
				 tb_test_single => '', # single test name 
				 tb_test_list => 'SMOKE', # list name (to contain list of tests to run)
				 tb_email => 'mooreof@ie.ibm.com', # email to receive report
				 tb_clean => 1, # Testbed clean up option
				 tb_prefix => 'TB', # Testbed prefix (2-character)
				 tb_cmd_opt => '-cx FUNCTIONALITY=LARGE_OBJECT -c',
	};

	# run test using parameters specified in config object
	$testbed->run(TestBedConfig->createFromHash($tb_parms));
	$testbed->processResults(); # parse result logs and send email
};

# Error thrown in eval {...}
if ($@) { Environment::logf("\n\nErrors found: $@\n"); }

	# CLEANUP

	if (defined($mConsole)) {
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

