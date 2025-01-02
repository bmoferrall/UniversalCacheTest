########################################################################
# 
# File   :  Inet.pm
# History:  Apr-2010 (alg) module created as part of Test Automation
#			project
#
########################################################################
#
# Inet provides a network interface to deal with remote ends.
# 
########################################################################

package Inet;

use strict;
use warnings;

use Net::SSH::Perl;
use IBM::UC::Environment;

my $ssh;

#------------------------------------------------------------------------------
# $ssh = Inet::rsh_open($ip, $uid, $pwd)
#------------------------------------------------------------------------------
#
# Public.
# 
# Open a ssh tunel to the specified host and log onto this host using the 
# given credentials.
#
#------------------------------------------------------------------------------
sub rsh_open {
	my $ip  = shift;
	my $uid = shift;
	my $pwd = shift;

	Environment::logf "rsh open : ip = $ip - uid = $uid - pwd = $pwd\n";
	my %params = ( debug => "true", protocol => "2,1" );
	$ssh = Net::SSH::Perl->new( $ip, %params );
	$ssh->login( $uid, $pwd );
}

#------------------------------------------------------------------------------
# $ssh = Inet::rsh_close()
#------------------------------------------------------------------------------
#
# Public.
# Not implemented.
#------------------------------------------------------------------------------
sub rsh_close {
	Environment::logf "TO BE DEFINED - Inet::rsh_close\n";
}

#------------------------------------------------------------------------------
# $ssh = Inet::rsh_execute($command)
#------------------------------------------------------------------------------
#
# Public.
#
# Use the open connection and execute the given command on the remote host.
# Print out sdtout, stderr and the exit status from the command execution.
#
#------------------------------------------------------------------------------
sub rsh_execute {
	my $command = shift;

	Environment::logf "rsh execute : $command\n";
	my $out  = '';
	my $err  = '';
	my $exit = '';
	( $out, $err, $exit ) = $ssh->cmd("$command");
	Environment::logf "standard output from remote: $out\n";
	Environment::logf "error output from remote: $err\n";
	Environment::logf "exit status from remote: $exit\n";
}

#------------------------------------------------------------------------------
# ftp_connect()
#------------------------------------------------------------------------------
#
# Public.
# Not implemented.
#------------------------------------------------------------------------------
sub ftp_connect {
	Environment::logf "TO BE DEFINED - Inet::ftp_connect\n";
	
	my $ip = shift;
	my $uid = shift;
	my $pwd = shift;
	
	Environment::logf "ftp_connect : ip = $ip - uid = $uid - pwd = $pwd\n";
}

#------------------------------------------------------------------------------
# ftp_disconnect()
#------------------------------------------------------------------------------
#
# Public.
# Not implemented.
#------------------------------------------------------------------------------
sub ftp_disconnect {
	Environment::logf "TO BE DEFINED - Inet::ftp_disconnect\n";
}

sub ftp_put {
	Environment::logf "TO BE DEFINED - Inet::ftp_up\n";
	
	my $package = shift;
	
	Environment::logf "ftp_up : package = $package\n";
}

#------------------------------------------------------------------------------
# ftp_get()
#------------------------------------------------------------------------------
#
# Public.
# Not implemented.
#------------------------------------------------------------------------------
sub ftp_get {
	Environment::logf "TO BE DEFINED - Inet::ftp_down\n";
}

1;