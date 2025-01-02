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



switch ($ARGV[0]) {
	case "config" { create_cdc_from_config(); }
	case "file" { create_cdc_from_file(); }
	else { print "Please specify one of the following options\n\t/
			(config|file)\ne.g. cdc_test.pl config\n" }
}

# Create db config object from hash map and use it to create solid database object
# Create cdc config object from hash map
# Use both config objects to create CDC object
sub create_cdc_from_config
{
	my $env_params = {};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_params));
	my $sol_params = { 
		db_port => '2317', 
		db_dir => 'sol_source',
	};
	my $source = SolidDB->createFromConfig(DatabaseConfig->createFromHash($sol_params));
	$source->start();
	
	my $cdc_params = {
		ts_name => 'ts_source',
		ts_port => 11121,
	};
	my $cdc_sol = CDCSolid->createFromConfig(CDCConfig->createFromHash($cdc_params),$source);
	$cdc_sol->printout();
	$cdc_sol->create();
	$cdc_sol->delete();
}


# Create db config object from ini file and use it to create solid database object
# Create cdc config object from same ini file
# Use both config objects to create CDC object
sub create_cdc_from_file
{
	my $env_params = {};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_params));
	my $sol_cfg = DatabaseConfig->new('solid_instance1.ini');
	$sol_cfg->initFromConfigFile();

	my $source = SolidDB->createFromConfig($sol_cfg);
	$source->start();

	my $cdc_cfg = CDCConfig->new('solid_instance1.ini');
	$cdc_cfg->initFromConfigFile();

	my $cdc_sol = CDCSolid->createFromConfig($cdc_cfg,$source);
	$cdc_sol->printout();
	$cdc_sol->create();
	$cdc_sol->delete();
}

