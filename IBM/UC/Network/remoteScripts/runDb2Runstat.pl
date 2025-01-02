use strict;
use warnings;

use IBM::UC::Environment;

my $envParams = {};
my $env = Environment->createFromConfig( EnvironmentConfig->createFromHash($envParams) );

sub main {
	my ( $table, $dbName, $db2User, $db2Pass ) = @ARGV;

	if ( $table && $dbName && $db2User && $db2Pass ) {
		my $command = "db2 connect to " . $dbName;
		system($command);

		$command = "db2 RUNSTATS ON TABLE " . $table . " WITH DISTRIBUTION AND DETAILED INDEXES ALL";
		system($command);

		$command = "db2 connect reset";
		system($command);
	}
}
main();
