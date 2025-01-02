use strict;
use warnings;

use IBM::UC::Environment;
use IBM::UC::Database::Db2DB;

my $envParams = {};
my $env       =
  Environment->createFromConfig(
	EnvironmentConfig->createFromHash($envParams) );

sub main {
	my ( $db2Dir, $dbName, $db2User, $db2Pass, $db2Port,
		$remoteCdcSolidRootDir ) = @ARGV;

	if (   $db2Dir
		&& $dbName
		&& $db2User
		&& $db2Pass
		&& $db2Port
		&& $remoteCdcSolidRootDir )
	{
		Environment->getEnvironment()
		  ->CDCSolidRootDir( $remoteCdcSolidRootDir, 1 );

		my $db2Cfg = {
			db_name => $dbName,
			db_dir  => $db2Dir,
			db_user => $db2User,
			db_pass => $db2Pass,
			db_port => $db2Port
		};
		my $db2Db =
		  Db2DB->createFromConfig( DatabaseConfig->createFromHash($db2Cfg) );
		$db2Db->connectReset();
		$db2Db->deleteDatabase();
	}
}
main();
