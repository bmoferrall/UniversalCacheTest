#!/usr/bin/perl
########################################################################
# 
# File   :  testSub.pl
# History:  Apr-2010 (cg) module created as part of Test Automation
#			project
#
########################################################################
#
# testSub.pml Program used to install databases/Transformation servers, create TS instances/datatastors
# and run testbed as per user requirements
# 
########################################################################
use strict;

use IBM::UC::CDC;
use IBM::UC::Environment;
use IBM::UC::AccessServer::AccessServer;

use IBM::UC::Database::SolidDB;
use IBM::UC::CDC::CDCSolid;

use IBM::UC::Database::InformixDB;
use IBM::UC::CDC::CDCInformix;

use IBM::UC::CDC::CDCDb2;
use IBM::UC::Database::Db2DB;

use IBM::UC::TestBed;
use IBM::UC::UCConfig::AccessServerConfig;

use IBM::UC::Install;
use IBM::UC::UCConfig::InstallConfig;

use Switch;

my $g_IDS_port = 10201;
my $g_UDB_port = 10901;
my $g_solidDB_port = 11101;
my $g_srcIDS_TSinstanceName = 'ids_ts_src';
my $g_tgtIDS_TSinstanceName = 'ids_ts_tgt';
my $g_srcUDB_TSinstanceName = 'udb_ts_src';
my $g_tgtUDB_TSinstanceName = 'udb_ts_tgt';
my $g_srcsolidDB_TSinstanceName = 'sol_ts_src';
my $g_tgtsolidDB_TSinstanceName = 'sol_ts_tgt';

my $g_beConfig;          # name of config file for backend
my $g_feConfig;          # name of config file for frontend
my $g_scenario;          # description of what is being tested
my $g_informixBE=0;

my $g_frontEnd=0;        # 1 - frontend: 0 - backend
my $g_test;              # Test description
my $g_installsDir;
my $g_directory;
my $g_CDCRootDir;
my $g_ip;
my $g_backendDBStarted=0;
my $g_frontendDBStarted=0;

main();

#-----------------------------------------------------------------------
# main()
#-----------------------------------------------------------------------
#
# main() driver program for testing
#
#-----------------------------------------------------------------------

sub main
{
    my ($beConfig, $feConfig, $scenario);
    my ($srcSrvr, $tgtSrvr, $srcTable, $tgtTable, $subscription);
    my $installCfg;
	my $install;

    initialize();

    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $g_ip = ((`ipconfig`) =~ /IP Address. . . . . . . . . . . . : (\S+)/);
        $g_ip = $1; 
    }
    else {
        $g_ip = ((`/sbin/ifconfig`) =~ /inet addr:(\S+)/);
        $g_ip = $1;
    }

    # parse and verify parameters entered
    ($beConfig, $feConfig, $scenario) = parseArguments(\@ARGV);
	
	$install = processInstall();

    if (($g_test eq "mirror") || ($g_test eq "refresh") || ($g_test eq "testbed")) {
        performARepl(\@$beConfig, \@$feConfig, \@$scenario, $install);
    }
    elsif (($#ARGV + 1) == 2) { # Install a Database either ids/db2/solidDB
        $g_scenario = @$scenario[0];
        $g_feConfig = @$feConfig[0];    
        installModules($install, $g_scenario, $g_feConfig);
    }
    elsif (($#ARGV + 1) == 3) { # Starting
        $g_scenario = @$scenario[0];
        $g_beConfig = @$beConfig[0];    
        installModules($install);

        ($srcSrvr, $tgtSrvr, $srcTable, $tgtTable, $subscription) = setup();

        runTest($srcSrvr, $tgtSrvr, $srcTable, $tgtTable, $subscription);
    }
    elsif (($#ARGV + 1) == 4) { # Stopping
        $g_scenario = @$scenario[0];
        $g_feConfig = @$feConfig[0];    
        stop();
    }
    elsif ($#ARGV <= 2) {
        runTests($ARGV[0], $install);
    }
    else {
        die "Usage: \n";
    }
}

#-----------------------------------------------------------------------
# processInstall()
#-----------------------------------------------------------------------
#
# Reads the install.ini file for a list of the programs that if
# may/may not need to be installed.
#
#-----------------------------------------------------------------------

sub processInstall()
{
    my $installCfg;
	my $install;
	
    $installCfg = InstallConfig->new('install.ini');
    $installCfg->initFromConfigFile("\\[INSTALL\\]","\\[/INSTALL\\]");
    $install = Install->createFromConfig($installCfg);
	return $install;
}

sub runTests()
{
    my $test = shift;
	my $install = shift;
    my $cdcInstance;
    my ($cdcSubInstanceSrc, $cdcSubInstanceTgt);
    my ($server, $tgtSrvr, $srcTable, $tgtTable, $subscription);
    my ($beConfig_ref, $feConfig_ref, $scenario_ref);
    my @subListParams;

    switch (lc($test)) {
        case "test_sol_ids" {
            $g_test = "createsub";
            @subListParams = ('-b', 'soliddb', 'DB_solidSRC_w.ini', '-f', 'ids', 'DB_IDS_w.ini', '-I', 'c:\\autoinstalls');
            ($beConfig_ref, $feConfig_ref, $scenario_ref) = parseArguments(\@subListParams);

            performARepl(\@$beConfig_ref, \@$feConfig_ref, \@$scenario_ref, $install);
        }
        case "test_sol_udb" {
            $g_test = "createsub";
            @subListParams = ('-f', 'soliddb', 'DB_solidDB_w.ini', '-b', 'udb', 'DB_UDB_w.ini', '-I', 'c:\\autoinstalls');
            ($beConfig_ref, $feConfig_ref, $scenario_ref) = parseArguments(\@subListParams);

            performARepl(\@$beConfig_ref, \@$feConfig_ref, \@$scenario_ref, $install);
        }
        case "test_sol_ora" {
            $g_test = "createsub";
            @subListParams = ('-f', 'soliddb', 'DB_solidDB_w.ini', '-b', 'ora', 'DB_ORA_w.ini', '-I', 'c:\\autoinstalls');
            ($beConfig_ref, $feConfig_ref, $scenario_ref) = parseArguments(\@subListParams);

            performARepl(\@$beConfig_ref, \@$feConfig_ref, \@$scenario_ref, $install);
        }
        case "create_ids_ts" {
            # initialise
            $g_scenario = "ids";
            if (Environment::getEnvironment()->getOSName() eq 'windows') {
                $g_beConfig = "DB_IDS_w.ini";
            }
            else {
                $g_beConfig = "DB_IDS_l.ini";
            }

            # setup for instance creation
            ($server, $tgtSrvr, $srcTable, $tgtTable, $subscription) = setup();

            # create a logical CDC instane
            $cdcInstance = CDCInformix->createSimple($g_srcIDS_TSinstanceName, $g_IDS_port, $server);

            # create a real one
            $cdcInstance->create();

            # list it
            CDC->list($g_CDCRootDir);

            # start the instance
            $cdcInstance->start();

            # list again to see it's status changed
            CDC->list($g_CDCRootDir);

            # stop it
            $cdcInstance->stop();

            # delete it
            $cdcInstance->delete();

            # list again to see that it is gone
            $cdcInstance->list($g_CDCRootDir);
        }
        case "create_udb_ts" {
            # initialise
            $g_scenario = "udb";
            if (Environment::getEnvironment()->getOSName() eq 'windows') {
                $g_beConfig = "DB_UDB_w.ini";
            }
            else {
                $g_beConfig = "DB_UDB_l.ini";
            }

            # setup for instance creation
            ($server, $tgtSrvr, $srcTable, $tgtTable, $subscription) = setup();

            # create a logical CDC instane
            $cdcInstance = CDCDb2->createSimple($g_tgtUDB_TSinstanceName, $g_UDB_port, $server);

            # create a real one
            $cdcInstance->create();

            # list it
            CDC->list($g_CDCRootDir);

            # start the instance
            $cdcInstance->start();

            # list again to see it's status changed
            CDC->list($g_CDCRootDir);

            # stop it
            $cdcInstance->stop();

            # delete it
            $cdcInstance->delete();

            # list again to see that it is gone
            $cdcInstance->list($g_CDCRootDir);
        }
        case "create_soliddb_ts" {
            # initialise
            $g_scenario = "soliddb";
            if (Environment::getEnvironment()->getOSName() eq 'windows') {
                $g_beConfig = "DB_SolidSRC_w.ini";
            }
            else {
                $g_beConfig = "DB_SolidSRC_l.ini";
            }

            # setup for instance creation
            ($server, $tgtSrvr, $srcTable, $tgtTable, $subscription) = setup();

            # create a logical CDC instane
            $cdcInstance = CDCSolid->createSimple($g_srcIDS_TSinstanceName, $g_IDS_port, $server);

            # create a real one
            $cdcInstance->create();

            # list it
            CDC->list($g_CDCRootDir);

            # start the instance
            $cdcInstance->start();

            # list again to see it's status changed
            CDC->list($g_CDCRootDir);

            # stop it
            $cdcInstance->stop();

            # delete it
            $cdcInstance->delete();

            # list again to see that it is gone
            $cdcInstance->list($g_CDCRootDir);
        }
        case "create_ora_ts" {
        }
    }
}

sub performARepl()
{
    my ($beConfig, $feConfig, $scenario, $install) = @_;
    my ($srcSrvr, $tgtSrvr, $srcTable, $tgtTable, $subscription);

    $g_scenario = @$scenario[0];
    $g_beConfig = @$beConfig[0];

    # install and create/start instance
    installModules($install);
    ($srcSrvr, $tgtSrvr, $srcTable, $tgtTable, $subscription) = setup();
    runTest($srcSrvr, $tgtSrvr, $srcTable, $tgtTable, $subscription);
 
    $g_scenario = @$scenario[1];
    $g_feConfig = @$feConfig[1];
    $g_beConfig = @$beConfig[1];

    # install and create/start instance and test
    $g_frontEnd = 1;
    installModules($install);
    ($srcSrvr, $tgtSrvr, $srcTable, $tgtTable, $subscription) = setup();
    runTest($srcSrvr, $tgtSrvr, $srcTable, $tgtTable, $subscription);
}
#-----------------------------------------------------------------------
# parseArguments()
#-----------------------------------------------------------------------
#
# main() Parses & verifies arguments received
#
#-----------------------------------------------------------------------

sub parseArguments()
{
    my ($argList) = @_;
    
    my $bIdx = getOption(\@$argList, '-b'); # frontend
    my $fIdx = getOption(\@$argList, '-f'); # backend
    my $sIdx = getOption(\@$argList, '-s'); # stopping

    my (@beConfigList,  @feConfigList, @scenarioList); # storage for lists to be obtained
 
    if (@$argList == 7 && $bIdx != -1 && $fIdx != -1) {

        unless ((-r @$argList[$fIdx + 2]) && (-r @$argList[$bIdx + 2])) {
            die "Cannot read both files @$argList[$fIdx + 2], @$argList[$bIdx + 2] simultaneously\n";
        }

        # backend
        $scenarioList[0] = lc(@$argList[$bIdx + 1]);
        $beConfigList[0] = @$argList[$bIdx + 2];

        #frontend
        $scenarioList[1] = lc(@$argList[$fIdx + 1]) . "_to_" . lc(@$argList[$bIdx + 1]);
        $feConfigList[1] = @$argList[$fIdx + 2];
        $beConfigList[1] = @$argList[$bIdx + 2];
        
        $g_test = lc(@$argList[0]); # record test name
    }
    elsif ((@$argList == 3) && ($bIdx == -1) && ($fIdx == -1)) {
        $scenarioList[0] = lc(@$argList[1]);
        $feConfigList[0] = @$argList[2];
    }
	elsif ((@$argList == 3) && (($bIdx != -1) || ($fIdx != -1))) {
        my $tIdx;

        if ($bIdx != -1) {
            $tIdx = $bIdx;
        }
        else {
            $tIdx = $fIdx;
            $g_IDS_port = 10200;
            $g_UDB_port = 10900;
            $g_solidDB_port = 11100;
            $g_tgtIDS_TSinstanceName = $g_srcIDS_TSinstanceName;
            $g_tgtUDB_TSinstanceName = $g_srcUDB_TSinstanceName;
            $g_tgtsolidDB_TSinstanceName = $g_srcsolidDB_TSinstanceName;
        }
		
        if (-r @$argList[$tIdx + 2]) {
            $scenarioList[0] = lc(@$argList[$tIdx + 1]);
            $beConfigList[0] = @$argList[$tIdx + 2];
        }
        else {
            die "Cannot read file @$argList[$bIdx + 2]\n";
        }
    }
    elsif (@$argList == 4 && $sIdx != -1 && ($bIdx != -1 || $fIdx != -1)) {
        my $idx = ($bIdx == -1) ? $fIdx : $bIdx;

        if (-r @$argList[$idx]) {
            $scenarioList[0] = lc(@$argList[$idx + 1]);
            $feConfigList[0] = @$argList[$idx + 2];
            
            if ($bIdx == -1) {
                $g_frontEnd = 1;
            }
        }
        else {
            die "Cannot read file @$argList[$idx + 2]\n";
        }
    }
    elsif (@$argList == 2) { # installing a DB only
        if (-r @$argList[1]) {
			$scenarioList[0] = lc(@$argList[0]);
	    	$feConfigList[0] = @$argList[1];
	    	$g_frontEnd = 1;
    	}
        else {
            die "Cannot read file @$argList[1]\n";
        }
    }	

    return (\@beConfigList, \@feConfigList, \@scenarioList);
}

#-----------------------------------------------------------------------
# getOption()
#-----------------------------------------------------------------------
#
# Gets location of option of interest. If option being sought is not found -1
# returned otherwise >= 0 returned
#
#-----------------------------------------------------------------------

sub getOption()
{
    my ($argList, $key) = @_;

    for (my $index = 0; $index < @$argList;$index++) {
        
        if (lc(@$argList[$index]) eq $key) {
            return $index; # found it
        }
    }

    return -1; # not there
}

#-----------------------------------------------------------------------
# stop()
#-----------------------------------------------------------------------
#
# Stops a CDC instance. Can only stop a TS if you are on the machine
# it is running on
#
#-----------------------------------------------------------------------

sub stop()
{
    my $server;
    my $instanceName;
    my $port;
    my $ts = 0;

    chdir($g_directory);

    switch ($g_scenario) {
        case "ids" {
            $server = InformixDB->createFromFile($g_feConfig);

            $instanceName = ($g_frontEnd == 1) ? $g_srcIDS_TSinstanceName : $g_tgtIDS_TSinstanceName;
            $port = ($g_frontEnd == 1) ? $g_IDS_port : ($g_IDS_port + 1);

            $ts =  CDCInformix->createSimple($instanceName, $port, $server);
        }
        case "udb" {
            $server = Db2DB->createFromFile($g_feConfig);

            $instanceName = ($g_frontEnd == 1) ? $g_srcUDB_TSinstanceName : $g_tgtUDB_TSinstanceName;
            $port = ($g_frontEnd == 1) ? $g_UDB_port : ($g_UDB_port + 1);

            $ts = CDCDb2->createSimple($instanceName, $port,  $server);    
        }
        case "soliddb" {
            $server = SolidDB->createFromFile($g_feConfig);

            $instanceName = ($g_frontEnd == 1) ? $g_srcsolidDB_TSinstanceName : $g_tgtsolidDB_TSinstanceName;
            $port = ($g_frontEnd == 1) ? $g_solidDB_port : ($g_solidDB_port + 1);

            $ts = CDCSolid->createSimple($instanceName, $port, $server);
        }
    }

    if ($ts) {
        if ($g_frontEnd == 1) {  # stop TS
            $ts->stop(); # only stop on frontend
        }

        $ts->delete(); # delete object
    }

    if ($server && $g_frontEnd == 1) { # stop database on frontend
        $server->stop();
    }
}

#-----------------------------------------------------------------------
# installModules()
#-----------------------------------------------------------------------
#
# May install a database and/or a CDC if not installed
#
#-----------------------------------------------------------------------

sub installModules()
{
    my $install = shift;
    my $dbType = shift;
    my $configFile = shift;
    my $server;
    my ($CDC_to, $CDC_from);
    my ($DB_from, $DB_to);

    $configFile = ($g_frontEnd == 1) ? $g_feConfig : $g_beConfig;
	
	$CDC_from = $install->ts_soliddb();
    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $g_CDCRootDir = 'C:\\Program Files\\DataMirror\\Transformation Server for solidDB'; 
    }
    else {
        $g_CDCRootDir = "$ENV{'HOME'}" . "/Transformation\ Server\ for\ solidDB";
    }

    unless (-d $g_CDCRootDir) { # need to install solidDB CDC
        CDCSolid->install($g_CDCRootDir, $CDC_from);
            
        # on UNIX cp can be aliased to ask if u want to copy so ensure it's unalisaed
        if (Environment::getEnvironment()->getOSName() ne 'windows') {
			system("unalias cp");
        }
    }
	
	if (index($g_scenario, "soliddb") == 0) { # solidDB
		$DB_from = $install->db_soliddb();
		if (Environment::getEnvironment()->getOSName() eq 'windows') {
			$DB_to = 'C:\\Program Files\\IBM\\solidDB\\solidDB6.5';
		}
		else {
			$DB_to = "/opt/solidDB/solidDB6.5/";
		}
		
		unless (-d $DB_to) { # need to install solidDB server
			SolidDB->install($DB_to, $DB_from);
		}
	}
    elsif (index($g_scenario, "ids") == 0) { # Informix
		$DB_from = $install->db_ids();
		$CDC_from = $install->ts_ids();
		
        if (Environment::getEnvironment()->getOSName() eq 'windows') {   
            $g_CDCRootDir = 'C:\\Program Files\\DataMirror\\Transformation Server for Informix';
        }
        else {     
            $g_CDCRootDir = "$ENV{'HOME'}" . "/Transformation\ Server\ for\ Informix";
        }

        $server = InformixDB->createFromFile($configFile);

        if ($g_ip ne $server->dbHost()) {
            return;
        }
        
        # check if DB server needs to be installed
        unless (-d $server->dbDir()) { # database installation
           $server->install($DB_from);
        }

        # check if CDC needs to be installed
        unless (-d $g_CDCRootDir) {
            CDCInformix->install($g_CDCRootDir, $CDC_from);
        }
    }
    elsif (index($g_scenario, "udb") == 0) { # DB2
	    $CDC_from = $install->ts_udb();
        if (Environment::getEnvironment()->getOSName() eq 'windows') {
            $g_CDCRootDir = 'C:\\Program Files\\DataMirror\\Transformation Server for UDB';
        }
        else {           
            $g_CDCRootDir = "$ENV{'HOME'}" . "/Transformation\ Server\ for\ UDB";	
        }

        # If no directory to install from we're finished here
        if (length($g_installsDir) == 0) {
            return;
        }

	    $server = Db2DB->createFromFile($configFile);

        if ($g_ip ne $server->dbHost()) {
            return;
        }

        unless (-d $g_CDCRootDir) {
            CDCDb2->install($g_CDCRootDir, $CDC_from);
        }
    }
}

#-----------------------------------------------------------------------
# subscriptionTests()
#-----------------------------------------------------------------------
#
# May install a database and/or a CDC if not installed
#
#-----------------------------------------------------------------------

sub setup()
{
    my $srcTable = 'src';
    my $tgtTable = 'tgt';
    my $subscription = 'SUB';
    my ($srcSrvr, $tgtSrvr);

    my @setupDataCollected;

    $g_directory = Cwd::getcwd();

    if ($g_frontEnd == 0) {
        switch ($g_scenario) {
            case "ids" {     
                $srcSrvr = getInformixServer($g_beConfig, $srcTable, $tgtTable, \$g_backendDBStarted);
            }
            case "udb" {
                $srcSrvr = getDb2Server($g_beConfig, uc($srcTable), uc($tgtTable), \$g_backendDBStarted); 
                
                $srcTable = uc($srcTable);
                $tgtTable = uc($tgtTable);
            }
            case "soliddb" {
                $srcSrvr = getsolidDBServer($g_beConfig, uc($srcTable), uc($tgtTable), \$g_backendDBStarted);
                $srcTable = uc($srcTable);
                $tgtTable = uc($tgtTable);
            }
        }
    }
    else {     
        switch ($g_scenario) {
            case "ids_to_ids" {

                $srcSrvr = getInformixServer($g_feConfig, $srcTable, $tgtTable,\$g_frontendDBStarted);
                $tgtSrvr = getInformixServer($g_beConfig, $srcTable, $tgtTable, \$g_backendDBStarted);
            }
            case "ids_to_soliddb" {

                $srcSrvr = getInformixServer($g_feConfig, $srcTable, $tgtTable, \$g_frontendDBStarted);
                $tgtSrvr = getsolidDBServer($g_beConfig, uc($srcTable), uc($tgtTable), \$g_backendDBStarted);
                $tgtTable = uc($tgtTable);
            }
            case "soliddb_to_ids" {

                $srcSrvr = getsolidDBServer($g_feConfig, uc($srcTable), uc($tgtTable), \$g_frontendDBStarted);
                $tgtSrvr = getInformixServer($g_beConfig , $srcTable, $tgtTable, \$g_backendDBStarted);
                $srcTable = uc($srcTable);    
            }
            case "soliddb_to_soliddb" {

                $srcSrvr = getsolidDBServer($g_feConfig, uc($srcTable), uc($tgtTable), \$g_frontendDBStarted);
                $tgtSrvr = getsolidDBServer($g_beConfig, uc($srcTable), uc($tgtTable), \$g_backendDBStarted);
                $srcTable = uc($srcTable);
                $tgtTable = uc($tgtTable);
            }
            case "soliddb_to_udb" { # with solid as src it doesn't work

                $srcSrvr = getsolidDBServer($g_feConfig, uc($srcTable), uc($tgtTable), \$g_frontendDBStarted);
                $tgtSrvr = getDb2Server($g_beConfig, uc($srcTable), uc($tgtTable), \$g_backendDBStarted);
                $srcTable = uc($srcTable);
                $tgtTable = uc($tgtTable);
            }
            case "udb_to_soliddb" { # UPPERCASE WORKS ONLY FOR DB2 as SRC

                $srcSrvr = getDb2Server($g_feConfig, uc($srcTable), uc($tgtTable), \$g_frontendDBStarted);
                $tgtSrvr = getsolidDBServer($g_beConfig , uc($srcTable), uc($tgtTable), \$g_backendDBStarted);
                $tgtTable = uc($tgtTable);
                $srcTable = uc($srcTable);
            }
            case "udb_to_udb" { # Doesn't work

                $srcSrvr = getDb2Server($g_feConfig, uc($srcTable), uc($tgtTable), \$g_frontendDBStarted);
                $tgtSrvr = getDb2Server($g_beConfig, uc($srcTable), uc($tgtTable), \$g_backendDBStarted);
                
                $srcTable = uc($srcTable);
                $tgtTable = uc($tgtTable);
            }
            else {
                print "Please specify one of the following options\n\t/
                (sol_to_sol|sol_to_ids|ids_to_ids|ids_to_sol|udb_to_sol|sol_to_udb)\ne.g. informix.pl sol_to_sol\n";
                return;
            }
        }
    }

    $setupDataCollected[0] = $srcSrvr;
    $setupDataCollected[1] = $tgtSrvr;
    $setupDataCollected[2] = $srcTable;
    $setupDataCollected[3] = $tgtTable;
    $setupDataCollected[4] = $subscription;
    
    return @setupDataCollected;
}

#-----------------------------------------------------------------------
# runTest()
#-----------------------------------------------------------------------
#
# Runs the test requested by user
#
#-----------------------------------------------------------------------

sub runTest
{
    my ($src_ts, $tgt_ts);
	my ($ds_src, $ds_tgt);
    my $ds_name;
    my ($srcTable, $tgtTable);
	my ($srcPort, $tgtPort);

    my ($srcSrvr, $tgtSrvr, $srcTableName, $tgtTableName, $subscription) = @_;
    # ASSUMPTION: CDC IS ON THE SAME SYSTEM AS DATABASE OR ON THE MACHINE THIS SCRIPT IS RUNNING ON

    if ($g_frontEnd == 0) { # on backend
        if ($g_scenario eq "ids") {
			$srcPort = $g_IDS_port + 1;
            $src_ts =  CDCInformix->createSimple($g_tgtIDS_TSinstanceName, $srcPort, $srcSrvr);
        }
        elsif ($g_scenario eq "udb") {
			$srcPort = $g_UDB_port + 1;
            $src_ts = CDCDb2->createSimple($g_tgtUDB_TSinstanceName, $srcPort, $srcSrvr);
        }
        elsif ($g_scenario == "soliddb") {
			$srcPort = $g_solidDB_port + 1;
            $src_ts = CDCSolid->createSimple($g_tgtsolidDB_TSinstanceName, $srcPort, $srcSrvr);
        }
    }
    else { # frontend
        if ($g_scenario eq "ids_to_ids") {
			$srcPort = $g_IDS_port;
			$tgtPort = $g_IDS_port + 1;
            $src_ts =  CDCInformix->createSimple($g_srcIDS_TSinstanceName, $srcPort, $srcSrvr);
            $tgt_ts =  CDCInformix->createSimple($g_tgtIDS_TSinstanceName, $tgtPort, $tgtSrvr);

            $srcTable = "informix.${srcTableName}";
            $tgtTable = "informix.${tgtTableName}";
        }
        elsif ($g_scenario eq "ids_to_soliddb") {
			$srcPort = $g_IDS_port;
			$tgtPort = $g_solidDB_port + 1;
            $src_ts = CDCInformix->createSimple($g_srcIDS_TSinstanceName, $srcPort, $srcSrvr);
            $tgt_ts = CDCSolid->createSimple($g_tgtsolidDB_TSinstanceName, $tgtPort, $tgtSrvr);

            $srcTable = "informix.${srcTableName}";        
            $tgtTable = "DBA.${tgtTableName}";
        }
        elsif ($g_scenario eq "soliddb_to_ids") {
			$srcPort = $g_solidDB_port;
			$tgtPort = $g_IDS_port + 1;
            $src_ts = CDCSolid->createSimple($g_srcsolidDB_TSinstanceName, $srcPort, $srcSrvr);
            $tgt_ts = CDCInformix->createSimple($g_tgtIDS_TSinstanceName, $tgtPort, $tgtSrvr);

            $srcTable = "DBA.${srcTableName}";
            $tgtTable = "informix.${tgtTableName}";
        }
        elsif ($g_scenario eq "soliddb_to_soliddb") {
			$srcPort = $g_solidDB_port;
			$tgtPort = $g_solidDB_port + 1;
            $src_ts = CDCSolid->createSimple($g_srcsolidDB_TSinstanceName, $srcPort, $srcSrvr);
            $tgt_ts = CDCSolid->createSimple($g_tgtsolidDB_TSinstanceName, $tgtPort, $tgtSrvr);

            $srcTable = "DBA.${srcTableName}";
            $tgtTable = "DBA.${tgtTableName}";
        }
        elsif ($g_scenario eq "udb_to_soliddb") {
			$srcPort = $g_UDB_port;
			$tgtPort = $g_solidDB_port + 1;
            $src_ts = CDCDb2->createSimple($g_srcUDB_TSinstanceName, $srcPort, $srcSrvr);
            $tgt_ts = CDCSolid->createSimple($g_tgtsolidDB_TSinstanceName, $tgtPort, $tgtSrvr);

            $srcTable = "DB2ADMIN.${srcTableName}";
            $tgtTable = "DBA.${tgtTableName}";
        }
        elsif ($g_scenario eq "soliddb_to_udb") {
			$srcPort = $g_solidDB_port;
			$tgtPort = $g_UDB_port + 1;
            $src_ts = CDCSolid->createSimple($g_srcsolidDB_TSinstanceName, $srcPort, $srcSrvr);
            $tgt_ts = CDCDb2->createSimple($g_tgtUDB_TSinstanceName, $tgtPort, $tgtSrvr);

            $srcTable = "DBA.${srcTableName}";
            $tgtTable = "DB2ADMIN.${tgtTableName}";
        }
        elsif ($g_scenario eq "udb_to_udb") {
			$srcPort = $g_UDB_port;
			$tgtPort = $g_UDB_port + 1;
            $src_ts = CDCDb2->createSimple($g_srcUDB_TSinstanceName, $srcPort, $srcSrvr);
            $tgt_ts = CDCDb2->createSimple($g_tgtUDB_TSinstanceName, $tgtPort, $tgtSrvr);

            $srcTable = "DB2ADMIN.${srcTableName}";
            $tgtTable = "DB2ADMIN.${tgtTableName}";
        }
        else {
            print "Please specify one of the following options\n\t/
                   (sol_to_sol|sol_to_ids|ids_to_ids|ids_to_sol|udb_to_sol|sol_to_udb)\ne.g. informix.pl sol_to_sol\n";
            return;
        }
    }

    # create\start TS
    if ($srcSrvr->dbHost() eq $g_ip) {
        $src_ts->create();
        $src_ts->start();
        sleep(10);
    }

    if ($g_frontEnd == 1) {
        # Create mConsole/Access server instance
        # Access server configuration

        my $accessSrvr = AccessServerConfig->new('accessserver.ini');

        $accessSrvr->initFromConfigFile();
        
        my $accessServer = AccessServer->createFromConfig($accessSrvr);
        my $ip = $accessServer->accessHost();

        if ($ip eq 'localhost') {
            $accessServer->accessHost($g_ip);
        }

        # Create source datastore
		$ds_name = 's_' . $srcPort;
        $ds_src = $accessServer->createDatastoreSimple($ds_name,                       # datastore name
                                                       'Source datastore',             # datastore description
                                                       $src_ts->database()->dbHost(),  # Host
                                                       $src_ts);                       # cdc instance
        # assign source datastore
        $accessServer->source($ds_src);    
        $accessServer->assignDatastoreUser($ds_src);

        # Create source datastore
		$ds_name = 't_' . $tgtPort;
        $ds_tgt = $accessServer->createDatastoreSimple($ds_name,                       # datastore name
                                                       'Target datastore',             # datastore description
                                                       $tgt_ts->database()->dbHost(),  # Server
                                                       $tgt_ts);                       # cdc instance
        
        # assign target datastore
        $accessServer->target($ds_tgt);   
        $accessServer->assignDatastoreUser($ds_tgt);

        switch ($g_test) {
            case "testbed" {
                testBed($ds_src, $ds_tgt, $accessSrvr, $ip);
            }
            case "refresh" {
                $accessServer->createSubscription($subscription);
                $accessServer->addMapping($subscription, $srcTable, $tgtTable);
                $srcSrvr->execSqlStmt("insert into ${srcTable} values (445)");
                $srcSrvr->execSqlStmt("insert into ${srcTable} values (446)");
                $srcSrvr->execSqlStmt("insert into ${srcTable} values (5467)");
                $accessServer->refreshSubscription($ds_src, $subscription);
            }
            case "mirror" {
                $accessServer->createSubscription($subscription);
                $accessServer->addMapping($subscription, $srcTable, $tgtTable);
                $accessServer->startMirroring($subscription);
                sleep(10);
                $srcSrvr->execSqlStmt("insert into ${srcTable} values (445)");
                $srcSrvr->execSqlStmt("insert into ${srcTable} values (446)");
                $srcSrvr->execSqlStmt("insert into ${srcTable} values (5467)");
                sleep(30);                # Allow mirroring to take effect
                $tgtSrvr->execSqlStmt("select * from ${tgtTable}"); # Read target table
                sleep(10);
                # cleanUp
                $accessServer->stopMirroring($subscription);         # Stop mirroring
                sleep(10);
            }
            case "createsub" {
                $accessServer->createSubscription($subscription);
                $accessServer->addMapping($subscription, $srcTable, $tgtTable);
            }
        }
 
        # Delete datastores
        $accessServer->deleteDatastore($ds_tgt);
        $accessServer->deleteDatastore($ds_src);

        # stop and delete cdc instances
        if ($srcSrvr->dbHost() eq $g_ip) {
            $src_ts->stop();
            $src_ts->delete();
            $srcSrvr->stop();
        }

        if ($tgtSrvr->dbHost() eq $g_ip) {
            $tgt_ts->stop();
            $tgt_ts->delete();
            $tgtSrvr->stop();
        }
    }
}

#-----------------------------------------------------------------------
# testBed()
#-----------------------------------------------------------------------
#
# Runs the test for testbed
#
#-----------------------------------------------------------------------

sub testBed()
{
    my ($ds_src, $ds_tgt);
    my $accessSrvr_config;
    my $testbed;
    my $ip;

    ($ds_src, $ds_tgt, $accessSrvr_config, $ip) = @_; # inputs

    # make a testbed object
    #CG $testbed = TestBed->new($accessSrvr_config, $ip, $g_scenario);
	$testbed = TestBed->new($accessSrvr_config);
    
    # Assign source and target datastores
    $testbed->source($ds_src);
    $testbed->target($ds_tgt);

    $testbed->writeEnvironment(); # Write environment.xml file
        
    # Testbed config for run() routine (all these parameters have defaults)
    my $tb_parms = {tb_user => 'cguckian', # user name
                    tb_cmd_opt => '-c',
                    tb_test_single => '', # single test name 'V46_MirrorContinuous_9999''V63_DbClob_0001'
                    tb_test_list => 'SMOKE',
					tb_email => 'cguckian@ie.ibm.com', # email to receive report
                    tb_clean => 1, # Testbed clean up option
                    tb_prefix => 'TB', # Testbed prefix (2-character)
    };

    # run test using parameters specified in config object
	#pause();
    $testbed->run(TestBedConfig->createFromHash($tb_parms));
    $testbed->processResults(); # parse result logs and send email
}

#-----------------------------------------------------------------------
# initialize()
#-----------------------------------------------------------------------
#
# Initialisation
#
#-----------------------------------------------------------------------

sub initialize
{
   my $bits;
   my $os = $Config::Config{'osname'} =~ /^MSWin/i ? 'windows' : 'other';

   my $env_parms_windows = { debug => 1,
                      smtp_server => 'D06ML901',
                      email_admin => 'cguckian@ie.ibm.com',
                      #testbed_head_dir => '/home/udbinst1/workspace/TestBed_HEAD/',
                      testbed_head_dir => 'C:\\TestBed_QA_Approved',
                      java_home => 'C:\\Program Files\\Java\\ibm-java2-sdk-50-win-i386'
   };
    my $env_parms_linux = { debug => 1,
                      smtp_server => 'D06ML901',
                      email_admin => 'cguckian@ie.ibm.com',
                      testbed_head_dir => '/home/informix/TestBed_QA_Approved/',
                      java_home => '/root/bin/ibm-java2-i386-50/bin'
    };
    # Initialise environment
    if ($os eq 'windows') {
        Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms_windows));
    } else {
        Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms_linux));
    }

    Environment->getEnvironment()->javaHome(Environment->getEnvironment()->javaHome(), 1);
    Environment::getEnvironment()->initAccessRootDir();
}

#-----------------------------------------------------------------------
# getDb2Server()
#-----------------------------------------------------------------------
#
# Gets the DB2 server and starts if allowed
#
#-----------------------------------------------------------------------

sub getDb2Server
{
    my $iniFile;
    my $srcTableName;
    my $tgtTableName;
    my $server;
    my $alreadyStarted;

    ($iniFile, $srcTableName,$tgtTableName, $alreadyStarted) = @_; # inputs
    $server = Db2DB->createFromFile($iniFile);

    if ($server->dbHost() eq $g_ip && ${$alreadyStarted} == 0) {
        ${$alreadyStarted} = 1;
        $server->init();
        $server->start();
        
        $server->createDatabase($server->dbName());
        
        $server->createSchema($server->dbSchema());
        $server->execSqlStmt("create table ${\$server->dbSchema()}.${srcTableName} (number integer)");
        $server->execSqlStmt("create table ${\$server->dbSchema()}.${tgtTableName} (number integer)");
    }

    return $server;
}

#-----------------------------------------------------------------------
# getInformixServer()
#-----------------------------------------------------------------------
#
# Gets the IDS server and starts if allowed
#
#-----------------------------------------------------------------------

sub getInformixServer
{
    my $srcTableName;
    my $tgtTableName;
    my $server;
    my $iniFile;
    my $alreadyStarted;

    ($iniFile, $srcTableName,$tgtTableName, $alreadyStarted) = @_; # inputs
    $server = InformixDB->createFromFile($iniFile);

    if ($server->dbHost() eq $g_ip && ${$alreadyStarted} == 0) {
        ${$alreadyStarted} = 1;
        $server->start();
        $server->createDatabase($server->dbName());
        $server->execSqlStmt("create schema authorization ${\$server->dbSchema()}");
        $server->execSqlStmt("create table ${srcTableName} (number integer, primary key (number))");
        $server->execSqlStmt("create table ${tgtTableName} (number integer, primary key (number))");
        $server->setDatabase($server->dbName());
    }

    return $server;
}

#-----------------------------------------------------------------------
# getsolidDBServer()
#-----------------------------------------------------------------------
#
# Gets the solidDB server and starts if allowed
#
#-----------------------------------------------------------------------


sub getsolidDBServer
{
    my $solidIniFile;
    my $srcTable;
    my $tgtTable;
    my $savecwd = Cwd::getcwd();
    my $server;
    my $alreadyStarted;

    ($solidIniFile, $srcTable, $tgtTable, $alreadyStarted) = @_; # inputs
    $server = SolidDB->createFromFile($solidIniFile);
   
    if ($server->dbHost() eq $g_ip && ${$alreadyStarted} == 0) {
        ${$alreadyStarted} = 1;
        $server->start();
        sleep(10);
        $server->execSqlStmt("create table ${srcTable} (number integer, primary key (number))");
        $server->execSqlStmt("create table ${tgtTable} (number integer, primary key (number))");
    }
    chdir($savecwd);
    return $server;
}

#-----------------------------------------------------------------------
# informixCDCTest()
#-----------------------------------------------------------------------
#
# Not used
#-----------------------------------------------------------------------

sub informixCDCTest
{   
    my $server;
    my $install_to;
    my $install_from;
    my ($cdcInstance1, $cdcInstance2, $cdcInstance3);
    my $cdc_cfg;
    my $bits;

    ($server, $install_to, $install_from) = @_; 

    my $cdc_params1 = {
        ts_name => 'cdc_from_hash',
        ts_port => 10302,
    };
    my $config_ids;
    my $cdc_params2 = {
        ts_name => 'cdc_cfg',
        ts_port => '10303',
    };

    #CDC->uninstall($install_to);
    #sleep(30);
    unless (-d $install_to) {
        CDCInformix->install($install_to, $install_from);
    }
    
    # 3 ways to create a CDC instance
    # Method 1 - simple way
    $cdcInstance1 = CDCInformix->createSimple('simple_cdc', '10301', $server);
    
    # Method 2 - from a parameter
    $cdc_cfg = cdcConfig->createFromHash($cdc_params1);
    $cdcInstance2 = CDCInformix->createFromConfig($cdc_cfg, $server);
    
    #Method 3 - from a file
    $config_ids = cdcConfig->new('informix.ini');
    $config_ids->initFromConfigFile();
    
    $cdcInstance3 = CDCInformix->createFromConfig($config_ids, $server);

    # create real ones
    $cdcInstance1->create();
    $cdcInstance1->start();

    $cdcInstance2->create();
    $cdcInstance2->start();

    $cdcInstance3->create();
    CDC->list($install_to);
    $cdcInstance3->start();
    
    CDC->list($install_to);
    
    $cdcInstance1->stop();
    $cdcInstance2->stop();
    $cdcInstance3->stop();
 
    $cdcInstance1->delete();
    $cdcInstance2->delete();
    $cdcInstance3->delete();
}

sub pause
{
    my $msg = shift || "Press <enter> to continue\n";
    my $inp;
    print $msg;
    $inp = <STDIN>;
}