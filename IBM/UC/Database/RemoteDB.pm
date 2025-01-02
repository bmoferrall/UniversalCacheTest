########################################################################
# 
# File   :  RemoteDB.pm
# History:  Mar-2010 (bmof/ag) module created as part of Test Automation
#			project
#
########################################################################
#
# RemoteDB.pm is a sub-class of Database.pm.
# Its intention is to describe a database on a remote machine, one with
# which no interaction will take place. Therefore, the behaviour of this
# class will be curtailed (e.g. no database creation, SQL queries, etc.)
# 
########################################################################
package RemoteDB;

use strict;

use IBM::UC::Database;
use File::Path;
use File::Copy;
use Cwd;
use UNIVERSAL qw(isa);

our @ISA = qw(Database); # database super class


#-------------------------------------------------------------------------------------
# $ob = RemoteDB->createSimple([$db_type,$db_name,$db_host,$db_user,$db_pass,
#								$db_schema,$db_port])
#-------------------------------------------------------------------------------------
#
# create Remote Database object using fixed order parameters
# e.g. RemoteDB->createSimple('DB2','name','localhost','user','pass','schema',50000)
#--------------------------------------------------------------------------------------
sub createSimple
{
	my $class = shift;
	my $dbtype = shift; # database type (e.g. 'DB2','SOLID','INFORMIX','ORACLE')
	my $dbname = shift; # database name
	my $dbhost = shift; # database host
	my $dbuser = shift; # database user
	my $dbpass = shift; # database password
	my $dbschema = shift; # database schema
	my $dbport = shift; # database port

	my $self = $class->SUPER::new();

	bless $self, $class;

	# Make sure we get all parameters
	if (!defined($dbtype)) {
		Environment::fatal("RemoteDB::createSimple requires database type as 1st input\nExiting...\n");
	}
	if (!defined($dbname)) {
		Environment::fatal("RemoteDB::createSimple requires database name as 2nd input\nExiting...\n");
	}
	if (!defined($dbhost)) {
		Environment::fatal("RemoteDB::createSimple requires database host as 3rd input\nExiting...\n");
	}
	if (!defined($dbuser)) {
		Environment::fatal("RemoteDB::createSimple requires database user as 4th input\nExiting...\n");
	}
	if (!defined($dbpass)) {
		Environment::fatal("RemoteDB::createSimple requires database password as 5th input\nExiting...\n");
	}
	if (!defined($dbschema)) {
		Environment::fatal("RemoteDB::createSimple requires database schema as 6th input\nExiting...\n");
	}
	if (!defined($dbport)) {
		Environment::fatal("RemoteDB::createSimple requires database port as 7th input\nExiting...\n");
	}
	
	Environment::logf(">>Creating Remote Database instance for \"$dbtype\" database...\n");
	$self->init(); # set defaults

	$self->dbPort($dbport);
	$self->dbSchema($dbschema);
	$self->dbPass($dbpass);
	$self->dbUser($dbuser);
	$self->dbHost($dbhost);
	$self->dbName($dbname);
	$self->dbType($dbtype);

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");

	Environment::logf(">>Done.\n");	
	return $self;
}


#------------------------------------------------------------------------------------
# $ob = RemoteDB->createComplex($refParam)
#------------------------------------------------------------------------------------
#
# create Remote DB object from variable parameters
# See POD for allowed parameter names and their default values
# e.g. RemoteDB->createComplex({db_name => 'test', db_type => 'schema1'})
#
#------------------------------------------------------------------------------------
sub createComplex
{
	my $class = shift;
	my $refParam = shift; # hash ref with name/value pairs

	my $self = $class->SUPER::new();

	bless $self, $class;

	Environment::logf(">>Creating Remote Database instance...\n");
	$self->init(); # set defaults

	if (!defined($refParam) or (ref($refParam) ne 'HASH')) {
		Environment::fatal("RemoteDB::createComplex: expecting hash reference as parameter\nExiting...\n");
	} else {
		# override defaults with parameters passed
		$self->getConfig()->initFromConfig($refParam);
	}

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");

	# Make sure database type db_type was specified
	$self->dbType() or Environment::fatal("RemoteDB::createComplex. Database type must be specified...\n");

	Environment::logf(">>Done.\n");	
	return $self;
}



#-----------------------------------------------------------------------
# $ob = RemoteDB->createFromConfig($config)
#-----------------------------------------------------------------------
# 
# Create Remote DB object from existing DatabaseConfig object which is essentially a hash
# of parameter name/value pairs.
# See POD for allowed parameter names and their default values
# e.g.
# $config_values = { db_type => 'DB2', db_name => 'test', db_user => 'user', 
#					 db_pass => 'pass', db_schema_name => 'schema1'};
# RemoteDB->createFromConfig(DatabaseConfig->createFromHash($config_values));
# 
#-----------------------------------------------------------------------
sub createFromConfig
{
	my $class = shift;
	my $config = shift;
	my $self = $class->SUPER::new();

	bless $self, $class;

	Environment::logf(">>Creating Remote Database instance...\n");
	$self->init();	

	# override defaults with parameters passed
	if (ref($config) eq 'DatabaseConfig') {
		$self->getConfig()->initFromConfig($config->getParams());	
	} else {
		Environment::fatal("RemoteDB::createFromConfig: config parameter not of type \"DatabaseConfig\"\n");
	}

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");

	# Make sure database type db_type was specified
	$self->dbType() or Environment::fatal("RemoteDB::createFromConfig. Database type must be specified...\n");
	
	Environment::logf(">>Done.\n");	
	return $self;
}



#-----------------------------------------------------------------------
# $ob = Db2DB->createFromFile($ini)
#-----------------------------------------------------------------------
# 
# Create Remote DB object using configuration info from ini file (in the form
# of name=value records).
# See POD for allowed parameter names and format of the ini file
# e.g. RemoteDB->createFromFile('instance1.ini')
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
		Environment::fatal("RemoteDB::createFromFile needs valid *.ini file as input\nExiting...\n");
	}

	bless $self, $class;

	Environment::logf(">>Creating Remote Database instance...\n");
	$self->init();	
	
	# Check that config is fully initialised
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");

	# Make sure database type db_type was specified
	$self->dbType() or Environment::fatal("RemoteDB::createFromFile. Database type must be specified...\n");

	Environment::logf(">>Done.\n");	
	return $self;
}


#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise Remote DB instance, including assigning default values and calling
# super class version of init()
#
#-----------------------------------------------------------------------
sub init
{
	my $self = shift;
	my $ps = $self->getEnv()->getPathSeparator();
				                	    	
	# Make sure we only initialise once,
	#    in case a user explicitly calls what is intended to be a private method
	if (!$self->initialised()) {
		# Initialise some config parameters to default values
		$self->getConfig()->initFromConfig({db_dir => '', # required by DatabaseConfig but not needed by RemoteDB
											});

		# invoke super class' initialiser
		$self->SUPER::init();	
		$self->initialised(1);
	}
}




#-----------------------------------------------------------------------
# $ob->start()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub start
{
	Environment::fatal("start() not implemented by RemoteDB\n");
}


#-----------------------------------------------------------------------
# $ob->stop()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub stop
{
	Environment::fatal("stop() not implemented by RemoteDB\n");
}




#-----------------------------------------------------------------------
# $ob->createDatabase()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub createDatabase
{
	Environment::fatal("createDatabase() not implemented by RemoteDB\n");
}


#-----------------------------------------------------------------------
# $ob->connectToDatabase()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub connectToDatabase
{
	Environment::fatal("connectToDatabase() not implemented by RemoteDB\n");
}



#-----------------------------------------------------------------------
# $ob->deleteDatabase()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub deleteDatabase
{
	Environment::fatal("deleteDatabase() not implemented by RemoteDB\n");
}


#-----------------------------------------------------------------------
# $ob->createSchema()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub createSchema
{
	Environment::fatal("createSchema() not implemented by RemoteDB\n");
}



#-----------------------------------------------------------------------
# $ob->deleteSchema([$name])
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub deleteSchema
{
	Environment::fatal("deleteSchema() not implemented by RemoteDB\n");
}


#--------------------------------------------------------------------------
# $ob->execSql()
#--------------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub execSql
{
	Environment::fatal("execSql() not implemented by RemoteDB\n");
}


#-----------------------------------------------------------------------
# $ob->execSqlStmt()
#-----------------------------------------------------------------------
#
# Not implemented
#
#-----------------------------------------------------------------------
sub execSqlStmt
{
	Environment::fatal("execSqlStmt() not implemented by RemoteDB\n");
}



1;


=head1 NAME

RemoteDB - 'Database' sub-class for implementing Remote database functionality
           Its intention is to describe a database on a remote machine, one with
           which no interaction will take place. Therefore, the behaviour of this
           class will be curtailed (e.g. no database creation, SQL queries, etc.)

=head1 SYNOPSIS

use IBM::UC::Database::RemoteDB;

######################################
#           class methods            #
######################################

 $ob = RemoteDB->createSimple($dbtype,$dbname,$dbuser,$dbpass,$dbschema)
  where:
   $dbtype=database type
   $dbname=name of database to create or use
   $dbuser=user name to access database
   $dbpass=password of user
   $dbschema=schema name to use
   $dbport=database port number

 $ob = RemoteDB->createComplex($hash_map)
  where:
   $hash_map=hash map of parameter name/value pairs (see below for examples)

 $ob = RemoteDB->createFromConfig($config)
  where:
   $config=object of class DatabaseConfig (see below for examples)

 $ob = RemoteDB->createFromFile($ini)
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


=head1 DESCRIPTION

The RemoteDB module is a sub-class of the Database super-class.
Its intention is to describe a database on a remote machine, one with
which no interaction will take place. Therefore, the behaviour of this
class will be curtailed (e.g. no database creation, SQL queries, etc.)


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

if initialisation is via a configuration ini file the format is as folows:

 [DATABASE]

 ; Type of database
 db_type=SOLID

 ; Communication port for database
 db_port=2315 

 ; name of database to be created
 db_name=TEST
 .
 . 
 .
 etc.

=head1 EXAMPLES


=cut
