use strict;
use warnings;

use IBM::UC::Environment;
use IBM::UC::Database::Db2DB;

my $envParams = {};
my $env       =
  Environment->createFromConfig(
	EnvironmentConfig->createFromHash($envParams) );

sub main {
	my ( $db2Dir, $db2User, $db2Pass, $remoteCdcSolidRootDir ) = @ARGV;

	if ( $db2Dir && $db2User && $db2Pass && $remoteCdcSolidRootDir ) {
		Environment->getEnvironment()
		  ->CDCSolidRootDir( $remoteCdcSolidRootDir, 1 );

		my $db2Cfg = {
			db_dir  => '$db2Dir',
			db_user => '$db2User',
			db_pass => '$db2Pass',
		};
		my $db2Db =
		  Db2DB->createFromConfig( DatabaseConfig->createFromHash($db2Cfg) );

		$db2Db->stop();
	}
}
main();
