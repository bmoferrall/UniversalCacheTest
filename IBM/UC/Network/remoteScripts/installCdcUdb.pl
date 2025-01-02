use strict;
use warnings;

use IBM::UC::Environment;
use IBM::UC::CDC::CDCDb2;

my $envParams = {};
my $env       =
  Environment->createFromConfig(
	EnvironmentConfig->createFromHash($envParams) );

sub main {
	my ( $installFrom, $installTo, $remoteCdcSolidRootDir ) =
	  @ARGV;

	if ( $installFrom && $installTo && $remoteCdcSolidRootDir ) {
		Environment->getEnvironment()
		  ->CDCSolidRootDir( $remoteCdcSolidRootDir, 1 );

		CDCDb2::install( $installTo, $installFrom );
	}
}
main();
