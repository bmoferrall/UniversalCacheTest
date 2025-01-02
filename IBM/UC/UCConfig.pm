########################################################################
# 
# File   :  UCConfig.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# UCConfig.pm is a config super-class which loads and stores configuration 
# info (parameter name/value pairs).
# 
########################################################################
package UCConfig;

use strict;

use IBM::UC::UCConfig::ConfigParser;
use Data::Dumper;



#-----------------------------------------------------------------------
# $ob = UCConfig->new(\@VALIDP,\@REQUIREDP,\$STAG,\$ETAG[,$ini])
#-----------------------------------------------------------------------
# 
# Create UCConfig object
# where:
# VALIDP=reference to array of valid parameters
# REQUIREDP=reference to array of required parameters
# STAG=reference to (ini file) section start tag
# ETAG=reference to (ini file) section end tag
# INI=ini file name (optional)
#
#-----------------------------------------------------------------------
sub new
{
	my $class = shift;
	my $self = {
		VALIDPARAM => shift, # array of valid parameters
		REQUIREDP => shift, # array of required parameters
		STAG => shift, # start section tag
		ETAG => shift, # end section tag
		INIFILE  => shift, # Ini file to load (optional parameter)
		PARAMS => {}, # Hash of parameters and their values
	};
	bless $self, $class;
	
	return $self;
}


#-----------------------------------------------------------------------
# $ob->initFromConfig($refHash)
#-----------------------------------------------------------------------
# 
# Initialise config object with hash reference of parameter name/value
# pairs, e.g.
#	my $config_db2 = DatabaseConfig->new();
#	my $config_values_db2 = { 
#		db_name => 'test', 
#		db_dir => 'test', 
#		db_user => 'user', 
#		db_pass => 'pass',
#		db_tbl_name => 'table',
#	};
#	$config_db2->initFromConfig($config_values_db2);
#
#-----------------------------------------------------------------------
sub initFromConfig
{
	my $self = shift;
	my $refHash = shift;
	my $key;
	
	foreach $key (keys %$refHash) {
		if (grep($key eq $_, @{$self->{'VALIDPARAM'}})) {
			$self->getParams()->{$key} = $$refHash{$key};
		} else {
			$self->printout();
			Environment::fatal("\nERROR: \"$key\" not a valid parameter. Valid parameters:\n(@{$self->{'VALIDPARAM'}})\n\n");
		}
	}
}


#-----------------------------------------------------------------------
# $ob->initFromConfigFile([$sTag,$eTag])
#-----------------------------------------------------------------------
# 
# Initialise config object with parameter name/value records in ini file
# where:
# $sTag=start section tag (overrides default set in new())
# $eTag=end section tag (overrides default set in new())
# e.g.
#	my $config_db2 = DatabaseConfig->new('config.ini');
#	$config_db2->initFromConfigFile();
#
#-----------------------------------------------------------------------
sub initFromConfigFile
{
	my $self = shift;
	my $ini = $self->getIniFile();
	my $sTag = $_[0] ? \$_[0] : $self->{'STAG'};
	my $eTag = $_[1] ? \$_[1] : $self->{'ETAG'};
		
	my $parser = new ConfigParser($self->{'VALIDPARAM'},$self->{'REQUIREDP'},$sTag,$eTag);
	$parser->parseFile($ini,$self->getParams());
}


#-----------------------------------------------------------------------
# $ob->checkRequired()
#-----------------------------------------------------------------------
# 
# Checks that all required parameters in config object have been initialised
#
#-----------------------------------------------------------------------
sub checkRequired
{
	my $self = shift;
	my $ret = 1;

	foreach (@{$self->{'REQUIREDP'}}) {
		if (!defined($self->getParams()->{$_})) { 
			if ($ret) { $self->printout(); }
			print "Required parameter '$_' not defined in Config\n";
			$ret = 0;
		}
	}
	return $ret;
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
	
	print Dumper($self);
}


#############################################################
# GET/SET METHODS
#############################################################


#-----------------------------------------------------------------------
# $ini = $ob->getIniFile()
#-----------------------------------------------------------------------
#
# Get configuration ini file name
#
#-----------------------------------------------------------------------
sub getIniFile
{
	my $self = shift;
	return $self->{'INIFILE'};
}

#-----------------------------------------------------------------------
# $ini = $ob->getParams()
#-----------------------------------------------------------------------
#
# Get reference to hash with parameter name/value pairs
#
#-----------------------------------------------------------------------

sub getParams
{
	my $self = shift;
	return $self->{'PARAMS'};
}


1;

=head1 NAME

UCConfig - config super-class which loads and stores configuration info (parameter name/value pairs).

=head1 SYNOPSIS

use IBM::UC::UCConfig;

#################
# class methods #
#################

 $ob = UCConfig->new($v,$r,$s,$e,$ini);
   where:
     $v=reference to array of valid config parameter names
     $r=reference to array of required config parameters names
     $s=section-start tag in configuration file
     $e=section-end tag in configuration file
     $ini=configuration file (optional parameter)

#######################
# object data methods #
#######################

### get versions ###

 $ini = getIniFile()   Name of configuration file
 $h = getParams()      Returns hash reference of parameter/value pairs from configuration file

### set versions ###

 

########################
# other object methods #
########################

 $ob->initFromConfig($hr)   Initialises object data with name/value pairs (via hash reference)
 $ob->initFromConfigFile()  Load configuration file
 $ob->checkRequired()	    Check that all required parameters have been initialised

=head1 DESCRIPTION

The UCConfig class is a super-class defining common functionality for configuration objects.
It stores configuration information (parameter name/value pairs) for use by its encapsulating class.
Initialisation of the config object can be via a configuration file (initFromConfigFile()) or via a 
hash map reference (initFromConfig($hashRef)).

=cut
