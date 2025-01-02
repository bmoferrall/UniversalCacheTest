#!/usr/bin/perl

use strict;

use IBM::UC::Environment;
use IBM::UC::Database::SolidDB;
use IBM::UC::Database::RemoteDB;
use IBM::UC::CDC::CDCSolid;
use IBM::UC::CDC::CDCRemote;
use IBM::UC::AccessServer::AccessServer;


&mirrorSolidToDB2();


#-----------------------------------------------------------------------
# mirrorSolidToDB2()
#-----------------------------------------------------------------------
#
# Create subscription and mirror between Solid source and DB2 target
#
# This example demonstrates mirroring between a front-end SolidDB database
# on a local machine and a back-end DB2 database on a remote machine.
# This routine creates and starts a database instance of Solid (source),
# creates a table 'SRC' in this source database,
# creates a virtual representation of the remote database using RemoteDB,
# (the remote database will have a table called 'TGT' already created),
# creates and starts a CDC instance of Solid, creates a virtual
# representation of the remote CDC instance using CDCRemote, 
# creates source and target datastores, 
# creates a subscription from source/publisher to target/subscriber, 
# creates a mapping from a table in the source database ('SRC') to a table 
# ('TGT') in the target database, initiates replication, 
# inserts some data into the source table, finally pauses for the user to verify
# that the data has been copied to the target
#-----------------------------------------------------------------------
sub mirrorSolidToDB2
{
	my ($envParamsLinux, $envParamsWindows); # Environment parameters
	my ($dbParamsSrc); # Source database parameters
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
		# Location of Transformation Server for DB2
		cdc_db2_root_dir => $home . "/Transformation Server for UDB/",
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
		# Location of Transformation Server for DB2
		cdc_db2_root_dir => "C:\\Program Files\\DataMirror\\Transformation Server for UDB\\",
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
		db_port => '2315',  # Port number of source database
		db_dir => $home . "/solid/sol_src" # Location of source database
	};
	$dbSrc = SolidDB->createFromConfig(DatabaseConfig->createFromHash($dbParamsSrc));
	$dbSrc->start(); # Start source Solid instance

#------------------------------------------------------------------------------------------------
# Create representation of target database instance on remote machine.
# We are assuming here that a DB2 database with the specified name exists on the
# remote machine and has been started, that a schema with the specififed name
# has been created, that DB2 is listening on the specified port number,
# and that the user name/password used here has sufficient rights
#------------------------------------------------------------------------------------------------
	
	$dbTgt = RemoteDB->createSimple('DB2', # Type of database
									'TEST', # Database name (must exist)
									'localhost', # Host name ('localhost' if on same machine as TS)
									'db2admin', # User name (must have sufficient rights)
									'db2admin', # User password
									'db2schema', # Database schema (must exist)
									50000); # Database Port number

#------------------------------------------------------------------------------------------------
# Create source table
#------------------------------------------------------------------------------------------------

	# Register source and target table names 
	$dbSrc->dbTableName('SRC');
	$dbTgt->dbTableName('TGT');

	# Store full table names (including schema name) for reuse
	$tblNameSrc = $dbSrc->dbSchema() . '.' . $dbSrc->dbTableName();
	$tblNameTgt = $dbTgt->dbSchema() . '.' . $dbTgt->dbTableName();

	# Create source table 'SRC'	(target table 'TGT' will be created if it doesn't exist)
	$dbSrc->execSqlStmt("create table $tblNameSrc (id integer, name char(50))");
	
#------------------------------------------------------------------------------------------------
# Create and start source CDC instance
# Create virtual representation of target CDC instance. Here we assume
# that a CDC instance has been created and started on a remote machine
# (set host property to 'localhost' if target instance is on the same
# machine as the source instance)
#------------------------------------------------------------------------------------------------
	
	# Initialise source CDC
	$cdcSrc = CDCSolid->createSimple('solsrc_ts',11101,$dbSrc);

	# Initialise target CDC
	$cdcTgt = CDCRemote->createSimple('db2tgt_ts',11102,'localhost',$dbTgt);

	$cdcSrc->create(); # Create source CDC instance
	$cdcSrc->start(); # Start source CDC instance

	pause("\nPlease ensure that Access Server is running in the background\nPress <enter> when ready...\n");	
	
#------------------------------------------------------------------------------------------------
# Access Server configuration and datastore creation
# We are assuming here that access server is running on the same machine as the source/publisher
# Solid instance
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
		$cdcSrc->instanceHost(), # host name/ip of local Solid cdc instance
		$cdcSrc,		# source cdc instance
	);
	# Create target datastore
	$dsTgt = $mConsole->createDatastoreSimple(
		'db2tgt_ds',		# datastore name
		'Target datastore',	# datastore description
		$cdcTgt->instanceHost(), # host name/ip of remote DB2 cdc instance
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
# Check contents of target table to verify mirroring has taken place
#------------------------------------------------------------------------------------------------

	pause("\nCheck contents of table \"$tblNameTgt\" in target database to verify mirroring has taken place\n" .
	      "When ready, press <enter> to start cleanup...\n");

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
	# stop and delete source cdc instance
	if (defined($cdcSrc)) {
		$cdcSrc->stop();
		$cdcSrc->delete();
	}

	# shut down database
	$dbSrc->stop() if (defined($dbSrc));
}



sub pause
{
	my $msg = shift || "Press <enter> to continue\n";
	my $inp;
	print $msg;
	$inp = <STDIN>;
}


