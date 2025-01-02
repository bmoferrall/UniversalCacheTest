#!/usr/bin/perl

use IO::Socket::INET;
use strict;



if (require Config) {
	if ($Config::Config{'osname'} =~ /^MSWin/i) {
		 launch_pad_client_pipe_win(@ARGV);
	} else {
		launch_pad_client_pipe_linux(@ARGV);
	}
} else {
	die "Cannot load Config module: $!";
}


#-----------------------------------------------------------------------
# launch_pad_client_pipe_linux($method[,parameterlist])
#-----------------------------------------------------------------------
#
# Launch client with method name and list of parameters (Linux version)
# Clients talks to server through a named pipe
# It sends a request to the server to invoke a server method
# Method name and parameters are passed from client as a single string
# Method name is separated from parameters by the pound sign
# Individual parameters are separated by an exclamation mark
# e.g. "install_solid£/home/db2inst1/bank_demo/!/home/db2inst1/soliddb-6.5"
#
#-----------------------------------------------------------------------
sub launch_pad_client_pipe_linux
{
	my $method = shift;
	my @params = @_;
	my $lpipe = $ENV{'HOME'} . '/launch_pad_server.pipe';
	my $ret_code;

	open(SYSFIFO, "> $lpipe") or die "launch_pad_client_linux: Can't open pipe for writing: $!";

	# Invoke server method by passing method name and parameters as string
	print SYSFIFO $method . '£' . join('!',@params);
	close(SYSFIFO);
	if ($method ne "stop_server") {
		open(SYSFIFO, "< $lpipe") or die "launch_pad_client_linux: Can't open pipe for reading: $!";
		while (1) { # wait for response from server
			$ret_code = <SYSFIFO>;
			last if (length($ret_code) > 0);
		}
		close SYSFIFO;
	}
	exit($ret_code);
}



#-----------------------------------------------------------------------
# launch_pad_client_pipe_win($method[,parameterlist])
#-----------------------------------------------------------------------
#
# Launch client with method name and list of parameters (Windows version)
# Clients talks to server through a named pipe
# It sends a request to the server to invoke a server method
# Method name and parameters are passed from client as a single string
# Method name is separated from parameters by the pound sign
# Individual parameters are separated by an exclamation mark
# e.g. "install_solid£/home/db2inst1/bank_demo/!/home/db2inst1/soliddb-6.5"
#
#-----------------------------------------------------------------------
sub launch_pad_client_pipe_win
{
	my $method = shift;
	my @params = @_;
	my $ret_code;
	my $lpipe;

	require Win32::Pipe or die "Cannot load required module Win32::Pipe: $!";

	$lpipe = new Win32::Pipe("\\\\.\\pipe\\launch_pad_server.pipe") 
		or die "Cannot connect to named pipe: $!\n";

	# Invoke server method by passing method name and parameters as string
	$lpipe->Write($method . '£' . join('!',@params));
	if ($method ne "stop_server") {
		while (1) { # wait for response from server
			$ret_code = $lpipe->Read();
			last if (length($ret_code) > 0);
		}
	}
	$lpipe->Close();
	exit($ret_code);
}


#-----------------------------------------------------------------------
# launch_pad_client($method[,parameterlist])
#-----------------------------------------------------------------------
#
# Connect to server using tcp socket
#
#-----------------------------------------------------------------------
sub launch_pad_client
{
	my $method = shift;
	my @params = @_;
	my $sock = new IO::Socket::INET (
		PeerAddr => 'localhost', 
		PeerPort => '7070', 
		Proto => 'tcp',
		Type => IO::Socket::SOCK_STREAM
	);
	my $ret_code;

	die "Could not create socket: $!\n" unless $sock; 
	#$sock->send("method£param1~param2");
	$sock->send($method . '£' . join('!',@params));
	if (defined($ret_code = <$sock>)) {
		print STDOUT $ret_code;
	}
	close($sock);
	exit($ret_code);
}


