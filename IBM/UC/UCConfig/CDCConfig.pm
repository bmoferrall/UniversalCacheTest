########################################################################
# 
# File   :  CDCConfig.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# CDCConfig.pm stores CDC configuration info
# 
########################################################################
package CDCConfig;

use strict;

use IBM::UC::UCConfig;
use UNIVERSAL qw(isa);

our @ISA = qw(UCConfig); # Config super class


# Parameters recognised in user configuration file
my @VALIDPARAM = qw(ts_name ts_port ts_root ts_host ts_db_refresh_loader);

# Required parameters in config file (for others, default values will be provided if unspecified)
my @REQUIREDP = qw(ts_name ts_port);

my $startConfigTag = '\[CDC\]'; # Start reading from this section
my $endConfigTag = '\[/CDC\]'; # Stop reading at this section


#-----------------------------------------------------------------------
# $ob = CDCConfig->new([$ini])
#-----------------------------------------------------------------------
# 
# Create CDCConfig object
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
# $ob = CDCConfig->createFromHash($hash)
#-----------------------------------------------------------------------
# 
# Create CDCConfig object from hash reference of parameter name/values
# e.g.
#	$cdc_cfg = {
#		ts_name => 'solsrc_ts',
#   	ts_port => 11101,
#   };
#	$cdc_cfg = CDCConfig->createFromHash($cdc_parms);
#
#-----------------------------------------------------------------------
sub createFromHash
{
	my $class = shift;
	my $cfg = shift;
	my $self = $class->SUPER::new(\@VALIDPARAM,\@REQUIREDP,\$startConfigTag,\$endConfigTag);
	
	if (!defined($cfg) or (ref($cfg) ne 'HASH')) {
		Environment::fatal("CDCConfig::createFromConfig: expecting hash reference as parameter\nExiting...\n");
	} else {
		$self->initFromConfig($cfg);
	}
	bless $self, $class;
	
	return $self;
}


1;

=head1 NAME

CDCConfig - helper class (sub-class of Config) for CDC module, loads and stores configuration info 
			for CDC instances.

=head1 SYNOPSIS

use IBM::UC::UCConfig::CDCConfig;

#################
# class methods #
#################

 $ob = CDCConfig->new($ini);
   where:
     $ini=configuration file (optional parameter)
 $ob = CDCConfig->createFromHash($cfg);
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

The CDCConfig class is a helper class for the CDC module. It stores configuration information
(parameter name/value pairs) for use by its encapsulating class. Initialisation of the config 
object can be via a configuration file (initFromConfigFile()) or via a hash map reference
(initFromConfig($hashRef)).

=cut
