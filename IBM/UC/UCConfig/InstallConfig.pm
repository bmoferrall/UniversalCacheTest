########################################################################
# 
# File   :  InstallConfig.pm
# History:  Apr-2010 (cg) module created as part of Test Automation
#			project
#
########################################################################
#
# InstallConfig.pm stores Install configuration info
# 
########################################################################
package InstallConfig;

use strict;

use IBM::UC::UCConfig;
use UNIVERSAL qw(isa);

our @ISA = qw(UCConfig); # Config super class


# Valid parameters in user configuration file
my @VALIDPARAM = qw(db_ids db_solid db_udb ts_ids ts_soliddb ts_udb);

# Required parameters in config file (for others, default values will be provided if unspecified)
my @REQUIREDP;

# Valid database types
our @VALIDDBTYPES = qw(SOLID DB2 INFORMIX);

my $startConfigTag = '\[INSTALL\]'; # Start reading from this section
my $endConfigTag = '\[/INSTALL\]'; # Stop reading at this section


#-----------------------------------------------------------------------
# $ob = InstallConfig->new([$ini])
#-----------------------------------------------------------------------
# 
# Create InstallConfig object
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
# $ob = InstallConfig->createFromHash($hash)
#-----------------------------------------------------------------------
# 
# Create InstallConfig object from hash reference of parameter name/values
# e.g.
#	$install_parms = {
#		db_ids => 'informix.exe', 
#		db_solid => 'solid.exe',
#	};
#	$db_cfg = InstallConfig->createFromHash($install_parms);
#
#-----------------------------------------------------------------------
sub createFromHash
{
	my $class = shift;
	my $cfg = shift;
	my $self = $class->SUPER::new(\@VALIDPARAM,\@REQUIREDP,\$startConfigTag,\$endConfigTag);
	
	if (!defined($cfg) or (ref($cfg) ne 'HASH')) {
		Environment::fatal("InstallConfig::createFromConfig: expecting hash reference as parameter\nExiting...\n");
	} else {
		$self->initFromConfig($cfg);
	}
	bless $self, $class;
	
	return $self;
}


1;

=head1 NAME

InstallConfig - helper class (sub-class of Config) for Install module, loads and stores configuration info 
			for install.

=head1 SYNOPSIS

use IBM::UC::UCConfig::InstallConfig;

#################
# class methods #
#################

 $ob = InstallConfig->new($ini);
   where:
     $ini=configuration file (optional parameter)
 $ob = InstallConfig->createFromHash($cfg);
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

The InstallConfig class is a helper class for the Install module. It stores configuration information
(parameter name/value pairs) for use by its encapsulating class. Initialisation of the config 
object can be via a configuration file (initFromConfigFile()) or via a hash map reference
(initFromConfig($hashRef)).

=cut
