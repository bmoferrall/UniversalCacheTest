########################################################################
# 
# File   :  DatastoreConfig.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# DatastoreConfig.pm stores Datastore configuration info
# 
########################################################################
package DatastoreConfig;

use strict;

use IBM::UC::UCConfig;
use UNIVERSAL qw(isa);

our @ISA = qw(UCConfig); # Config super class


# Parameters recognised in user configuration file
my @VALIDPARAM = qw(ds_name ds_desc ds_host);

# Required parameters in config file (for others, default values will be provided if unspecified)
my @REQUIREDP = qw(ds_name ds_desc ds_host);

my $startConfigTag = '\[DATASTORE\]'; # Start reading from this section
my $endConfigTag = '\[/DATASTORE\]'; # Stop reading at this section


#-----------------------------------------------------------------------
# $ob = DatastoreConfig->new([$ini])
#-----------------------------------------------------------------------
# 
# Create DatastoreConfig object
# Can take ini file as optional parameter. Relevant section in ini file
# must start and end with $startConfigTag and $endConfigTag.
#
#-----------------------------------------------------------------------
sub new
{
	my $class = shift;
	my $ini = shift;
	my $self = $class->SUPER::new(\@VALIDPARAM,\@REQUIREDP,\$startConfigTag,\$endConfigTag,$ini);

	bless $self, $class;
	
	return $self;
}


#-----------------------------------------------------------------------
# $ob = DatastoreConfig->createFromHash($hash)
#-----------------------------------------------------------------------
# 
# Create DatastoreConfig object from hash reference of parameter name/values
# e.g.
#	$ds_parms = {
#		ds_name => 'soltgt_ds',
#		ds_desc => 'Target datastore',
#		ds_host => 'localhost',
#	};
#	$ds_cfg = DatastoreConfig->createFromHash($ds_parms);
#
#-----------------------------------------------------------------------
sub createFromHash
{
	my $class = shift;
	my $cfg = shift;
	my $self = $class->SUPER::new(\@VALIDPARAM,\@REQUIREDP,\$startConfigTag,\$endConfigTag);
	
	if (!defined($cfg) or (ref($cfg) ne 'HASH')) {
		Environment::fatal("TestBedConfig::createFromConfig: expecting hash reference as parameter\nExiting...\n");
	} else {
		$self->initFromConfig($cfg);
	}
	bless $self, $class;
	
	return $self;
}

1;

=head1 NAME

DatastoreConfig - helper class (sub-class of Config) for DataStore module, loads and stores configuration info 
			for Datastore instances.

=head1 SYNOPSIS

use IBM::UC::UCConfig::DatastoreConfig;

#################
# class methods #
#################

 $ob = DatastoreConfig->new($ini);
   where:
     $ini=configuration file (optional parameter)
 $ob = DatastoreConfig->createFromHash($cfg);
   where:
     $cfg=hash reference of parameter name/value pairs

#######################
# object data methods #
#######################

### get versions ###

see base class Config

### set versions ###

see base class Config

########################
# other object methods #
########################

see base class Config

=head1 DESCRIPTION

The DatastoreConfig class is a helper class for the Datastore module. It stores configuration information
(parameter name/value pairs) for use by its encapsulating class. Initialisation of the config 
object can be via a configuration file (initFromConfigFile()) or via a hash map reference
(initFromConfig($hashRef)).

=cut
