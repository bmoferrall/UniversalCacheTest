package NetworkNodeConfig;

use strict;

use IBM::UC::UCConfig;
use UNIVERSAL qw(isa);

our @ISA = qw(UCConfig); # Config super class

# Parameters recognised in user configuration file
my @VALIDPARAM = qw(ip uid pwd frameworkPath rScriptsPath remoteCdcSolidRootDir);

# Required parameters in config file (for others, default values will be provided if unspecified)
my @REQUIREDP = qw(ip uid pwd frameworkPath rScriptsPath remoteCdcSolidRootDir);

my $startConfigTag = '\[CDC\]'; # Start reading from this section
my $endConfigTag = '\[DATASTORE\]'; # Stop reading at this section

#-----------------------------------------------------------------------
# $ob = cdcConfig->new([$ini])
#-----------------------------------------------------------------------
# 
# Create cdcConfig object
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
# $ob = cdcConfig->createFromHash($hash)
#-----------------------------------------------------------------------
# 
# Create cdcConfig object from hash reference of parameter name/values
# e.g.
#	$cdc_cfg = {
#		ts_name => 'solsrc_ts',
#   	ts_port => 11101,
#   };
#	$cdc_cfg = cdcConfig->createFromHash($cdc_parms);
#
#-----------------------------------------------------------------------
sub createFromHash
{
	my $class = shift;
	my $cfg = shift;
	my $self = $class->SUPER::new(\@VALIDPARAM,\@REQUIREDP,\$startConfigTag,\$endConfigTag);

	if (!defined($cfg) or (ref($cfg) ne 'HASH')) {
		Environment::fatal("CDCRemoteConfig::createFromConfig: expecting hash reference as parameter\nExiting...\n");
	} else {
		$self->initFromConfig($cfg);
	}
	bless $self, $class;

	return $self;
}


1;
