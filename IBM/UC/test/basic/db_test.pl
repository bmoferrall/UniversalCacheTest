#!/usr/bin/perl

use strict;

use IBM::UC::Database::SolidDB;
use IBM::UC::Database::Db2DB;
use IBM::UC::Environment;
use Switch;



switch ($ARGV[0]) {
	case "simple" { create_simple(); }
	case "complex" { create_complex(); }
	case "config" { 
		create_from_config();
		create_from_config_ini(); 
	}
	case "file" { create_from_file(); }
	case "run_sol" { create_and_run_solid(); }
	case "run_db2" { create_and_run_db2(); }
	case "all" { 
		create_simple();
		create_complex();
		create_from_config();
		create_from_config_ini();
		create_from_file();
		create_and_run_solid();
		create_and_run_db2();
	}
	else { print "Please specify one of the following options\n\t/
			(simple|complex|config|file|run_sol|run_db2|all)\ne.g. db_test.pl simple\n" }
}


# Create database objects from zero or more fixed order parameters
# Parameters are all optional but those present must be in correct order
sub create_simple
{
	# Solid parameters: Home directory, database sub-directory, port number, solid licence file
	my $source = SolidDB->createSimple('/tmp/src',2319,'mysolid.lic');
	$source->printout();

	# DB2 parameters: Home dir, database sub-dir, db name, user name, password, schema
	my $target = Db2DB->createSimple('/home/user/db2inst1/test','test','user','mypass','myschema');
	$target->printout();
}


# Create database objects from hash maps (either using anonymous hash map or hash map variable)
# Any valid parameter name can be used
# If a parameter name isn't recognised the program aborts and prints a full list of valid parameters
sub create_complex
{
	# Create with anonymous hash reference
	my $source = SolidDB->createComplex({db_port => 2319, db_dir => '/home/user/sol_source'});
	$source->printout();

	my $db2_params = {
		db_dir => '/home/user/test',
		db_name => 'test',
		db_user => 'user',
		db_pass => 'mypass',
		db_schema => 'myschema',
	};
	my $target = Db2DB->createComplex($db2_params);
	$target->printout();
}

# Create config objects from hash maps and use them to create database objects
sub create_from_config
{
	my $config_values = { 
		db_port => '2317', 
		db_dir => '/home/user/sol_tgt',
	};
	my $source = SolidDB->createFromConfig(DatabaseConfig->createFromHash($config_values));
	$source->printout();

	my $config_db2 = DatabaseConfig->new();
	my $config_values_db2 = { 
		db_name => 'test', 
		db_dir => '/home/user/test', 
		db_user => 'user', 
		db_pass => 'pass',
		db_tbl_name => 'table',
	};
	$config_db2->initFromConfig($config_values_db2);
	my $target = Db2DB->createFromConfig($config_db2);
	$target->printout();
}

# Create config object from ini file and use it to create database object
sub create_from_config_ini
{
	my $config = DatabaseConfig->new('solid_instance1.ini');

	my $source = SolidDB->createFromConfig($config->initFromConfigFile());
	$source->printout();
}

# Create database objects from ini files
sub create_from_file
{
	my $env = Environment->createFromFile('solid_instance1.ini');
	my $source = SolidDB->createFromFile('solid_instance1.ini');
	$source->printout();
	my $target = Db2DB->createFromFile('db2_instance2.ini');
	$target->printout();
}

# Create solid database object, start solid manager, execute sql and shut down manager
sub create_and_run_solid
{
	my $env_parms = {
		debug => 1,
		smtp_server => 'D06DBE01',
		email_admin => 'mooreof@ie.ibm.com'
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));
	
	my $config_values = { 
		db_port => '2317', 
		db_dir => '/home/db2inst1/solid/sol_src',
	};
	my $source = SolidDB->createFromConfig(DatabaseConfig->createFromHash($config_values));
	$source->start();
	# Set table name to replace placeholder %TABLE% in 'sol_createsrc.sql'
	$source->dbTableName('src');
	$source->execSql('sol_createsrc.sql');
	my $stmt = "insert into src values (1,'Brendan','Smith','Annfield Crescent, Dublin','Ireland')";
	$source->execSqlStmt($stmt);	
	$source->stop();
}


# Create DB2 database object, start solid manager, execute sql and shut down manager
sub create_and_run_db2
{
	my $env_parms = {
		debug => 1,
		smtp_server => 'D06DBE01',
		email_admin => 'mooreof@ie.ibm.com'
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));
	
	my $db_params = { 
		db_dir => '/home/db2inst1/db2inst1/NODE0000/TEST',
		db_name => 'TEST',
	};
	my $source = Db2DB->createFromConfig(DatabaseConfig->createFromHash($db_params));
	$source->start();
	$source->createDatabase();
	$source->createSchema('db2admin');
	# Set table name to replace placeholder %TABLE% in 'sol_createsrc.sql'
	$source->dbTableName('src');
	$source->execSql('db2_createsrc.sql');
	my $stmt = "insert into db2admin.src values (1,'Brendan','Smith','Annfield Crescent, Dublin','Ireland')";
	$source->execSqlStmt($stmt);	
	$source->stop();
}


