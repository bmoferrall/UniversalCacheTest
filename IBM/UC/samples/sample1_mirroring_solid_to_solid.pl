#!/usr/bin/perl

use strict;

use IBM::UC::Environment;
use IBM::UC::Database::SolidDB;
use IBM::UC::CDC::CDCSolid;
use IBM::UC::AccessServer::AccessServer;


&mirrorSolidToSolid();


#-----------------------------------------------------------------------
# mirrorSolidToSolid()
#-----------------------------------------------------------------------
#
# Create subscription and mirror between Solid source and Solid target
#
# This routine creates and starts two database instances of Solid (source
# and target), creates and starts two CDC instances of Solid (source and 
# target), creates source and target datastores, creates a subscription
# from source/publisher to target/subscriber, creates a mapping from
# a table in the source database ('SRC') to a table ('TGT') in the target
# database, initiates replication, inserts some data into the source table,
# pauses, then displays the contents of the target table (select * from TGT)
# to verify that mirroring has taken effect
#-----------------------------------------------------------------------
sub mirrorSolidToSolid
{
	my ($envParamsLinux, $envParamsWindows); # Environment parameters
	my ($dbParamsSrc, $dbParamsTgt); # Source and target database parameters
	my ($dbSrc, $dbTgt); # Source and target database instances
	my ($cdcSrc, $cdcTgt); # Source and target CDC instances
	my ($asCfg); # Access server configuration
	my ($mConsole); # Access Server/Management console instance
	my ($dsSrc, $dsTgt); # Source and target datastore instances
	my ($tblNameSrc, $tblNameTgt); # src and target table names
	my $sub = 'subname'; # Default subscription name
	my $ps; # Path separator
	my $es; # Environment variable separator
	my $os = $Config::Config{'osname'} =~ /^MSWin/i ? 'windows' : 'other';
	my $home = $os eq 'windows' ? '' : $ENV{'HOME'}; # Home directory

eval { # trap errors so we can clean up before exiting

#------------------------------------------------------------------------------------------------
# Initialise Environment
#------------------------------------------------------------------------------------------------

	$envParamsLinux = { # Linux environment setup
		# Location of Solid home
		solid_root_dir => $home . "/soliddb-6.5",
		# Location of solid licence file
		solid_licence_file => $home . "/soliddb-6.5/solid.lic", 
		# Location of Transformation Server for Solid
		cdc_solid_root_dir => $home . "/Transformation Server for solidDB/",
		# Location of access server
	    access_server_root_dir => $home . "/DataMirror/Transformation Server Access Control/",
        java_home => $home . "/ibm-java2-i386-50/", # Java 5 home directory
	};
	$envParamsWindows = { # Windows environment setup
		# Location of Solid home
		solid_root_dir => "C:\\Program Files\\IBM\\solidDB\\solidDB6.5\\",
		# Location of solid licence file
		solid_licence_file => Cwd::getcwd() . "\\solid.lic", 
		# Location of Transformation Server for Solid
		cdc_solid_root_dir => "C:\\Program Files\\DataMirror\\Transformation Server for solidDB\\",
		# Location of access server
	    access_server_root_dir => "C:\\Program Files\\DataMirror\\Transformation Server Access Control\\",
        java_home => "C:\\Program Files\\Java\\ibm-java2-sdk-50-win-i386\\", # Java 5 home directory
	};
	# Initialise environment
	if ($os eq 'windows') {
		Environment->createFromConfig(EnvironmentConfig->createFromHash($envParamsWindows));
	} else {
		Environment->createFromConfig(EnvironmentConfig->createFromHash($envParamsLinux));
	}
	$ps = Environment->getEnvironment()->getPathSeparator();
	$es = Environment->getEnvironment()->getEnvSeparator();
    $ENV{'JAVA_HOME'} = Environment::getEnvironment()->javaHome();
	# Add java 5 compiler location to Environment PATH
	$ENV{'PATH'} = $ENV{'JAVA_HOME'} . 'bin' . $es . $ENV{'PATH'};
	
#------------------------------------------------------------------------------------------------
# Initialise and start source database
#------------------------------------------------------------------------------------------------

	# create and start source database
	$dbParamsSrc = { 
		db_port => '2315',  # Port  number of source database
		db_dir => $home . '/solid/sol_src', # Location of source database
	};
	$dbSrc = SolidDB->createFromConfig(DatabaseConfig->createFromHash($dbParamsSrc));
	$dbSrc->start(); # Start source Solid instance
	
#------------------------------------------------------------------------------------------------
# Initialise and start target database
#------------------------------------------------------------------------------------------------

	# create and start target database
	$dbParamsTgt = { 
		db_port => '2316',  # Port number of target database
		db_dir => $home . '/solid/sol_tgt', # Location of target database
	};
	$dbTgt = SolidDB->createFromConfig(DatabaseConfig->createFromHash($dbParamsTgt));
	$dbTgt->start(); # Start target Solid instance
	
#------------------------------------------------------------------------------------------------
# Create source and target tables
#------------------------------------------------------------------------------------------------

	# Register source and target table names 
	$dbSrc->dbTableName('SRC');
	$dbTgt->dbTableName('TGT');

	# Store full table names (including schema name) for reuse
	$tblNameSrc = $dbSrc->dbSchema() . '.' . $dbSrc->dbTableName();
	$tblNameTgt = $dbTgt->dbSchema() . '.' . $dbTgt->dbTableName();
	
	# Create source table 'SRC'
	$dbSrc->execSqlStmt("create table $tblNameSrc (id integer, name char(50))");
	# Create target table 'TGT' with same structure as 'SRC'
	$dbTgt->execSqlStmt("create table $tblNameTgt (id integer, name char(50))");
	
#------------------------------------------------------------------------------------------------
# Create and start source and target CDC instances
#------------------------------------------------------------------------------------------------
	
	# Initialise source CDC
	$cdcSrc = CDCSolid->createSimple('solsrc_ts',11101,$dbSrc);

	# Initialise target CDC
	$cdcTgt = CDCSolid->createSimple('soltgt_ts',11102,$dbTgt);

	$cdcSrc->create(); # Create source CDC instance
	$cdcTgt->create(); # Create target CDC instance
	$cdcSrc->start(); # Start source CDC instance
	$cdcTgt->start(); # Start target CDC instance

	pause("\nPlease ensure that Access Server is running in the background\nPress <enter> when ready...\n");	
	
#------------------------------------------------------------------------------------------------
# Access Server configuration and datastore creation
#------------------------------------------------------------------------------------------------

	# Access server configuration
	# Ensure values match those of running access server
	$asCfg = {ac_host => 'localhost',	# Access server host
			 	  ac_port => '10101',	# Access server port
				  ac_user => 'Admin',	# Access server user
				  ac_pass => 'admin123'};	# Access server password

	# Initialise mConsole/Access server instance
	$mConsole = AccessServer->createFromConfig(AccessServerConfig->createFromHash($asCfg));

	# Create source datastore
	$dsSrc = $mConsole->createDatastoreSimple(
		'solsrc_ds',		# datastore name
		'Source datastore',	# datastore description
		$cdcSrc->instanceHost(),		# datastore host
		$cdcSrc,		# source cdc instance
	);
	# Create target datastore
	$dsTgt = $mConsole->createDatastoreSimple(
		'soltgt_ds',		# datastore name
		'Target datastore',	# datastore description
		$cdcTgt->instanceHost(),		# datastore host
		$cdcTgt,		# cdc instance
	);
	$mConsole->source($dsSrc);	# assign source datastore
	$mConsole->target($dsTgt);	# assign target datastore
	
	# Assign datastore user to source and target respectively
	$mConsole->assignDatastoreUser($dsSrc);
	$mConsole->assignDatastoreUser($dsTgt);
	
#------------------------------------------------------------------------------------------------
# Create subscription and mapping from source to target, start mirroring
#------------------------------------------------------------------------------------------------

	# Create subscription between source and target datastores
	$mConsole->createSubscription($sub);
	# Add mapping from source table to target table
	$mConsole->addMapping($sub,$tblNameSrc,$tblNameTgt);
	# Start mirroring
	$mConsole->startMirroring($sub);
	
#------------------------------------------------------------------------------------------------
# Modify source table
#------------------------------------------------------------------------------------------------

	# Insert some rows into the source table
	$dbSrc->execSqlStmt("insert into $tblNameSrc values (1,'One')");
	$dbSrc->execSqlStmt("insert into $tblNameSrc values (2,'Two')");
	$dbSrc->execSqlStmt("insert into $tblNameSrc values (3,'Three')");

	# Pause to allow mirroring to take effect
	sleep(10);
	
#------------------------------------------------------------------------------------------------
# Display contents of target table to show mirroring has taken place
#------------------------------------------------------------------------------------------------

	# Read contents of target table
	$dbTgt->execSqlStmt("select * from $tblNameTgt");
	# Display results of sql command
	displayResults($dbTgt->dbDir() . $dbTgt->dbSqlOutputFile());

	pause("\nPress <enter> to start cleanup...\n");

};

# Error thrown in eval {...}
if ($@) { Environment::logf("\n\nErrors found: $@\n"); }

#------------------------------------------------------------------------------------------------
# Clean up
#------------------------------------------------------------------------------------------------

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


