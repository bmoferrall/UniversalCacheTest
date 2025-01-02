########################################################################
# 
# File   :  Db2dDB.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# Db2dDB.pm is a sub-class of Database.pm.
# It provides routines to create and interact with a Db2DB database
# It can also be used to connect with an existing Db2dDB database 
# (either remote or local) and interact with it
# 
########################################################################
package Db2DB;

use strict;

use IBM::UC::Database;
use File::Path;
use File::Copy;
use Cwd;
use UNIVERSAL qw(isa);

our @ISA = qw(Database); # database super class


#-------------------------------------------------------------------------------------
# $ob = Db2DB->createSimple([$db_dir,$db_name,$db_user,$db_pass,$db_schema])
#-------------------------------------------------------------------------------------
#
# create Db2 object using fixed order parameters
# All parameters are optional, but those present must be in the correct order
# e.g. Db2DB->createSimple('/home/db2inst1/db2inst1/NODE0000/TEST','TEST','db2admin')
#--------------------------------------------------------------------------------------
sub createSimple
{
	my $class = shift;
	my $dbdir = shift; # database directory
	my $dbname = shift; # database name
	my $dbuser = shift; # database user
	my $dbpass = shift; # database password
	my $dbschema = shift; # database schema

	my $self = $class->SUPER::new();

	bless $self, $class;

	$self->init(); # set defaults

	# override defaults with parameters passed
	if (defined($dbschema)) { $self->dbSchema($dbschema); }
	if (defined($dbpass)) { $self->dbPass($dbpass); }
	if (defined($dbuser)) { $self->dbUser($dbuser); }
	if (defined($dbname)) { $self->dbName($dbname); }
	if (defined($dbdir)) { $self->dbDir($dbdir); }

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");

	# Make sure dbDir has a full path and ends with path separator
	$self->setDbDirPath($self->dbDir());

	# DB2 uppercases database name and directory, so have to make sure parameters match this
	$self->dbName(uc($self->dbName()));
	
	return $self;
}


#------------------------------------------------------------------------------------
# $ob = Db2DB->createComplex($refParam)
#------------------------------------------------------------------------------------
#
# create Db2 object from variable parameters
# See POD for allowed parameter names and their default values
# e.g. Db2DB->createComplex({db_name => 'test', db_schema => 'schema1'})
#
#------------------------------------------------------------------------------------
sub createComplex
{
	my $class = shift;
	my $refParam = shift; # hash ref with name/value pairs

	my $self = $class->SUPER::new();

	bless $self, $class;

	$self->init(); # set defaults

	if (!defined($refParam) or (ref($refParam) ne 'HASH')) {
		Environment::fatal("Db2DB::createComplex: expecting hash reference as parameter\nExiting...\n");
	} else {
		# override defaults with parameters passed
		$self->getConfig()->initFromConfig($refParam);
	}

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");

	# Make sure dbDir has a full path and ends with path separator
	$self->setDbDirPath($self->dbDir());

	# DB2 uppercases database name and directory, so have to make sure parameters match this
	$self->dbName(uc($self->dbName()));
	
	return $self;
}



#-----------------------------------------------------------------------
# $ob = Db2DB->createFromConfig($config)
#-----------------------------------------------------------------------
# 
# Create DB2 object from existing DatabaseConfig object which is essentially a hash
# of parameter name/value pairs.
# See POD for allowed parameter names and their default values
# e.g.
# $config_values = { db_name => 'test', db_dir => '/dir/test', db_user => 'user', 
#					 db_pass => 'pass', db_schema_name => 'schema1'};
# DB2->createFromConfig(DatabaseConfig->createFromHash($config_values));
# 
#-----------------------------------------------------------------------
sub createFromConfig
{
	my $class = shift;
	my $config = shift;
	my $self = $class->SUPER::new();

	bless $self, $class;

	$self->init();	

	# override defaults with parameters passed
	if (ref($config) eq 'DatabaseConfig') {
		$self->getConfig()->initFromConfig($config->getParams());	
	} else {
		Environment::fatal("Db2DB::createFromConfig: config parameter not of type \"DatabaseConfig\"\n");
	}

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");

	# Make sure dbDir has a full path and ends with path separator
	$self->setDbDirPath($self->dbDir());

	# DB2 uppercases database name and directory, so have to make sure parameters match this
	$self->dbName(uc($self->dbName()));
	
	return $self;
}



#-----------------------------------------------------------------------
# $ob = Db2DB->createFromFile($ini)
#-----------------------------------------------------------------------
# 
# Create Db2 object using configuration info from ini file (in the form
# of name=value records).
# See POD for allowed parameter names and format of the ini file
# e.g. Db2DB->createFromFile('instance1.ini')
#
#-----------------------------------------------------------------------
sub createFromFile
{
	my $class = shift;
	my $ini = shift;
	my $self = {};

	# Check that param was passed and that file exists 
	if (defined($ini) && -f $ini) { # Call super class constructor
		$self = $class->SUPER::new($ini);
	} else {
		Environment::fatal("Db2DB::createFromFile needs valid *.ini file as input\nExiting...\n");
	}

	bless $self, $class;

	$self->init();	
	
	# Check that config is fully initialised
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");

	# Make sure dbDir has a full path and ends with path separator
	$self->setDbDirPath($self->dbDir());

	# DB2 uppercases database name and directory, so have to make sure parameters match this
	$self->dbName(uc($self->dbName()));

	return $self;
}


#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise Db2DB instance, including asssigning default values and calling
# super class version of init()
#
#-----------------------------------------------------------------------
sub init
{
	my $self = shift;
	my $ps = $self->getEnv()->getPathSeparator();
	my $inst = $ENV{'DB2INSTANCE'} || 'DB2INST1'; # $ENV{'DB2INSTANCE'} returns undef if value is not set
	my $db2_path = ($self->getEnv()->getOSName() eq 'windows') ? # Default db2 path 
					$ps.$inst.$ps.'NODE0000'.$ps : # windows
					$ENV{'HOME'}.$ps.$inst.$ps.'NODE0000'.$ps; # linux
				                	    	
	# Make sure we only initialise once,
	#    in case a user explicitly calls what is intended to be a private method
	if (!$self->initialised()) {
		# Initialise some config parameters to default values
		$self->getConfig()->initFromConfig({db_inst => $inst,
											db_dir => $db2_path . 'TEST',
											db_dir_clean => 'no',
											db_host => 'localhost',
											db_port => 50000,
											db_name => 'TEST',
					  						db_user => 'db2admin',
					  						db_pass => 'db2admin',
					  						db_schema => 'db2admin',
											db_sql_output => 'sqloutput.log'});

		# invoke super class' initialiser
		$self->SUPER::init();	
		$self->initialised(1);
	}
}



#-----------------------------------------------------------------------
# $ob->createStorage()
#-----------------------------------------------------------------------
#
# Database directory should already exist unless
#    user has chosen to create one from scratch
# Optionally deletes existing storage before re-creating
#
#-----------------------------------------------------------------------
sub createStorage
{
	my $self = shift;
	my $cwd = $self->getEnv()->getStartDir();

	# Delete database if it exists and user has chosen to remove it
	# ***Moved this to createDatabase()***
#	if (lc($self->dbDirClean()) eq 'yes') {
#		$self->cleanStorage();
#	}
}


#-----------------------------------------------------------------------
# $ob->cleanStorage()
#-----------------------------------------------------------------------
#
# Delete existing database storage
#
#-----------------------------------------------------------------------
sub cleanStorage
{
	my $self = shift;
	my $command;

#	if (-d $self->dbDir()) {
#		Environment::logf(">> Dropping database \"${\$self->dbName()}\"...\n");
#		system('db2start') if (!$self->db2Active());
#		$command = "db2 drop database " . $self->dbName();
#		Environment::logf(">> COMMAND: $command\n");
#		system($command);
#	}
}


#-----------------------------------------------------------------------
# $ob->start()
#-----------------------------------------------------------------------
#
# Calls createStorage(), optionally creates a new database instance,
# optionally creates a new Db2 database, and starts db2 database 
# manager
#
#-----------------------------------------------------------------------
sub start
{
	my $self = shift;

	$self->createStorage();
	
	$self->createInstance(); # Create instance if it doesn't exist

	# start database manager
	if (!$self->db2Active()) {
		Environment::logf("\n>> Starting db2 for \"${\$self->instanceName()}\"...\n");
		system('db2start'); 
		Environment::logf(">> Done.\n");
	}
}


#-----------------------------------------------------------------------
# $ob->stop()
#-----------------------------------------------------------------------
#
# Shuts down the db2 database manager
# Optionally drop database (only if it was created here)
# Delete instance if it was created here
#
#-----------------------------------------------------------------------
sub stop
{
	my $self = shift;
	my $command;
		
	# shut down database manager
        # If this is target and source was DB2 then manager will have been shut down, hence check
	if ($self->db2Active()) {
		Environment::logf("\n>> Disconnecting from active database and shutting down db2...\n");
		system('db2 terminate');
		system('db2stop');
		Environment::logf(">> Done.\n");
	}
	$self->deleteInstance(); # delete instance if it was created here
}


#-----------------------------------------------------------------------
# $ob->createInstance()
#-----------------------------------------------------------------------
#
# Creates database instance specified by user if it doesn't exist
#-----------------------------------------------------------------------
sub createInstance
{
	my $self = shift;
	my $db2Inst = $ENV{'DB2INSTANCE'};

	if (!defined($db2Inst) || (lc($db2Inst) ne lc($self->instanceName()))) {
		Environment::logf(">> Creating db2 instance \"${\$self->instanceName()}\"\n");
		$self->instanceCreated(1);
		system('db2icrt ' . $self->instanceName()); # command not on linux installation
	}
}


#-----------------------------------------------------------------------
# $ob->deleteInstance()
#-----------------------------------------------------------------------
#
# Deletes database instance if it was created here
#-----------------------------------------------------------------------
sub deleteInstance
{
	my $self = shift;
	my $db2Inst = $ENV{'DB2INSTANCE'};

	if ($self->instanceCreated() && (lc($db2Inst) eq lc($self->instanceName()))) {
		Environment::logf(">> Deleting db2 instance \"${\$self->instanceName()}\"\n");
		system('db2idrop ' . $self->instanceName()); # command not on linux installation
		$self->instanceCreated(0);
	}
}


#-----------------------------------------------------------------------
# $created = $ob->instanceCreated()
#-----------------------------------------------------------------------
#
# Gets/sets flag indicating whether an instance was created here
# Also changes value of environmental variable 'DB2INSTANCE' to
#    new name and backs up original value for later restoration
#
#-----------------------------------------------------------------------
sub instanceCreated
{
	my ($self,$created) = @_;

	if (defined($created)) {
		$self->{'INSTCREATED'} = $created;
		if ($created == 1) {
			Environment::logf(">> Backing up $ENV{DB2INSTANCE} and changing temporarily...\n");
			$ENV{'DB2INSTANCE_ORIG'} = $ENV{'DB2INSTANCE'};
			$ENV{'DB2INSTANCE'} = $self->instanceName();
		} else {
			Environment::logf(">> Restoring original value of ENV{DB2INSTANCE}...\n");
			$ENV{'DB2INSTANCE'} = $ENV{'DB2INSTANCE_ORIG'};
		}
	}
	return defined($self->{'INSTCREATED'}) && $self->{'INSTCREATED'};
}


#-----------------------------------------------------------------------
# $ob->createDatabase([$dbname])
#-----------------------------------------------------------------------
#
# Creates database specified by user, where:
# $dbname=name of database to create (optional)
# If no name is specified the name specified during object's creation is
# used
# Also connects to database
#
#-----------------------------------------------------------------------
sub createDatabase
{
	my $self = shift;
	my $dbname = shift;
	my $ps = $self->getEnv()->getPathSeparator();
	my $bkupdir;

	if (defined($dbname)) {	
		$self->dbName($dbname);
		# Build database directory from base directory and database name
		$self->dbDir($self->dbBaseDir() . uc($dbname) . $ps);
	}
	$bkupdir = $self->dbDir() . "..${ps}" . $self->dbName() . '_BKUP';

	$self->deleteDatabase($self->dbName()); # Delete database first if it exists

	if (!$self->db2Active()) { system('db2start'); } # shouldn't need to do this
	Environment::logf(">> Creating database \"${\$self->dbName()}\"\n");
	system("db2 create database ${\$self->dbName()}") and
		Environment::fatal("Db2DB::createDatabase: Failed to create database \"${\$self->dbName()}\"\n");
	system("db2 update db cfg for ${\$self->dbName()} using logindexbuild on");
	system("db2 update db cfg for ${\$self->dbName()} using indexrec restart");
	system("db2 update db cfg for ${\$self->dbName()} using logretain on");
	mkpath($bkupdir);
	system("db2 backup db ${\$self->dbName()} to $bkupdir");
	system("db2 activate database ${\$self->dbName()}");
	system("db2 connect to ${\$self->dbName()}");
	system("db2 grant dbadm, createtab, bindadd, connect, create_not_fenced_routine, implicit_schema, load, create_external_routine, quiesce_connect, secadm on database to user ${\$self->dbUser()}");

	# TestBed testcases need the following commands
	system('db2 create bufferpool bp32 immediate pagesize 32 K');
	system('db2 create user temporary tablespace tbsp32K pagesize 32 K managed by automatic storage bufferpool bp32');
}



#-----------------------------------------------------------------------
# $ob->connectToDatabase([$dbname])
#-----------------------------------------------------------------------
#
# Connect to database
# $dbname=name of database to create (optional)
# If no name is specified the name specified during object's creation is
# used
# Method first disconnects from active database (if there is one)
#
#-----------------------------------------------------------------------
sub connectToDatabase
{
	my $self = shift;
	my $dbname = shift;
	my $db_curr = $self->dbName();
	my $ps = $self->getEnv()->getPathSeparator();

	if (defined($dbname)) {	
		$self->dbName($dbname);
		# Build database directory from base directory and database name
		$self->dbDir($self->dbBaseDir() . uc($dbname) . $ps);
	}
	Environment::logf(">> Connecting to database \"${\$self->dbName()}\"\n");
	system("db2 connect reset > null");
	system("db2 deactivate database $db_curr > null");
	system("db2 activate database ${\$self->dbName()} > null");
	system("db2 connect to ${\$self->dbName()}");
	unlink('null');
}



#-----------------------------------------------------------------------
# $ob->deleteDatabase([$dbname])
#-----------------------------------------------------------------------
#
# Delete existing database before re-creating
# $dbname=name of database to delete (optional)
# If no name is specified the name specified during object's creation is
# used
#
#-----------------------------------------------------------------------
sub deleteDatabase
{
	my $self = shift;
	my $dbname = shift;
	
	$dbname = $self->dbName() if !defined($dbname);

	if (-d $self->dbDir()) {
		Environment::logf(">> Deleting database \"$dbname\"\n");
		if (!$self->db2Active()) { system('db2start'); } # shouldn't need to do this
		system("db2 connect reset > null");
		system("db2 deactivate database $dbname > null");
		system("db2 drop database $dbname");
		unlink('null');
	} else {
		Environment::logf(">> Db2DB::deleteDatabase: Database \"$dbname\" not deleted as path \"${\$self->dbDir()}\" doesn't exist\n");
	} 
}


#-----------------------------------------------------------------------
# $ob->createSchema([$name])
#-----------------------------------------------------------------------
#
# Creates schema specified by user, where:
# $name=name of schema to create (optional)
# If no name is specified the name specified during object's creation is
# used
# Assumes that a connection to the database exists (connectToDatabase)
#
#-----------------------------------------------------------------------
sub createSchema
{
	my $self = shift;
	my $schema = shift;

	$self->dbSchema($schema) if (defined($schema));

	Environment::logf(">> Creating schema \"${\$self->dbSchema()}\"\n");
	system("db2 create schema ${\$self->dbSchema()} authorization ${\$self->dbUser()}");
}



#-----------------------------------------------------------------------
# $ob->deleteSchema([$name])
#-----------------------------------------------------------------------
#
# Deletes schema specified by user, where:
# $name=name of schema to delete (optional)
# If no name is specified the name specified during object's creation is
# used
# Assumes that a connection to the database exists (connectToDatabase)
#
#-----------------------------------------------------------------------
sub deleteSchema
{
	my $self = shift;
	my $schema = shift;

	$self->dbSchema($schema) if (defined($schema));

	Environment::logf(">> Delete schema \"${\$self->dbSchema()}\"\n");
	system("db2 drop schema ${\$self->dbSchema()}");
}


#--------------------------------------------------------------------------
# $ob->execSql($input)
#--------------------------------------------------------------------------
# Execute batch sql statements from a file
# $input is the name of an sql file (if no path is specified it is assumed
# to be in the start directory).
# e.g.
# $ob->execSql('/home/user/db2/create_src.sql')
#---------------------------------------------------------------------------
sub execSql
{
	my $self = shift;
	my $sql = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $ps = $self->getEnv()->getPathSeparator();
	my $dir = $self->dbDir() . '..';
	# Suppress sql output (gets redirected to a file instead)
	my $null = ($self->getEnv()->getOSName() eq 'windows') ? ' > null' : ' > /dev/null';

	if (!defined($sql)) {
		Environment::fatal("Db2DB::execSql: No parameter specified (filename)\n");
	} else {
		# If path not supplied assume start directory and copy to db directory
		require File::Basename;
		my ($f,$p) = File::Basename::fileparse($sql);
		$p = length($p)>2 ? $p : $self->getEnv()->getStartDir();
		File::Copy::cp($p.$f, $dir.$ps.$f) or Environment::fatal("Db2DB::ExecSql: Copy failed ($!)\n");
		$sql = $f;
	}
	chdir($dir);

	unless (-f $sql) { Environment::fatal("Db2DB::execSql: Cannot find sql input \"$dir$ps$sql\"\nExiting...\n"); }
	$self->prepareSqlFile($sql);
	$command = "db2 -tf " . $sql . " -z " . $self->dbSqlOutputFile() . $null;
	Environment::logf("\n>> COMMAND: $command\n");
	system($command) and Environment::logf("***Error occurred in Db2DB::execSql***\n");
	unlink('null'); # null used to suppress output
	Environment::logf(">> Done. Check $dir${ps}${\$self->dbSqlOutputFile()} for output\n");

	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->execSqlStmt($sql)
#-----------------------------------------------------------------------
#
# Execute single sql statements against the database
# e.g.
# $sql = 'select * from src';
# $ob->execSqlStmt($sql);
#
#-----------------------------------------------------------------------
sub execSqlStmt
{
	my $self = shift;
	my $sqlstr = shift;
	my $savecwd = Cwd::getcwd();
	my $command;
	my $dir = $self->dbDir() . '..';
	my $ps = $self->getEnv()->getPathSeparator();
	my $null = ($self->getEnv()->getOSName() eq 'windows') ? ' > null' : ' > /dev/null';

	chdir($dir);

	if (defined($sqlstr)) { # execute sql string specified by user
		# No option to execute sql statement as string, so have to write to a temp. file
		my $fsql = '_sql_input.sql';
		open(SQL,'>',$fsql) or Environment::fatal("Db2DB::execSqlStmt: Cannot open $fsql\n");
		# Appears we need to wrap sql statement with 'connect to' and 'connect reset' commands
		print SQL "connect to " . $self->dbName() . ";\n";
		print SQL $sqlstr . ";\n";
		print SQL "connect reset;\n";
		close(SQL);
		$command = "db2 -tf " . $fsql . " -z " . $self->dbSqlOutputFile() . $null;
		Environment::logf("\n>> SQL: $sqlstr\n");
		Environment::logf(">> COMMAND: $command\n");
		system($command) and Environment::logf("***Error occurred in Db2DB::execSqlStmt***\n");
		unlink('null'); # null used to suppress output
		unlink($fsql);
		Environment::logf(">> Done. Check $dir$ps" . $self->dbSqlOutputFile() . " for output\n");
	}
	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $active = $ob->db2Active()
#-----------------------------------------------------------------------
#
# Checks silently whether db2 database manager has been started
#
#-----------------------------------------------------------------------
sub db2Active
{
	my $self = shift;
	my $active;
	
	system('db2 list active databases > mynull');
	if ($self->getEnv()->getOSName() eq 'windows') {
		open IN, '<', 'mynull';
		my $s = join("",<IN>);
		close(IN);
		$active = ($s =~ /no start database manager/i) ? 0 : 1;
	} else {
		$active = `cat mynull | grep 'No start database manager'` ? 0 : 1;
	}
	unlink('mynull');
	return $active;
}



#-----------------------------------------------------------------------
# $active = $ob->upperCaseDbDir()
#-----------------------------------------------------------------------
#
# Ensures that actual db2 database directory 
# (i.e. 'TEST' in '/home/user/db2inst1/NODE0000/TEST/') is upper case.
# Necessary for unix os' due to their case sensitivity
# DB2 uppercases this directory name even if the user specifies to create
# the database name in lower case
# At this point the path will have been terminated with a path separator
# (in setDbDirPath()) so we can look for /xxx/ at end of path
#
#-----------------------------------------------------------------------
sub upperCaseDbDir
{
	my $self = shift;
	my $dir = $self->dbDir();
	
	$dir =~ s/(.*)(\/.*\/)$/$1\U$2/;
	$self->dbDir($dir);
}

1;


=head1 NAME

Db2DB - 'Database' sub-class for implementing DB2-specific functionality

=head1 SYNOPSIS

use IBM::UC::Database::Db2DB;

######################################
#           class methods            #
######################################

 $ob = Db2DB->createSimple([$dbdir,$dbname,$dbuser,$dbpass,$dbschema])
  where:
   $dbdir=database directory
   $dbname=name of database to create or use (optional parameter)
   $dbuser=user name to access database (optional parameter)
   $dbpass=password of user (optional parameter)
   $dbschema=schema name to use (optional parameter)

 All parameters are optional, but those present must be in the specified order. Parameters not specified
 all get default values

 $ob = Db2DB->createComplex($hash_map)
  where:
   $hash_map=hash map of parameter name/value pairs (see below for examples)

 $ob = Db2DB->createFromConfig($config)
  where:
   $config=object of class DatabaseConfig (see below for examples)

 $ob = Db2DB->createFromFile($ini)
  where:
   $ini=configuration file

 See below for examples of all the above.

######################################
#         object data methods        #
######################################

### get versions ###

 See 'Database' module for remaining get methods

### set versions ###

 See 'Database' module for all available set methods

######################################
#        other object methods        #
######################################

 $ob->start();          	Optionally create config-specified database instance if it doesn't exist,
				create directories and copy files as necessary,
				starts Db2DB database manager. Use createDatabase() to create database
 $ob->stop();           	Shuts down database manager and optionally delete config-specified database 
 				instance
 $ob->createDatabase([$name])	Create database, where $name is database name (optional)
 				if not specified, database name specified during object creation is used
 $ob->deleteDatabase([$name])	Delete database, where $name is database name (optional)
 				if not specified, database name specified during object creation is used
 $ob->connectToDatabase([$name])Connect to database, where $name is database name (optional)
 				if not specified, database name specified during object creation is used
 				subsequent sql statements will execute against this database
 $ob->createSchema([$name])	Create schema, where $name is schema name (optional)
 				if not specified, schema name specified during object creation is used
 				Assumes that database connection exists (connectToDatabase())
 $ob->deleteSchema([$name])	Delete schema, where $name is schema name (optional)
 				if not specified, schema name specified during object creation is used
 $ob->execSql(file);		Executes batch sql statements from file
				(if no path is specified the current directory is assumed)
				%DB% and %TABLE% can be used as placeholders for dbName() and dbTableName()
 $ob->execSqlStmt(sqlstmt);	Executes single sql statement

=head1 DESCRIPTION

The Db2DB module is a sub-class of the Database super-class. Its purpose is to implement functionality
specific to DB2 databases: create a DB2 instance, create a DB2 database and associated
storage, launch the DB2 database manager, execute sql commands, and finally
shut down the database manager.

Initialisation of the database object's data can be done in several ways. Default values are used for 
object parameters not explicitly specified in the object's creation.

Valid configuration parameters and their default values follow (see DatabaseConfig.pm):

 ---------------------------------------------------------------------------------------------------------
 Parameter		Description					Default value
 ---------------------------------------------------------------------------------------------------------
 db_inst		Database instance name				Environment var 'DB2INSTANCE'
 db_dir			Database directory				'NODE0000' in 'DB2INSTANCE' dir + db_name
 db_dir_clean		delete db directory contents first (yes/no)	no
 db_name		Database name					TEST
 db_host		Database host					localhost
 db_port		Database port					n/a
 db_user		User name to access database			db2admin
 db_pass		Password for access to database			db2admin
 db_schema		Schema name					db2admin
 db_port		Port number					50000
 db_sql_output		File where sql output is redirected		sqloutput.log
 solid_lic		Solid licence file/location			n/a
 solid_ini_template	Template to use in generating solid.ini		n/a
 solid_db_inmemory	Specify whether to create in-memory database	n/a
 ---------------------------------------------------------------------------------------------------------

if initialisation is via a configuration ini file the Database section must, by default, start with [DATABASE]
and end with [/DATABASE] or end of file, e.g.:

 [DATABASE]

 ; Database Instance name
 db_inst=db2inst1

 ; Database directory
 db_dir=/home/db2inst1/db2inst1/NODE0000/TEST

 ; Specify whether to delete db_dir and its contents at startup (yes|no)
 db_dir_clean=yes

 ; Host name where database is located
 db_host=localhost

 ; Communication port for database
 db_port=2315 

 ; name of database to be created
 db_name=TEST
 .
 . 
 .
 etc.

=head1 EXAMPLES

Following are examples routines demonstrating the different ways a SolidDB object can be created:

 # Create database object from zero or more fixed order parameters
 # Parameters are all optional but those present must be in correct order
 # Parameters not included in the list get default values 
 sub create_simple
 {
 	# Parameters: Database dir, db name, user name, password, schema
	my $source = Db2DB->createSimple('/home/db2inst1/db2inst1/NODE0000/TEST','TEST','user','pass','schema');
	$source->printout(); # verify contents of object

	# As these parameters are optional you could just call:
	$source = Db2DB->createSimple();
	$source->printout();
	# Default values will be assigned to all parameters in this case

	# If you provide less than 6 parameters they must be in the correct order
	$source = Db2DB->createSimple('/home/user/test');
	$source->printout();
	return $source;
 }

 # Create database object from hash map. Any number of valid parameter names can be used
 # If a parameter name isn't recognised the program aborts and prints a full list of valid parameters
 # As before, default values are assigned to parameters not explicitly specified
 sub create_complex
 {
	my $source = Db2DB->createComplex({db_dir => '/home/db2inst1/db2inst1/NODE0000/TEST',db_name => 'TEST', 
					   db_user => 'user', db_pass => 'mypass', db_schema => 'myschema'});
	$source->printout();
	return $source;
 }


 # Create config object from hash map and use it to create db2 database object
 sub create_from_config
 {
	my $cfg_values = { 
		db_name => 'test', 
		db_schema => 'schema1',
	};
	my $source = Db2DB->createFromConfig(DatabaseConfig->createFromHash($cfg_values));
	$source->printout();
	return $source;
 }


 # Create config object from configuration file and use it to create database object
 sub create_from_config_ini
 {
	my $ini = shift;
	my $db2_cfg = DatabaseConfig->new($ini);

	$db2_cfg->initFromConfigFile();
	my $source = Db2DB->createFromConfig($db2_cfg);
	$source->printout();
	return $source;
 }


 # Create database object directly from configuration file
 sub create_from_file
 {
	my $ini = shift;
	my $source = Db2DB->createFromFile($ini);
	$source->printout();
	return $source;
 }

A typical sequence of calls to create a DB2 instance, start DB2 database manager, 
execute sql and shut down the manager would be:

 # Create DB2 database object, start solid manager, execute sql and shut down manager
 sub create_and_run_db2
 {
	my $env_parms = {
		debug => 1,
		smtp_server => 'D06DBE01',
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));
	
	my $db_params = { 
		db_dir => '/home/db2inst1/db2inst1/NODE0000/TEST',
		db_name => 'TEST',
		db_schema => 'db2inst1'
	};
	my $source = Db2DB->createFromConfig(DatabaseConfig->createFromHash($db_params));
	$source->start();
	$source->createDatabase();
	# create default schema db_schema
	$source->createSchema();
	# Set table name for sql file, %TABLE% placeholder in *.sql file will be replaced by it	
	$source->dbTableName('src');
	$source->execSql('db2_createsrc.sql');
	my $stmt = "insert into src values (1,'Brendan','Smith','Annfield Crescent, Dublin','Ireland')";
	$source->execSqlStmt($stmt);
	$source->stop();
 }


An example of automating the creation of source and target databases, setting up replication between
tables in the databases and verifying that replication has taken place would be as follows:

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
		cvs_user => 'dmbuild',
		cvs_pass => 'dmbuild',
		cvs_repository => ':pserver:dmbuild:dmbuild@dmccvs.torolab.ibm.com:/home/cvsuser/cvsdata',
		cvs_home => '/home/db2inst1/cvs',
		cvs_tag => 'HEAD',
		cdc_db2_root_dir => '/home/db2inst1/Transformation Server for UDB/',
		ant_version => 'apache-ant-1.6.2',
		java_home => '/home/DownloadDirector/ibm-java2-i386-50/',
		java6_home => '/home/DownloadDirector/ibm-java-i386-60/',
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));

	# create and start source database
	$dbvals_src = { 
		db_dir => '/home/db2inst1/db2inst1/NODE0000/TEST',
		db_name => 'TEST',
		db_user => 'db2inst1',
		db_pass => 'db2inst1',
	};
	$db_src = Db2DB->createFromConfig(DatabaseConfig->createFromHash($dbvals_src));
	$db_src->start();
	# createDatabase also connects to database
	$db_src->createDatabase();
	# Create source schema
	$db_src->createSchema('db2inst1');

	# Start target and connect to it (already created above)
	$dbvals_tgt = { 
		db_dir => '/home/db2inst1/db2inst1/NODE0000/TEST',
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

	# Set table names for source and target sql
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

If everything works as expected source and target tables should have the same content.

=cut
