########################################################################
# 
# File   :  Database.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# Database.pm is a generic class to implement database functionality.
# 
########################################################################
package Database;

use strict;

use IBM::UC::Environment;
use IBM::UC::UCConfig::DatabaseConfig;
use Data::Dumper;
use File::Basename;


#-----------------------------------------------------------------------
# $ob = Database->new([$ini])
#-----------------------------------------------------------------------
#
# Create Database object
# Optional parameter $ini is used to load configuration parameters
# e.g. $ob = Database->new('solid_instance1.ini')
#
#-----------------------------------------------------------------------
sub new
{
	my $class = shift;
	my $ini = shift;
	
	my $self = {
		CONFIG => {}, # Stores configuration object with parameter information
	};
	bless $self, $class;

	if (defined($ini)) { # If given an ini file create config object from it
		$self->{'CONFIG'} = new DatabaseConfig($ini);
	} else { # create default config object
		$self->{'CONFIG'} = new DatabaseConfig();
	}

	return $self;
}


#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise database object
# Loads configuration from $ini file if passed during object's creation
#
#-----------------------------------------------------------------------
sub init
{
	my $self = shift;
	
	# Load parameter values from ini if provided
	$self->getConfig()->initFromConfigFile() if (defined($self->getIniFileName()));
}


#-----------------------------------------------------------------------
# $ob->printout()
#-----------------------------------------------------------------------
#
# Prints out contents of object's hash in a human-readable form
#
#-----------------------------------------------------------------------
sub printout
{
	my $self = shift;
	
	Environment::logf(Dumper($self));
}


#-----------------------------------------------------------------------
# $ob->createStorage()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub createStorage
{
	Environment::fatal("createStorage not implemented in Database class\n");
}


#-----------------------------------------------------------------------
# $ob->cleanStorage()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub cleanStorage
{
	Environment::fatal("cleanStorage not implemented in Database class\n");
}


#-----------------------------------------------------------------------
# $ob->start()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub start
{
	Environment::fatal("start not implemented in Database class\n");
}


#-----------------------------------------------------------------------
# $ob->stop()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub stop
{
	Environment::fatal("stop not implemented in Database class\n");
}


#-----------------------------------------------------------------------
# $ob->execSql()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub execSql
{
	Environment::fatal("execSql not implemented in Database class\n");
}


#-----------------------------------------------------------------------
# $ob->execSqlStmt()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub execSqlStmt
{
	Environment::fatal("execSqlStmt not implemented in Database class\n");
}



#-----------------------------------------------------------------------
# $ob->prepareSqlFile($sqlfile)
#-----------------------------------------------------------------------
#
# Replaces placeholders for database name, schema name and table name 
# (%DB%, %SCHEMA% and %TABLE%)
# with values specified in the configuration
# This sub is called from execSql()
#
#-----------------------------------------------------------------------
sub prepareSqlFile
{
	my $self = shift;
	my $sql = shift;
	my $contents;

	open(SQL,'<',$sql) || Environment::fatal("Cannot open \"$sql\": $!\n");
	$contents = join("",<SQL>);
	close(SQL);
	$contents =~ s/%DB%/$self->dbName()/eg;
	$contents =~ s/%SCHEMA%/$self->dbSchema()/eg;
	$contents =~ s/%TABLE%/$self->dbTableName()/eg;
	open(SQL,'>',$sql);
	print SQL $contents;
	close(SQL);
}


#-----------------------------------------------------------------------
# $ob->createInstance()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub createInstance
{
	Environment::fatal("createInstance not implemented in Database class\n");
}


#-----------------------------------------------------------------------
# $ob->deleteInstance()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub deleteInstance
{
	Environment::fatal("deleteInstance not implemented in Database class\n");
}


#-----------------------------------------------------------------------
# $ob->createDatabase()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub createDatabase
{
	Environment::fatal("createDatabase not implemented in Database class\n");
}


#-----------------------------------------------------------------------
# $ob->connectToDatabase()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub connectToDatabase
{
	Environment::fatal("connectToDatabase not implemented in Database class\n");
}



#-----------------------------------------------------------------------
# $ob->deleteDatabase()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub deleteDatabase
{
	Environment::fatal("deleteDatabase not implemented in Database class\n");
}



#-----------------------------------------------------------------------
# $ob->createSchema()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub createSchema
{
	Environment::fatal("createSchema not implemented in Database class\n");
}



#-----------------------------------------------------------------------
# $ob->deleteSchema()
#-----------------------------------------------------------------------
#
# Empty sub which should be implemented by subclass of Database
#
#-----------------------------------------------------------------------
sub deleteSchema
{
	Environment::fatal("deleteSchema not implemented in Database class\n");
}




#############################################################
# GET/SET METHODS
#############################################################



#-----------------------------------------------------------------------
# $env = $ob->getEnv()
#-----------------------------------------------------------------------
#
# Get environment instance
#
#-----------------------------------------------------------------------
sub getEnv
{
	my $self = shift;
	return Environment::getEnvironment();
}


#-----------------------------------------------------------------------
# $ini = $ob->getIniFileName()
#-----------------------------------------------------------------------
#
# Get configuration ini file name
#
#-----------------------------------------------------------------------
sub getIniFileName
{
	my $self = shift;
	return $self->getConfig()->getIniFile();
}


#-----------------------------------------------------------------------
# $cfg = $ob->getConfig()
#-----------------------------------------------------------------------
#
# Get configuration object (class DatabaseConfig)
#
#-----------------------------------------------------------------------
sub getConfig
{
	my $self = shift;
	return $self->{'CONFIG'};
}


#-----------------------------------------------------------------------
# $ref = $ob->getConfigParams()
#-----------------------------------------------------------------------
#
# Get reference to configuration parameters hash
#
#-----------------------------------------------------------------------
sub getConfigParams
{
	my $self = shift;
	return $self->getConfig()->getParams();
}


#-----------------------------------------------------------------------
# $name = $ob->instanceName()
# $ob->instanceName($name)
#-----------------------------------------------------------------------
#
# Get/set database instance name
#
#-----------------------------------------------------------------------
sub instanceName
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_inst'} = $name if defined($name);
	return $self->getConfigParams()->{'db_inst'};
}



#-----------------------------------------------------------------------
# $ob->setDbDirPath($dir)
#-----------------------------------------------------------------------
#
# If dbDir was specified without a path, we make its path the start 
# directory
#
#-----------------------------------------------------------------------
sub setDbDirPath
{
	my $self = shift;
	my $dir = shift;
	my $ps = $self->getEnv()->getPathSeparator();
	my $path;
	my $subdir;

	($path,$subdir) = File::Basename::fileparse($dir);
	# If we were given, e.g., 'dir' only (i.e. no path), then fileparse will set $subdir to './' or '.\'
	$dir = $self->getEnv()->getStartDir() . $dir if (substr($subdir,0,1) eq '.');

	# make sure path is terminated with separator
	$dir .= $ps if (substr($dir,-1,1) !~ m/[\/\\]/);
	$self->dbDir($dir);
	
	# Remove last part of path and store as base database path
	# i.e. /home/db2inst1/db2inst1/NODE0000/TEST/ -->>
	#      /home/db2inst1/db2inst1/NODE0000/
	$dir =~ s/(.*[\/\\])(.*[\/\\])$/$1/;
	$self->dbBaseDir($dir);
}



#-----------------------------------------------------------------------
# $dir = $ob->dbDir()
# $ob->dbDir($dir)
#-----------------------------------------------------------------------
#
# Get/set database directory.
#
#-----------------------------------------------------------------------
sub dbDir
{
	my ($self,$dir) = @_;
	$self->getConfigParams()->{'db_dir'} = $dir if defined($dir);
	return $self->getConfigParams()->{'db_dir'};
}



#-----------------------------------------------------------------------
# $dir = $ob->dbBaseDir()
# $ob->dbBaseDir($dir)
#-----------------------------------------------------------------------
#
# Get/set base database directory.
#
#-----------------------------------------------------------------------
sub dbBaseDir
{
	my ($self,$dir) = @_;
	$self->{'BASEDIR'} = $dir if defined($dir);
	return $self->{'BASEDIR'};
}


#-----------------------------------------------------------------------
# $clean = $ob->dbDirClean()
# $ob->dbDirClean($clean)
#-----------------------------------------------------------------------
#
# Get/set flag (yes/no) specifying whether to delete database sub-directory
# and its contents at start
#
#-----------------------------------------------------------------------
sub dbDirClean
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_dir_clean'} = $name if defined($name);
	return $self->getConfigParams()->{'db_dir_clean'};
}


#-----------------------------------------------------------------------
# $name = $ob->dbName()
# $ob->dbName($name)
#-----------------------------------------------------------------------
#
# Get/set database name
#
#-----------------------------------------------------------------------
sub dbName
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_name'} = $name if defined($name);
	return $self->getConfigParams()->{'db_name'};
}



#-----------------------------------------------------------------------
# $host = $ob->dbHost()
# $ob->dbHost($host)
#-----------------------------------------------------------------------
#
# Get/set host name of machine where database lives
#
#-----------------------------------------------------------------------
sub dbHost
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_host'} = $name if defined($name);
	return $self->getConfigParams()->{'db_host'};
}


#-----------------------------------------------------------------------
# $port = $ob->dbPort()
# $ob->dbPort($port)
#-----------------------------------------------------------------------
#
# Get/set database communication port
#
#-----------------------------------------------------------------------
sub dbPort
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_port'} = $name if defined($name);
	return $self->getConfigParams()->{'db_port'};
}


#-----------------------------------------------------------------------
# $name = $ob->dbUser()
# $ob->dbUser($name)
#-----------------------------------------------------------------------
#
# Get/set user name with access rights to database
#
#-----------------------------------------------------------------------
sub dbUser
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_user'} = $name if defined($name);
	return $self->getConfigParams()->{'db_user'};
}


#-----------------------------------------------------------------------
# $pass = $ob->dbPass()
# $ob->dbPass($pass)
#-----------------------------------------------------------------------
#
# Get/set password for dbUser()
#
#-----------------------------------------------------------------------
sub dbPass
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_pass'} = $name if defined($name);
	return $self->getConfigParams()->{'db_pass'};
}


#-----------------------------------------------------------------------
# $name = $ob->dbSchema()
# $ob->dbSchema($name)
#-----------------------------------------------------------------------
#
# Get/set database schema name
#
#-----------------------------------------------------------------------
sub dbSchema
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_schema'} = $name if defined($name);
	return uc($self->getConfigParams()->{'db_schema'});
}


#-----------------------------------------------------------------------
# $name = $ob->dbTableName()
# $ob->dbTableName($name)
#-----------------------------------------------------------------------
#
# Get/set database table name
# Useful if you use placeholder %TABLE% in an sql batch file to represent
# a table name, rather than explicitly specifying the table name, e.g.:
# $source->dbTableName('src')
# $source->execSql('create_table.sql')
# (%TABLE% in 'create_table.sql' replaced with 'src')
#
#-----------------------------------------------------------------------
sub dbTableName
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_tbl_name'} = $name if defined($name);
	return uc($self->getConfigParams()->{'db_tbl_name'});
}



#-----------------------------------------------------------------------
# $name = $ob->dbSqlOutputFile()
# $ob->dbSqlOutputFile($name)
#-----------------------------------------------------------------------
#
# Get/set name of file where output from sql commands (execSql()) go
#
#-----------------------------------------------------------------------
sub dbSqlOutputFile
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_sql_output'} = $name if defined($name);
	return $self->getConfigParams()->{'db_sql_output'};
}




#-----------------------------------------------------------------------
# $type = $ob->dbType()
# $ob->dbType($type)
#-----------------------------------------------------------------------
#
# Get/set type of database
# Used mainly by RemoteDB module
#
#-----------------------------------------------------------------------
sub dbType
{
	my ($self,$type) = @_;
	
	if (defined($type) && !grep(uc($type) eq $_, @DatabaseConfig::VALIDDBTYPES)) {
		Environment::logf("Database::databaseType: unrecognised database type \"$type\"\n\tValid types: @{DatabaseConfig::VALIDDBTYPES}\n");
	}
	$self->getConfigParams()->{'db_type'} = uc($type) if defined($type);
	return $self->getConfigParams()->{'db_type'};
}


#-----------------------------------------------------------------------
# $init = $ob->initialised()
# $ob->initialised($init)
#-----------------------------------------------------------------------
#
# Get/set flag indicating whether object has been initialised.
# This is done to prevent object being initialised later by a user
# which would set all parameters back to their default values
#
#-----------------------------------------------------------------------
sub initialised
{
	my ($self,$init) = @_;
	if (!defined($self->{'INIT'})) { $self->{'INIT'} = 0; }
	$self->{'INIT'} = $init if defined($init);
	return $self->{'INIT'};
}


1;



=head1 NAME

Database - (super) class to implement database functionality

=head1 SYNOPSIS

use IBM::UC::Database;

#################
# class methods #
#################

 $ob = Database->new($ini);
   where:
     $ini=configuration file (optional parameter)

#######################
# object data methods #
#######################

### get versions ###

 $env = $ob->getEnv()
 $ini = $ob->getIniFileName()
 $cfg = $ob->getConfig()
 $cfg = $ob->getConfigParams()
 $inst = $ob->instanceName()
 $dbdir = $ob->dbDir()
 $clean = $ob->dbDirClean()
 $name = $ob->dbName()
 $host = $ob->dbHost()
 $port = $ob->dbPort()
 $user = $ob->dbUser()
 $pass = $ob->dbPass()
 $sch = $ob->dbSchema()
 $type = $ob->dbType()
 $tbl = $ob->dbTableName()
 $sqlo = $ob->dbSqlOutputFile()

### set versions ###

 $ob->instanceName('name')
 $ob->dbDir('/home/user/dbdir')
 $ob->dbDirClean(1)
 $ob->dbName('dbname')
 $ob->dbHost('localhost')
 $ob->dbPort(2315)
 $ob->dbUser('dba')
 $ob->dbPass('dba')
 $ob->dbSchema('dba')
 $ob->dbType('SOLID')
 $ob->dbTableName('tbl')		# set table name to replace %TABLE% placeholder in sql files
 $ob->dbSqlOutputFile(0[,'sql.log'])

########################
# other object methods #
########################

 $ob->createStorage()		Empty method to be implemented by sub-class
 $ob->start()			Empty method to be implemented by sub-class
 $ob->stop()			Empty method to be implemented by sub-class
 $ob->createInstance()		Empty method to be implemented by sub-class
 $ob->deleteInstance()		Empty method to be implemented by sub-class
 $ob->createDatabase([$name])	Empty method to be implemented by sub-class
 $ob->deleteDatabase([$name])	Empty method to be implemented by sub-class
 $ob->createSchema([$name])	Empty method to be implemented by sub-class
 $ob->deleteSchema([$name])	Empty method to be implemented by sub-class
 $ob->connectToDatabase([$name])Empty method to be implemented by sub-class
 $ob->prepareSql()		Replaces placeholders in SQL file, where:
 				%DB%=Database name
 				%SCHEMA%=Schema name
 				%TABLE%=Table name 
 $ob->execSql(sql)		Empty method to be implemented by sub-class
 $ob->execSqlStmt(sql)		Empty method to be implemented by sub-class
 $ob->printout()		printout readable version of object's contents 
 				(for debug purposes only)

=head1 DESCRIPTION

The Database class is a superclass intended to implement common methods 
for launching a database manager, creating a database instance, 
creating a database and associated storage, executing batch sql commands, 
optionally deleting the created database and finally shutting down the database manager.

=head1 EXAMPLES

See SolidDB and DB2DB classes for examples of use.

=cut
