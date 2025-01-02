use strict;
use warnings;

use IBM::UC::Environment;
use IBM::UC::Database::Db2DB;

my $envParams = {};
my $env       =
  Environment->createFromConfig(
	EnvironmentConfig->createFromHash($envParams) );

sub main {
	my ( $installFrom, $installTo, $remoteCdcSolidRootDir ) = @ARGV;

	if ( $installFrom && $installTo && $remoteCdcSolidRootDir ) {
		Environment->getEnvironment()
		  ->CDCSolidRootDir( $remoteCdcSolidRootDir, 1 );
		#TO DO - Defined wether log on as root should be done by the script
		#or by the fwk.
		Db2DB->install( $installTo, $installFrom );
	}
}
main();
