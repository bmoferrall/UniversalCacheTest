########################################################################
# 
# File   :  TestBedConfig.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# TestBedConfig.pm stores Testbed configuration info
# 
########################################################################
package TestBedConfig;

use strict;

use IBM::UC::UCConfig;
use UNIVERSAL qw(isa);

our @ISA = qw(UCConfig); # Config super class


# Parameters recognised in user configuration file
my @VALIDPARAM = qw(tb_user tb_test_single tb_test_list tb_email tb_clean tb_prefix tb_cmd_opt);

# Required parameters in config file (for others, default values will be provided if unspecified)
my @REQUIREDP = qw(tb_user);

my $startConfigTag = '\[TESTBED\]'; # Start reading from this section
my $endConfigTag = '\[/TESTBED\]'; # Stop reading at this section


#-----------------------------------------------------------------------
# $ob = TestBedConfig->new([$ini])
#-----------------------------------------------------------------------
# 
# Create TestBedConfig object
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
# $ob = TestBedConfig->createFromHash($hash)
#-----------------------------------------------------------------------
# 
# Create TestBedConfig object from hash reference of parameter name/values
# e.g.
#	$tb_parms = {tb_user => 'mooreof', # user name
#				 tb_test_single => 'V46_MirrorContinuous_9999', # single test name 
#				 tb_test_list => '', # list name (to contain list of tests to run)
#				 tb_email => 'mooreof@ie.ibm.com', # email to receive report
#				 tb_clean => 1, # Testbed clean up option
#				 tb_prefix => 'TB', # Testbed prefix (2-character)
#	};
#	$tb_cfg = TestBedConfig->createFromHash($tb_parms);
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

TestBedConfig - helper class (sub-class of Config) for TestBed module, loads and stores configuration info 
			for TestBed instances.

=head1 SYNOPSIS

use IBM::UC::UCConfig::TestBedConfig;

#################
# class methods #
#################

 $ob = TestBedConfig->new($ini);
   where:
     $ini=configuration file (optional parameter)
 $ob = TestBedConfig->createFromHash($cfg);
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

The TestBedConfig class is a helper class for the TestBed module. It stores configuration information
(parameter name/value pairs) for use by its encapsulating class. Initialisation of the config 
object can be via a configuration file (initFromConfigFile()) or via a hash map reference
(initFromConfig($hashRef)).

=cut
