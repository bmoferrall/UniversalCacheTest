use strict;
use warnings;

use IBM::UC::Environment;
use IBM::UC::CDC::CDCDb2;

my $envParams = {};
my $env       =
  Environment->createFromConfig(
	EnvironmentConfig->createFromHash($envParams) );

sub main {
	my ( $installFrom, $remoteCdcSolidRootDir ) = @ARGV;

	if ( $installFrom && $remoteCdcSolidRootDir ) {
		Environment->getEnvironment()
		  ->CDCSolidRootDir( $remoteCdcSolidRootDir, 1 );

		CDCDb2->uninstall($installFrom);
	}
}
main();
