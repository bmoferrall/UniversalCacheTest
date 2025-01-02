########################################################################
# 
# File   :  CVS.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# CVS.pm encapsulates routines for interacting with CVS repositories
# 
########################################################################
package CVS;

use IBM::UC::Environment;
use Cwd;



#-----------------------------------------------------------------------
# $ob = CVS->new([$user,$pass,$repos,$clean])
#-----------------------------------------------------------------------
#
# Create CVS object, where:
# user=user name with access to cvs repository (optional)
# pass=password for user name (optional)
# repos=location of cvs repository (optional)
# clean=clean up option (optional)
# 
# Any parameters not supplied are initialsed (by init()) to Environment values
#
#-----------------------------------------------------------------------
sub new
{
	my $class = shift;
	my $self = {
		USER => shift,
		PASS => shift,
		REPOS => shift,
		CLEAN => shift,
	};
	bless $self, $class;

	$self->init();
	
	return $self;
}


#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise CVS object
# Defaults parameters from new() if not passed by user
#
#-----------------------------------------------------------------------
sub init
{
	my $self = shift;
	my $cmd;
	my $savecwd = Cwd::getcwd();

	if (!defined($self->cvsUser())) { $self->cvsUser($self->getEnv()->cvsUser()); }
	if (!defined($self->cvsPass())) { $self->cvsPass($self->getEnv()->cvsPass()); }
	if (!defined($self->cvsRepository())) { $self->cvsRepository($self->getEnv()->cvsRepository()); }
	if (!defined($self->cvsClean())) { $self->cvsClean(0); }

	chdir($self->getEnv()->cvsHome());
	$ENV{'CVSROOT'} = $self->getEnv()->cvsHome();
	$ENV{'TAG'} = $self->getEnv()->cvsTag();
	$ENV{'CVSUSER'} = $self->cvsUser();
	$ENV{'CVSREPOSITORY'} = $self->cvsRepository();

	Environment::logf("Initialising local CVS repository and logging in...\n");
	$cmd = sprintf("\"%s\" init", $self->getEnv()->cvsBin());
	Environment::logf(">>COMMAND: $cmd\n");
	system($cmd) and Environment::logf("Error occurred in CVS::init\n");

	$cmd = sprintf("\"%s\" -d %s login", $self->getEnv()->cvsBin(), $self->getEnv()->cvsRepository());
	Environment::logf(">>COMMAND: $cmd\n");
	system($cmd) and Environment::logf("Error occurred in CVS::init\n");

	chdir($savecwd);
}


#-----------------------------------------------------------------------
# $ob->checkout($dir_l,$dir_r[,$tag])
#-----------------------------------------------------------------------
#
# Checkout from CVS repository, where:
# dir_l=local directory/branch
# dir_r=remote directory/branch
# tag=branch tag name (optional)
#
#-----------------------------------------------------------------------
sub checkout
{
	my $self = shift;
	my ($dir_local,$dir_remote,$tag) = @_;
	my $cmd;

	Environment::fatal("Syntax: checkout(LOCALDIR,REMOTEDIR[,TAG])") 
		unless (defined($dir_remote) && defined($dir_local));
	$tag = $self->getEnv()->cvsTag() unless (defined($tag));

	$cmd = sprintf("\"%s\" -d %s checkout -d %s -r%s %s", 
					$self->getEnv()->cvsBin(),
					$self->getEnv()->cvsRepository(),
					$dir_local,$tag,$dir_remote);

	system($cmd) and Environment::logf("Error occurred in CVS::checkout\n");
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
# $ob->cvsUser($usr)
# $usr = $ob->cvsUser()
#-----------------------------------------------------------------------
#
# User name to access CVS repository
#
#-----------------------------------------------------------------------
sub cvsUser
{
	my ($self,$name) = @_;
	$self->{'USER'} = $name if defined($name);
	return $self->{'USER'};
}


#-----------------------------------------------------------------------
# $ob->cvsPass($pass)
# $pass = $ob->cvsPass()
#-----------------------------------------------------------------------
#
# Password for cvsUser()
#
#-----------------------------------------------------------------------
sub cvsPass
{
	my ($self,$name) = @_;
	$self->{'PASS'} = $name if defined($name);
	return $self->{'PASS'};
}


#-----------------------------------------------------------------------
# $ob->cvsRepository($repos)
# $repos = $ob->cvsRepository()
#-----------------------------------------------------------------------
#
# CVS repository location
#
#-----------------------------------------------------------------------
sub cvsRepository
{
	my ($self,$name) = @_;
	$self->{'REPOS'} = $name if defined($name);
	return $self->{'REPOS'};
}


#-----------------------------------------------------------------------
# $ob->cvsClean($clean)
# $clean = $ob->cvsClean()
#-----------------------------------------------------------------------
#
# Clean existing source and build files first
#
#-----------------------------------------------------------------------
sub cvsClean
{
	my ($self,$name) = @_;
	$self->{'CLEAN'} = $name if defined($name);
	return $self->{'CLEAN'};
}

1;



=head1 NAME

CVS - xxx

=head1 SYNOPSIS

use IBM::UC::Repository::CVS;

#################.
# class methods #.
#################.

 $ob = CVS->new([$user,$pass,$repository,$clean]);
  where:
   $user=User name to access repository (optional parameter)
   $pass=Password to access repository (optional parameter)
   $repository=CVS repository location (optional parameter)
   $clean=clean existing source and build files first (optional parameter)

The constructor creates an instance of the CVS class. All parameters are optional, but those present must be
in the order specified. Parameters not specified are defaulted to Environment.pm values.


#######################.
# object data methods #.
#######################.

### get versions ###

 $env = $ob->getEnv()
 $user = $ob->cvsUser()
 $pass = $ob->cvsPass()
 $repos = $ob->cvsRepository()
 $repos = $ob->cvsClean()

### set versions ###

 $ob->cvsUser($user)
 $ob->cvsPass($pass)
 $ob->cvsRepository($repos)
 $ob->cvsClean(1)


########################.
# other object methods #.
########################.

 $ob->checkout($dir_l,$dir_r[,$tag])	# Checkout from $dir_r (remote cvs branch location) to $dir_l
					# (local cvs location) using Tag $tag (optional parameter)
 
=head1 DESCRIPTION

The CVS module encapsulates routines for interacting with a CVS repository. For example, checkout() will
checkout a branch of source from the repository to a branch on the local machine.

=cut
