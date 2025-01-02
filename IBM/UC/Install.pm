########################################################################
# 
# File   :  Install.pm
# History:  Apr-2010 (cg) module created as part of Test Automation
#			project
#
########################################################################
#
# Install.pm is a generic class to implement install functionality.
# 
########################################################################
package Install;

use strict;

use IBM::UC::Environment;
use IBM::UC::UCConfig::InstallConfig;
use Data::Dumper;
use File::Basename;


#-----------------------------------------------------------------------
# $ob = Install->new([$ini])
#-----------------------------------------------------------------------
#
# Create Install object
# Optional parameter $ini is used to load configuration parameters
# e.g. $ob = Install->new('install.ini')
#
#-----------------------------------------------------------------------
sub new
{
	my $class = shift;
	my $ini = shift;
	
	my $self = {
		CONFIG => new InstallConfig(), # Stores configuration object with parameter information
	};
	bless $self, $class;

	if (defined($ini)) { # If given an ini file create config object from it
		$self->{'CONFIG'} = new InstallConfig($ini);
	} else { # create default config object
		$self->{'CONFIG'} = new InstallConfig();
	}

	return $self;
}
sub createFromConfig
{
	my $class = shift;
	my $config = shift;

	my $self = {
		CONFIG => $config, # Stores configuration object with parameter information
	};

	bless $self, $class;

	$self->init();	

	# override defaults with parameters passed
	if (ref($config) eq 'InstallConfig') {
		$self->getConfig()->initFromConfig($config->getParams());	
	} else {
		Environment::fatal("Install::createFromConfig: config parameter not of type \"InstallConfig\"\n");
	}

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");
	
	return $self;
}
#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise Install object
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



#############################################################
# GET/SET METHODS
#############################################################

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
# $name = $ob->db_ids()
# $ob->db_ids($name)
#-----------------------------------------------------------------------
#
# Get/set informix DB install file
#
#-----------------------------------------------------------------------
sub db_ids
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_ids'} = $name if defined($name);
	return $self->getConfigParams()->{'db_ids'};
}

#-----------------------------------------------------------------------
# $name = $ob->ts_ids()
# $ob->ts_ids($name)
#-----------------------------------------------------------------------
#
# Get/set TS for informix install file
#
#-----------------------------------------------------------------------
sub ts_ids
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ts_ids'} = $name if defined($name);
	return $self->getConfigParams()->{'ts_ids'};
}


#-----------------------------------------------------------------------
# $name = $ob->db_soliddb()
# $ob->db_soliddb($name)
#-----------------------------------------------------------------------
#
# Get/set solid DB install file
#
#-----------------------------------------------------------------------
sub db_soliddb
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_solid'} = $name if defined($name);
	return $self->getConfigParams()->{'db_solid'};
}

#-----------------------------------------------------------------------
# $name = $ob->ts_solid()
# $ob->ts_solid($name)
#-----------------------------------------------------------------------
#
# Get/set TS for solidDB install file
#
#-----------------------------------------------------------------------
sub ts_soliddb
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ts_soliddb'} = $name if defined($name);
	return $self->getConfigParams()->{'ts_soliddb'};
}



1;



=head1 NAME

Install - (super) class to implement install functionality

=head1 SYNOPSIS

use IBM::UC::Install;

#################
# class methods #
#################

 $ob = Install->new($ini);
   where:
     $ini=configuration file (optional parameter)

#######################
# object data methods #
#######################

### get versions ###

 
 $ini = $ob->getIniFileName()
 $cfg = $ob->getConfig()
 $cfg = $ob->getConfigParams()
 $name = $ob->db_soliddb()
 $host = $ob->ts_soliddb()
 $port = $ob->db_ids()
 $user = $ob->ts_ids()

### set versions ###

 
 $ob->db_soliddb('solid_pathname')
 $ob->ts_soliddb('ts_pathname')
 $ob->db_ids('ids_db_pathname')
 $ob->ts_ids('ts_pathname')
 

########################
# other object methods #
########################

 $ob->printout()		printout readable version of object's contents 
 				        (for debug purposes only)

=head1 DESCRIPTION

The Install class is intended for installing modules need to implement
TSs or Databases

=head1 EXAMPLES

=cut
