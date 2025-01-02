#!/usr/bin/perl

use strict;

use IBM::UC::Database::InformixDB;
use IBM::UC::Environment;

test1();

sub test1
{
	eval { # trap errors so we can clean up before exiting

	my $env_parms = {
		debug => 1,
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));
	

    # Create informix db object
    my $informix_root = "";
    my $informix_tarball = "";
    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $informix_root = "c:\\ids_dest";
       	$informix_tarball = "c:\\temp\\CZ51IWEN.zip";
    } else {
    	$informix_root = "/opt/ibm/informix";
    	$informix_tarball = "/tmp/CZ5IZEN.tar";
    } 
    my $informix = InformixDB->createSimple('informix',
                                          'M1inframe',
	                                      $informix_root,
	                                      "informix_server",
	                                      "ids_db1",
	                                      9088,
	                                      'informix');

	# install database
	$informix->install($informix_tarball);
	$informix->start();
	
	
    if (Environment::getEnvironment()->getOSName() ne 'windows') {
        print "If you intend to use informix using a user other than root or informix, \n";
        print "please add them to the informix group, e.g. usermod -G informix mroche\n";
	}
	}
}
