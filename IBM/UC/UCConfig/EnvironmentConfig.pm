########################################################################
# 
# File   :  EnvironmentConfig.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# EnvironmentConfig.pm stores Environment configuration info
# 
########################################################################
package EnvironmentConfig;

use strict;

use IBM::UC::UCConfig;
use UNIVERSAL qw(isa);

our @ISA = qw(UCConfig); # Config super class
	
# Valid parameters in user configuration file
my @VALIDPARAM = qw(debug log_file log_file_name smtp_server email_admin email_on_error start_dir os_name
					cvs_user cvs_pass cvs_repository cvs_bin cvs_home cvs_tag 
					ant_version cdc_solid_root_dir cdc_db2_root_dir cdc_bits cdc_informix_root_dir
		    		access_server_root_dir solid_package solid_root_dir solid_licence_file
		    		testbed_envname testbed_bucket testbed_head_dir testbed_qa_approved_dir 
		    		java_home java6_home mssdk_home dotnetsdk_home vstudio_home);

# Required parameters in config file (for others, default values will be provided if unspecified)
my @REQUIREDP = qw(cdc_solid_root_dir cdc_db2_root_dir access_server_root_dir 
		   			solid_root_dir solid_licence_file java_home);

my $startConfigTag = '\[ENVIRONMENT\]'; # Start reading from this section
my $endConfigTag = '\[/ENVIRONMENT\]'; # Stop reading at this section


#-----------------------------------------------------------------------
# $ob = EnvironmentConfig->new([$ini])
#-----------------------------------------------------------------------
# 
# Create EnvironmentConfig object
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
# $ob = EnvironmentConfig->createFromHash($hash)
#-----------------------------------------------------------------------
# 
# Create EnvironmentConfig object from hash reference of parameter name/values
# e.g.
#	$env_parms = {
#		debug => 1,
#		smtp_server => 'D06DBE01',
#		cvs_user => 'dmbuild',
#		cvs_pass => 'dmbuild',
#		cvs_repository => ':pserver:dmbuild:dmbuild@dmccvs.torolab.ibm.com:/home/cvsuser/cvsdata',
#		cvs_home => '/home/db2inst1/cvs',
#		cvs_tag => 'HEAD',
#		cdc_solid_root_dir => '/home/db2inst1/Transformation Server for solidDB/',
#	};
#	$env_cfg = EnvironmentConfig->createFromHash($env_parms);
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

EnvironmentConfig - helper class (sub-class of Config) for Environment module, loads and stores 
			environment-specific configuration info.

=head1 SYNOPSIS

use IBM:UC::UCConfig::EnvironmentConfig;

#################
# class methods #
#################

 $ob = EnvironmentConfig->new($ini);
   where:
     $ini=configuration file (optional parameter)
 $ob = EnvironmentConfig->createFromHash($cfg);
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

The EnvironmentConfig class is a helper class for the Environment module. It stores configuration information
(parameter name/value pairs) for use by an Environment object. Initialisation of the config 
object can be via a configuration file (initFromConfigFile()) or via a hash map reference
(initFromConfig($hashRef)).

=cut
