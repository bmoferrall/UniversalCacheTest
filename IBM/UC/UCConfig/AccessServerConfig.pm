########################################################################
# 
# File   :  AccessServerConfig.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# AccessServerConfig.pm stores Access Server configuration info
# 
########################################################################
package AccessServerConfig;

use strict;

use IBM::UC::UCConfig;
use UNIVERSAL qw(isa);

our @ISA = qw(UCConfig); # Config super class


# Parameters recognised in user configuration file
my @VALIDPARAM = qw(ac_host ac_port ac_user ac_pass);

# Required parameters in config file (for others, default values will be provided if unspecified)
my @REQUIREDP = qw(ac_host ac_port ac_user ac_pass);

my $startConfigTag = '\[ACCESSSERVER\]'; # Start reading from this section
my $endConfigTag = '\[/ACCESSSERVER\]'; # Stop reading at this section


#-----------------------------------------------------------------------
# $ob = AccessServerConfig->new([$ini])
#-----------------------------------------------------------------------
# 
# Create AccessServerConfig object
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
# $ob = AccessServerConfig->createFromHash($hash)
#-----------------------------------------------------------------------
# 
# Create AccessServerConfig object from hash reference of parameter name/values
# e.g.
#	$as_cfg = {ac_host => 'localhost',
#	  		   ac_port => '10101',
#			   ac_user => 'Admin',
#			   ac_pass => 'admin123'
#   };
#	$as_cfg = AccessServerConfig->createFromHash($as_parms);
#
#-----------------------------------------------------------------------
sub createFromHash
{
	my $class = shift;
	my $cfg = shift;
	my $self = $class->SUPER::new(\@VALIDPARAM,\@REQUIREDP,\$startConfigTag,\$endConfigTag);
	
	if (!defined($cfg) or (ref($cfg) ne 'HASH')) {
		Environment::fatal("AccessServerConfig::createFromConfig: expecting hash reference as parameter\nExiting...\n");
	} else {
		$self->initFromConfig($cfg);
	}
	bless $self, $class;
	
	return $self;
}

1;

=head1 NAME

AccessServerConfig - helper class (sub-class of Config) for AccessServer module, loads and stores 
			configuration info related to Access Server.

=head1 SYNOPSIS

use IBM::UC::UCConfig::AccessServerConfig;

#################
# class methods #
#################

 $ob = AccessServerConfig->new($ini);
   where:
     $ini=configuration file (optional parameter)
 $ob = AccessServerConfig->createFromHash($cfg);
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

The AccessServerConfig class is a helper class for the AccessServer module. It stores configuration information
(parameter name/value pairs) for use by its encapsulating class. Initialisation of the config 
object can be via a configuration file (initFromConfigFile()) or via a hash map reference
(initFromConfig($hashRef)).

=cut
