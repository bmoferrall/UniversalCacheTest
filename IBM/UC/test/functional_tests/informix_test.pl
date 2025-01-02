#!/usr/bin/perl

use strict;

use IBM::UC::Database::InformixDB;
use IBM::UC::Environment;

test1();

sub test1
{
eval { # trap errors so we can clean up before exiting

    # Initialise environment
	my $env_parms = {
		debug => 1,
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));


    # Create informix db object
    my $informix_root = "";
    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $informix_root = "c:\\ids_dest";
    } else {
    	$informix_root = "/opt/ibm/informix";
    } 
    my $informix = InformixDB->createSimple('informix',
                                          'M1inframe',
	                                      $informix_root,
	                                      "informix_server",
	                                      "ids_db1",
	                                      9088,
	                                      'informix');

    # start database if not started
	$informix->start();
	$informix->createDatabase($informix->dbName());

	# Create schema
	$informix->execSqlStmt("create schema authorization informix");
	$informix->execSqlStmt("create table test1_table (number integer)");
	$informix->execSqlStmt("insert into test1_table values(1)");
	$informix->execSqlStmt("select * from test1_table");
};
}

