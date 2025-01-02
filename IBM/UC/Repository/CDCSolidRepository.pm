########################################################################
# 
# File   :  CDCSolidRepository.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# CDCSolidRepository.pm is used to build the latest version of CDC for 
# Solid from its source in the CVS repository
# 
########################################################################
package CDCSolidRepository;

use strict;
use IBM::UC::Environment;
use IBM::UC::Repository::CVS;
use File::Path;


#-----------------------------------------------------------------------
# $ob = CDCSolidRepository->new([$user,$pass,$repos,$clean])
#-----------------------------------------------------------------------
#
# Create CDCSolidRepository object, where:
# user=user name with access to cvs repository (optional)
# pass=password for user name (optional)
# repos=location of cvs repository (optional)
# clean=clean up option (optional)
# 
# Any parameters not supplied are initialised in the CVS module
#
#-----------------------------------------------------------------------
sub new
{
	my $class = shift;
	my $self = {
		CVS => CVS->new(@_),
	};
	bless $self, $class;
	
	$self->init();
	
	return $self;
}


#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise CDCSolidRepository object
# Initialises some environment variables for use by the ant utility
#
#-----------------------------------------------------------------------
sub init
{
	my $self = shift;
	my $es = $self->getEnv()->getEnvSeparator();
	my $ps = $self->getEnv()->getPathSeparator();

	# Set some environment variables that the Ant compiler needs
	$ENV{'MSSDK_HOME'} = $self->getEnv()->msSdkHome();
	$ENV{'DOTNETSDK_HOME'} = $self->getEnv()->dotNetSdkHome();
	$ENV{'VSTUDIO_HOME'} = $self->getEnv()->vstudioHome();
	$ENV{'JAVA_HOME'} = $self->getEnv()->javaHome();
	$ENV{'JAVA6_HOME'} = $self->getEnv()->javaSixHome();
	$ENV{'PATH'} = $ENV{'JAVA6_HOME'} . 'bin' . $es . $ENV{'PATH'};
	# initialise VStudio environment
	if ($self->getEnv()->getOSName() eq 'windows') {
		system("\"${\$self->getEnv()->vstudioHome()}${ps}vc${ps}vcvarsall.bat\"");
	}
}


#-----------------------------------------------------------------------
# $ob->copy()
#-----------------------------------------------------------------------
#
# Copy CDC Solid source from repository
#
#-----------------------------------------------------------------------
sub copy
{
	my $self = shift;

	chdir($self->getEnv()->cvsHome());	
	# Checkout ant compiler
	$self->getCvs()->checkout($self->getEnv()->antVersion(),'Shared/tools/'.$self->getEnv()->antVersion());
	# Checkout java engine
	$self->getCvs()->checkout('javaEngine','Integration/TS/V5/javaEngine');

	chdir('javaEngine');
	# CDC Solid source
	$self->getCvs()->checkout('tsJava','Integration/TS/V5/tsJava');
	$self->getCvs()->checkout('Shared','Shared');
	$self->getCvs()->checkout('dbtrans','Integration/DBXML/dbtrans');

	chdir('..');
	# JVMS
	$self->getCvs()->checkout('ibmjvms','ibmjvms');
}


#-----------------------------------------------------------------------
# $ob->build()
#-----------------------------------------------------------------------
#
# Build CDC Solid from source and install to target location
#
#-----------------------------------------------------------------------
sub build
{
	my $self = shift;
	my $command;
	my $dir;
	my $ps = $self->getEnv()->getPathSeparator();
	my $es = $self->getEnv()->getEnvSeparator();
	my $pname = ($self->getEnv()->getOSName() eq 'windows') ? 'windowspackage' : 'unixpackage';
	my $build_name = ($self->getEnv()->getOSName() eq 'windows') ? 'windows' : 'linux';
	my $clean = $self->getCvs()->cvsClean() ? 'clean ' : '';

	$dir = $self->getEnv()->cvsHome();
	chdir($dir. "${ps}javaEngine");
	$ENV{'ANT_HOME'} = $dir.$ps.$self->getEnv()->antVersion();
	$ENV{'PATH'} = $ENV{'ANT_HOME'} . "${ps}bin${es}" . $ENV{'PATH'};
	$command = "ant ${clean}compile ${pname} -Ddbms=solid -DjvmsCheckOutDir=. -DjvmsCheckOutLocation="
				. $self->getEnv()->cvsHome();
	Environment::logf("COMMAND: $command\n");
	system($command);# and Environment::logf("Error occurred in CDCSolidRepository::build\n");

	# Remove existing cdc solid installation
	#File::Path::rmtree($self->getEnv()->CDCSolidRootDir(),0,1);
	mkdir($self->getEnv()->CDCSolidRootDir());

	# Copy 'ship' branch of new build to CDC Solid directory
	$command = "${dir}${ps}javaEngine${ps}build-output${ps}${build_name}${ps}x86${ps}ship";
	if (require File::Copy::Recursive) {
		File::Copy::Recursive::dircopy($command, $self->getEnv()->CDCSolidRootDir());
	} else {
		Environment::fatal("Unable to finish install as File::Copy::Recursive module cannot be found\n");
	}
}




#############################################################
# GET/SET METHODS
#############################################################

#-----------------------------------------------------------------------
# $env = $ob->getEnv()
#-----------------------------------------------------------------------
#
# Get environment instance
#
#-----------------------------------------------------------------------
sub getEnv
{
	my $self = shift;
	return Environment::getEnvironment();
}


#-----------------------------------------------------------------------
# $cvs = $ob->getCvs()
#-----------------------------------------------------------------------
#
# Return CVS object created in constructor
#
#-----------------------------------------------------------------------
sub getCvs
{
	my $self = shift;
	return $self->{'CVS'};
}


1;


=head1 NAME

CDCSolidRepository - used to build the latest version of CDC for Solid from its source in the CVS repository

=head1 SYNOPSIS

use IBM::UC::Repository::CDCSolidRepository;

#################.
# class methods #.
#################.

 $ob = CDCSolidRepository->new($user,$pass,$repository,$clean);
  where:
   $user=User name to access repository (optional parameter)
   $pass=Password to access repository (optional parameter)
   $repository=CVS repository location (optional parameter)
   $clean=clean existing source and build files first (optional parameter)

The constructor creates an instance of the class CVS. It passes its parameters on to the CVS constructor.
Parameters not specified are defaulted in the CVS instance.


#######################.
# object data methods #.
#######################.

### get versions ###

 $env = $ob->getEnv()
 $cvs = $ob->getCvs()

### set versions ###


########################.
# other object methods #.
########################.

 $ob->copy()	# Copy CDC Solid source (also copies Ant utility across)
 $ob->build()	# Build CDC Solid and move to target directory
 
=head1 DESCRIPTION

The CDCSolidRepository module copies the latest version of CDC for Solid from its source in the CVS repository, builds it
and copies the build to the target installation directory.

=cut
