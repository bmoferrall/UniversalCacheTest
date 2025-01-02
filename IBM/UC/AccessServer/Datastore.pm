########################################################################
# 
# File   :  Datastore.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# Datastore.pm encapsulates the properties of a datastore
# 
########################################################################
package Datastore;
 
use strict;
use IBM::UC::Environment;
use IBM::UC::UCConfig::DatastoreConfig;


#-----------------------------------------------------------------------
# $ds = Datastore->createSimple($name,$desc,$host,$cdc)
#-----------------------------------------------------------------------
#
# Instantiates an object of class Datastore from simple parameters.
# Parameters are datastore name, datastore description, datastore host,
# and CDC instance associated with datastore, e.g.
# Datastore->createSimple('src_ds','Source','localhost',$cdc)
#
#-----------------------------------------------------------------------
sub createSimple
{
	my $class = shift;
	my $ds_name = shift;
	my $ds_desc = shift;
	my $ds_host = shift;
	my $cdc = shift;
	my $self = {
		CONFIG => DatastoreConfig->new(), # Datastore configuration object
		CDC => $cdc, # cdc instance associated with this datastore
		USER => undef, # user assigned to this datastore
	};
	bless $self, $class;


	# Make sure we get valid cdc object as input
	if (!defined($cdc)) {
		fatal("Datastore::createSimple requires cdc instance as 4th parameter\nExiting...\n");
	} elsif (!$cdc->isa('CDC')) {
		fatal("Datastore::createSimle: 4th parameter not of type \"CDC\"\nExiting...\n");
	}
	
	# Make sure we get valid ds configuration as first parameter
	if (!defined($ds_host)) {
		fatal("Datastore::createSimple requires datastore host as 3rd parameter\nExiting...\n");
	} elsif (!defined($ds_desc)) {
		fatal("Datastore::createSimple: requires datastore description as 2nd parameter\nExiting...\n");
	} elsif (!defined($ds_name)) {
		fatal("Datastore::createSimple: requires datastore name as 1st parameter\nExiting...\n");
	}
	$self->init(); # set defaults

	# override defaults with parameters passed
	$self->datastoreName($ds_name);
	$self->datastoreDesc($ds_desc);
	$self->datastoreHost($ds_host);

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or 
		fatal("Datastore::new: Error(s) occurred. Exiting...\n");

	return $self;
}


#-----------------------------------------------------------------------
# $ds = Datastore->createFromConfig($cfg,$cdc)
#-----------------------------------------------------------------------
#
# Instantiates an object of class Datastore.
# Parameters are a config object of class DatastoreConfig and the CDC instance 
# associated with datastore, e.g.
# $ds_vals = { ds_name => 'src_ds', ds_desc => 'source', ds_host => 'localhost' }
# Datastore->createFromConfig(DatastoreConfig->createFromHash($ds_vals),$cdc)
#
#-----------------------------------------------------------------------
sub createFromConfig
{
	my $class = shift;
	my $ds_cfg = shift;
	my $cdc = shift;
	my $self = {
		CONFIG => DatastoreConfig->new(), # Datastore configuration object
		CDC => $cdc, # cdc instance associated with this datastore
		USER => undef, # user assigned to this datastore
	};
	bless $self, $class;
	
	# Make sure we get valid ds configuration as first parameter
	if (!defined($ds_cfg)) {
		fatal("Datastore::createFromConfig requires Datastore configuration as 1st parameter\nExiting...\n");
	} elsif (ref($ds_cfg) ne 'DatastoreConfig') {
		fatal("Datastore::createFromConfig: Datastore configuration not of type \"DatastoreConfig\"\nExiting...\n");
	}
	
	# Make sure we get valid cdc object as input
	if (!defined($cdc)) {
		fatal("Datastore::createFromConfig requires cdc instance as 2nd parameter\nExiting...\n");
	} elsif (!$cdc->isa('CDC')) {
		fatal("Datastore::createFromConfig: 2nd parameter not of type \"CDC\"\nExiting...\n");
	}

	$self->init(); # set defaults

	# override defaults with parameters passed
	$self->getConfig()->initFromConfig($ds_cfg->getParams());	

	# Check that config is fully initialised	
	$self->getConfig()->checkRequired() or 
		fatal("Datastore::new: Error(s) occurred. Exiting...\n");

	return $self;
}



#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise Datastore object parameters with default values
#
#-----------------------------------------------------------------------
sub init
{
	my $self = shift;

	# Make sure we only initialise once,
	#    in case a user explicitly calls what is intended to be a private method
	if (!$self->initialised()) { 
		# Initialise some config parameters to default values
		$self->getConfig()->initFromConfig({ds_name => 'src_ds',
											ds_desc => 'Source datastore',
											ds_host => 'localhost'});

		$self->initialised(1);
	}
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
# Get configuration object (class CDCConfig)
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
# $name = $ob->datastoreName()
# $ob->datastoreName($name)
#-----------------------------------------------------------------------
#
# Get/set datastore name
#
#-----------------------------------------------------------------------
sub datastoreName
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ds_name'} = $name if defined($name);
	return $self->getConfigParams()->{'ds_name'};
}


#-----------------------------------------------------------------------
# $desc = $ob->datastoreDesc()
# $ob->datastoreDesc($desc)
#-----------------------------------------------------------------------
#
# Get/set datastore description
#
#-----------------------------------------------------------------------
sub datastoreDesc
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ds_desc'} = $name if defined($name);
	return $self->getConfigParams()->{'ds_desc'};
}


#-----------------------------------------------------------------------
# $host = $ob->datastoreHost()
# $ob->datastoreHost($host)
#-----------------------------------------------------------------------
#
# Get/set datastore host
#
#-----------------------------------------------------------------------
sub datastoreHost
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'ds_host'} = $name if defined($name);
	return $self->getConfigParams()->{'ds_host'};
}

#-----------------------------------------------------------------------
# $name = $ob->datastoreUser()
# $ob->datastoreUser($name)
#-----------------------------------------------------------------------
#
# Get/set user assigned to datastore
#
#-----------------------------------------------------------------------
sub datastoreUser
{
	my ($self,$name) = @_;
	$self->{'USER'} = $name if defined($name);
	return $self->{'USER'};
}


#-----------------------------------------------------------------------
# $cdc = $ob->getCdc()
#-----------------------------------------------------------------------
#
# Get CDC instance associated with datastore
#
#-----------------------------------------------------------------------
sub getCdc
{
	my $self = shift;
	return $self->{'CDC'};
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

Datastore - Class to encapsulate datastore properties

=head1 SYNOPSIS

use IBM::UC::AccessServer::Datastore;

#################
# class methods #
#################

 $ob = Datastore->createSimple($ds_name,$ds_desc,$ds_host,$cdc);
   where:
     $ds_name=datastore name
     $ds_desc=datastore description
     $ds_host=datastore host
     $cdc=cdc instance associated with datastore
 $ob = Datastore->createFromConfig($ds_cfg,$cdc);
   where:
     $ds_cfg=configuration object of class DatastoreConfig, describing datastore
     $cdc=cdc instance associated with datastore

#######################
# object data methods #
#######################

### get versions ###

 $nm = $ob->datastoreName()	# Name of datastore
 $desc = $ob->datastoreDesc()	# Description of datastore
 $host = $ob->datastoreHost()	# Host name of datastore
 $user = $ob->datastoreUser()	# User assigned to datastore
 $cdc = $ob->getCdc()		# CDC object associated with datastore

### set versions ###

 $ob->datastoreName('dsname')
 $ob->datastoreDesc('Description')
 $ob->datastoreHost('localhost')
 $ob->datastoreUser('Admin')

########################
# other object methods #
########################


=head1 DESCRIPTION

The Datastore module encapsulates the properties of a datastore.

Initialisation of the Datastore object's data can be done in several ways. Default values are used for 
object parameters not explicitly specified in the object's creation.

Valid configuration parameters and their default values follow (see DatastoreConfig.pm):

 ---------------------------------------------------------------------------------------------------------
 Parameter			Description				Default value
 ---------------------------------------------------------------------------------------------------------
 ds_name			Datastore name				src_ds
 ds_desc			Datastore description			source
 ds_host			Datastore host				localhost
 ---------------------------------------------------------------------------------------------------------

if initialisation is via a configuration ini file the Datastore section must, by default, start with [DATASTORE]
and end with [/DATASTORE] or end of file, e.g.:

 [DATASTORE]

 ; Instance name for transformation server
 ds_name=solsrc_ds

 ; Communication port for transformation server
 ds_desc=Source datastore

 ; Communication port for transformation server
 ds_host=localhost

=cut
