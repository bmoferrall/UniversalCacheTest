########################################################################
# 
# File   :  ConfigParser.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# ConfigParser.pm parses configuration files and stores name/value records
# in a hash
# 
########################################################################
package ConfigParser;

use strict;
use IBM::UC::Environment;

#-----------------------------------------------------------------------
# $ob = ConfigParser->new(\@VALIDP,\@REQUIREDP,\$STAG,\$ETAG)
#-----------------------------------------------------------------------
# 
# Create ConfigParser object
# where:
# VALIDP=reference to array of valid parameters
# REQUIREDP=reference to array of required parameters
# STAG=reference to (ini file) section start tag
# ETAG=reference to (ini file) section end tag
#
#-----------------------------------------------------------------------
sub new
{
	my $class = shift;
	my $self = {
		VALIDPARAM => shift, # Valid parameters in config file
		REQUIRED => shift, # Parameters required in config file
		STARTTAG => shift, # Where to start reading in config file
		ENDTAG => shift,   # Where to stop reading in config file
	};
	bless $self, $class;
	
	return $self;
}



#-----------------------------------------------------------------------
# $ob->parseFile($ini,$refParam)
#-----------------------------------------------------------------------
# 
# Parse ini file and load parameter values into hash, where:
# ini=ini file to read from
# refParam=reference to parameter hash where name/values will be stored
#
#-----------------------------------------------------------------------
sub parseFile
{
	my $self = shift; 
	my $ini = shift; # ini file to parse
	my $refParam = shift; # reference to parameter hash
	my $startTag = ${$self->{'STARTTAG'}};
	my $endTag = ${$self->{'ENDTAG'}};

	my @missing = ();
	my $line;
	my $param;
	my $value;

	open(CONFIG,'<',$ini) || 
		Environment::fatal("Can't open ini file \"$ini\" (specify full path if file is not in current dir): $!\n");

	if (!($self->moveTo(\*CONFIG,$startTag))) {
		close(CONFIG);
		Environment::fatal("Could not find $startTag in \"$ini\"\nExiting...\n");
	}
	#PARAM=VALUE
	while (defined($line = <CONFIG>) && ($line !~ m!^$endTag!i)) {
		if ($line =~ m/^[#;\/\s]/) {
			# ignore comment or blank line
		}
		elsif ($line =~ m/(\w+)=(.+?)[;\r\n]/) { # terminate value at comment or line end
			$param = $1;
			$value = $self->trim($2);
			if (!grep($param eq $_, @{$self->{'VALIDPARAM'}})) {
				close(CONFIG);
				Environment::fatal("Unrecognised parameter \"$param\" in $ini\nExiting...\n");
	 		}  
 			elsif ($value) {
		 		$refParam->{$param} = $value;
		 	}
		}
	}
	@missing = $self->checkMissing($refParam); 
	if (@missing) { 
		close(CONFIG);
		Environment::fatal("Following required parameter(s) not specified in \"$ini\":\n\t(@missing)\nExiting...\n\n"); 
		return 0; 
	} 
	close(CONFIG);
	return 1;
}


#-----------------------------------------------------------------------
# $ob->moveTo($fh,$tag)
#-----------------------------------------------------------------------
# 
# Move to line containing specififed tag in ini file, where:
# fh=filehandle to ini file
# stag=section tag to move to
# Returns true if tag is found, otherwise false
#
#-----------------------------------------------------------------------
sub moveTo
{
	my $self = shift;
	my $fh = shift;
	my $startTag = shift;
	my $line;

 	while (defined($line = <$fh>) && ($line !~ m!$startTag!i)) { }
	return defined($line);
}

	
# Make sure all required config parameters have been given a value
#-----------------------------------------------------------------------
# $ob->checkMissing($refParam)
#-----------------------------------------------------------------------
# 
# Makes sure all required config parameters have been initialised, where:
# refParam=hash reference of parameter name/value pairs
# Returns array of missing parameters
#
#-----------------------------------------------------------------------
sub checkMissing
{ 
	my $self = shift;
	my $refParam = shift;
	my %p; 

	foreach (keys %$refParam) { $p{$_}++; }
	return grep(!$p{$_}, @{$self->{'REQUIRED'}});
} 


# trim whitespace from start and end of string
#-----------------------------------------------------------------------
# $ob->trim($str)
#-----------------------------------------------------------------------
# 
# Trim whitespace from start and end of string
#
#-----------------------------------------------------------------------
sub trim
{
	my $self = shift;
	my $str = shift;
	$str =~ s/^\s+//;
	$str =~ s/\s+$//;
	return $str;
}


1;

=head1 NAME

ConfigParser - Parses configuration file and stores parameters and their values in hash map

=head1 SYNOPSIS

use IBM::UC::UCConfig::ConfigParser;

#################
# class methods #
#################

 $ob = ConfigParser->new(\@p,\@r,\$stag,\$etag);
   where:
     p=reference to array of valid parameters in configuration file
     r=reference to array of required parameters in config file (for which no default is specified)
     stag=start section tag in ini file
     etag=END section tag in ini file

#######################
# object data methods #
#######################

### get versions ###


### set versions ###
 

########################
# other object methods #
########################

 $ob->parseFile($ini,$refParam) 	# Parse specified ini file
  where:
   ini=config file to parse
   refParam=reference to hash of parameter name/value pairs

=head1 DESCRIPTION

The ConfigParser module will parse a section of a configuration ini file consisting of one or 
more NAME=VALUE records. NAME and VALUE for each record are stored in a hash map passed as 
reference to the parseFile routine.

=cut
