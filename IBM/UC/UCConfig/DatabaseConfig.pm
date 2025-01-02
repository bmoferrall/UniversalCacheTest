########################################################################
# 
# File   :  DatabaseConfig.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# DatabaseConfig.pm stores Database configuration info
# 
########################################################################
package DatabaseConfig;

use strict;

use IBM::UC::UCConfig;
use UNIVERSAL qw(isa);

our @ISA = qw(UCConfig); # Config super class


# Valid parameters in user configuration file
my @VALIDPARAM = qw(db_inst db_dir db_dir_clean db_name db_host db_port
       	            db_user db_pass db_schema db_tbl_name db_type
               	    db_sql_output solid_lic solid_ini_template solid_db_inmemory);

# Required parameters in config file (for others, default values will be provided if unspecified)
my @REQUIREDP = qw(db_dir db_port);

# Valid database types
our @VALIDDBTYPES = qw(SOLID DB2 INFORMIX);

my $startConfigTag = '\[DATABASE\]'; # Start reading from this section
my $endConfigTag = '\[/DATABASE\]'; # Stop reading at this section


#-----------------------------------------------------------------------
# $ob = DatabaseConfig->new([$ini])
#-----------------------------------------------------------------------
# 
# Create DatabaseConfig object
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
# $ob = DatabaseConfig->createFromHash($hash)
#-----------------------------------------------------------------------
# 
# Create DatabaseConfig object from hash reference of parameter name/values
# e.g.
#	$db_parms = {
#		db_port => '2317', 
#		db_dir => 'sol_tgt',
#	};
#	$db_cfg = DatabaseConfig->createFromHash($db_parms);
#
#-----------------------------------------------------------------------
sub createFromHash
{
	my $class = shift;
	my $cfg = shift;
	my $self = $class->SUPER::new(\@VALIDPARAM,\@REQUIREDP,\$startConfigTag,\$endConfigTag);
	
	if (!defined($cfg) or (ref($cfg) ne 'HASH')) {
		Environment::fatal("DatabaseConfig::createFromConfig: expecting hash reference as parameter\nExiting...\n");
	} else {
		$self->initFromConfig($cfg);
	}
	bless $self, $class;
	
	return $self;
}


1;

=head1 NAME

DatabaseConfig - helper class (sub-class of Config) for Database module, loads and stores configuration info 
			for database.

=head1 SYNOPSIS

use IBM::UC::UCConfig::DatabaseConfig;

#################
# class methods #
#################

 $ob = DatabaseConfig->new($ini);
   where:
     $ini=configuration file (optional parameter)
 $ob = DatabaseConfig->createFromHash($cfg);
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

The DatabaseConfig class is a helper class for the Database module. It stores configuration information
(parameter name/value pairs) for use by its encapsulating class. Initialisation of the config 
object can be via a configuration file (initFromConfigFile()) or via a hash map reference
(initFromConfig($hashRef)).

=cut
