use strict;
use warnings;

use IBM::UC::Environment;
use IBM::UC::CDC::CDCDb2;
use IBM::UC::Database::Db2DB;

my $envParams = {};
my $env       =
  Environment->createFromConfig(
	EnvironmentConfig->createFromHash($envParams) );

sub main {
	my (
		$cdcRootDir,
		$tsName,
		$tsPort,
		$db2Dir,
		$dbName,
		$db2User,
		$db2Pass,
		$dbPort,
		$dbSchema,
		$cdcRefreshLoader,
		$cdcbits,
		$remoteCdcSolidRootDir
	) = @ARGV;

	if (   $cdcRootDir
		&& $db2Dir
		&& $tsName
		&& $tsPort
		&& $dbName
		&& $db2User
		&& $db2Pass
		&& $dbPort
		&& $dbSchema
		&& $cdcRefreshLoader
		&& $cdcbits
		&& $remoteCdcSolidRootDir )
	{
		Environment->getEnvironment()->CDCBits($cdcbits);
		Environment->getEnvironment()
		  ->CDCSolidRootDir( $remoteCdcSolidRootDir, 1 );

		my $db2Cfg = {
			db_name   => $dbName,
			db_dir    => $db2Dir,
			db_user   => $db2User,
			db_pass   => $db2Pass,
			db_schema => $dbSchema,
			db_port   => $dbPort,
		};
		my $db2Db =
		  Db2DB->createFromConfig( DatabaseConfig->createFromHash($db2Cfg) );
		my $cdcCfg = {
			ts_name              => $tsName,
			ts_port              => $tsPort,
			ts_root              => $cdcRootDir,
			ts_db_refresh_loader => $cdcRefreshLoader
		};
		my $cdcUdb =
		  CDCDb2->createFromConfig( CDCConfig->createFromHash($cdcCfg),
			$db2Db );
		Environment::logf(">>#########starting...\n");
		$cdcUdb->start();
		Environment::logf(">>#########started...\n");
	}
}
main();
