########################################################################
# 
# File   :  Testbed.pm
# History:  Nov-2009 (bmof/yc) module created as part of Test Automation
#			project
#
########################################################################
#
# Testbed.pm provides a framework to interact with Testbed console, in 
# particular to run custom testcases and parse the resulting output logs
# 
########################################################################
package TestBed;

use strict;

use IBM::UC::Environment;
use IBM::UC::UCConfig::TestBedConfig;
use Cwd;
use File::Copy;
use File::Basename;
use Data::Dumper;
use Switch;


#-----------------------------------------------------------------------
# $ob = TestBed->new($config)
#-----------------------------------------------------------------------
# 
# Create TestBed object from existing AccessServerConfig object, which is essentially 
# a hash of parameter name/value pairs for Access Server.
# e.g.
# $config_values = { ac_host => 'localhost', ac_port => '10101',
#					  ac_user => 'Admin', ac_pass => 'admin123'};
# TestBed->new(AccessServerConfig->createFromHash($config_values));
# 
#-----------------------------------------------------------------------
sub new
{
	my $class = shift;
	my $as_cfg = shift;

	my $self = {
		TBLOG => undef, # Testbed output log name
		TBRESULTS => undef, # Testbed test results
		TBRESHEAD => undef, # Testbed test results header
		TBCONFIG => undef, # Testbed configuration for run() routine
		ASCONFIG => AccessServerConfig->new(),
		SRC  => undef, # source datastore
		TGT  => undef, # target datastore
	};

	bless $self, $class;

	# Make sure we get valid cdc configuration for target
	if (!defined($as_cfg)) {
		Environment::fatal("TestBed::new requires Access Server configuration as 1st parameter\nExiting...\n");
	} elsif (ref($as_cfg) ne 'AccessServerConfig') {
		Environment::fatal("TestBed::new: configuration object not of type \"AccessServerConfig\"\nExiting...\n");
	}
	$self->init(); # set defaults

	# override access server defaults with parameters passed
	$self->AccessConfig->initFromConfig($as_cfg->getParams());	

	# Check that Access Server config is fully initialised	
	$self->AccessConfig()->checkRequired() or 
		Environment::fatal("TestBed::new: Error(s) occurred. Exiting...\n");
	
	return $self;
}


#-----------------------------------------------------------------------
# $ob->init()
#-----------------------------------------------------------------------
#
# Initialise TestBed object parameters with default values
#
#-----------------------------------------------------------------------
sub init
{
	my $self = shift;

	# Make sure we only initialise once,
	#    in case a user explicitly calls what is intended to be a private method
	if (!$self->initialised()) { 
		$self->tbLog('testbed_nightlies.log'); # Testbed output log

		# Initialise some access config parameters to default values
		$self->AccessConfig()->initFromConfig({ac_host => 'localhost',
												ac_port => '10101',
												ac_user => 'Admin',
												ac_pass => 'admin123'});
		# Set flag so we don't initialise more than once
		$self->initialised(1);
	}
}



#-----------------------------------------------------------------------
# $ob->saveTestbedEnv()
#-----------------------------------------------------------------------
#
# Backs up environment.xml and testbedlauncher.ini files
# (method no longer needed)
#
#-----------------------------------------------------------------------
sub saveTestbedEnv
{
	my $self = shift;

	# Split path to environment file and make backup
	my ($name,$path) = fileparse($self->getEnv()->testbedEnvName());
	chdir($path);
	if (-f $name) { File::Copy::cp($name, $name . '.bak'); }

	# Make backup of testbed launcher
	chdir($self->tbHome() . 'res');
	File::Copy::cp('testBedLauncher.ini','testBedLauncher.ini.bak') if (-f 'testBedLauncher.ini');
}


#-----------------------------------------------------------------------
# $ob->restoreTestbedEnv()
#-----------------------------------------------------------------------
#
# Restores original environment.xml and testbedlauncher.ini files
# (method no longer needed)
#
#-----------------------------------------------------------------------
sub restoreTestbedEnv
{
	my $self = shift;
	
	# Split path to environment file and retore backup
	my ($name,$path) = fileparse($self->getEnv()->testbedEnvName());
	chdir($path);
	File::Copy::cp($name, $name . '.nightlies');
	File::Copy::cp($name.'bak', $name);
	unlink($name.'bak');

	# Restore testbed launcher backup
	chdir($self->tbHome() . 'res');
	File::Copy::cp('testBedLauncher.ini','testBedLauncher.ini.nightlies');
	File::Copy::cp('testBedLauncher.ini.bak','testBedLauncher.ini');
	unlink('testBedLauncher.ini.bak');
}


#-----------------------------------------------------------------------
# $ob->customiseLauncher()
#-----------------------------------------------------------------------
#
# Updates Testbedlauncher.ini file according to configuration here
# (method no longer needed)
#
#-----------------------------------------------------------------------
sub customiseLauncher
{
	my $self = shift;
	my $contents;

	chdir($self->tbHome() . 'res');
	Environment::fatal("Cannot find " . $self->tbHome() . "res/testBedLauncher.ini: $!\n")
		unless (-f 'testBedLauncher.ini');
	open(INI,'<','testBedLauncher.ini');
	$contents = join("",<INI>);
	close(INI);
	$contents =~ s/^(headHome)=(.*?)$/$1.'='.$self->tbHome()/em;
	$contents =~ s/^(QA_ApprovedHome)=(.*?)$/$1.'='.$self->tbApprovedDir()/em;
	$contents =~ s/^(environmentFileLocation)=(.*?)$/$1.'='.$self->getEnv()->testbedEnvName()/em;
	$contents =~ s/^(default_Bucket)=(.*?)$/$1.'='.$self->getEnv()->testbedBucket()/em;
	$contents =~ s/^(default_Cleanup)=(.*?)$/$1.'='.$self->tbClean()/em;
	$contents =~ s/^(default_Prefix)=(.*?)$/$1.'='.$self->tbPrefix()/em;
	$contents =~ s/^(default_Email)=(.*?)$/$1.'='.$self->tbEmail()/em;
	$contents =~ s/^(AS_User_Name)=(.*?)$/$1.'='.$self->tbUser()/em;
	open(INI,'>','testBedLauncher.ini');
	print INI $contents;
	close(INI);
}



#-----------------------------------------------------------------------
# $ob->writeEnvironment()
#-----------------------------------------------------------------------
#
# Writes out environment.xml with updated parameter values
#
#-----------------------------------------------------------------------
sub writeEnvironment
{
	my $self = shift;

	my $dbtype_s = ref($self->source()->getCdc());
	my $dbtype_t = ref($self->target()->getCdc());
	my ($informixConn_s, $informixConn_t);
	my ($schema_s, $schema_t);
	my $ENVXML;
	

    $informixConn_s="";
	$informixConn_t="";

	switch ($dbtype_s)
	{
		case "CDCSolid" {
			$dbtype_s = 'SOLID';
			$schema_s = "${\uc($self->source()->getCdc()->database()->dbSchema())}";
		}
		case "CDCDb2" {
			$dbtype_s = 'DB2_UDB';
			$schema_s = "${\uc($self->source()->getCdc()->database()->dbSchema())}";
		}
		case "CDCInformix" {
			$dbtype_s = 'INFORMIX';			
			$schema_s = "${\$self->source()->getCdc()->database()->dbSchema()}";
			$informixConn_s = "DB_CONN_PROPERTIES=\'INFORMIXSERVER=${\$self->source()->getCdc()->database()->instanceName()}\'";
		}
	}

	switch ($dbtype_t) {
		case "CDCSolid" {
			$dbtype_t = 'SOLID';
			$schema_t = "${\uc($self->target()->getCdc()->database()->dbSchema())}";
		}
		case "CDCDb2" {
			$dbtype_t = 'DB2_UDB';
			$schema_t = "${\uc($self->target()->getCdc()->database()->dbSchema())}";
		}
		case "CDCInformix" {
			$dbtype_t = 'INFORMIX';			
			$schema_t = "${\$self->target()->getCdc()->database()->dbSchema()}";
			$informixConn_t = "DB_CONN_PROPERTIES=\'INFORMIXSERVER=${\$self->target()->getCdc()->database()->instanceName()}\'";
		}
	}
$ENVXML=<<END;
<?xml version="1.0" encoding="UTF-8"?>
<environment>

	<definition name="${\$self->source()->datastoreName()}" type="$dbtype_s">
		<ea 
			EA_PASSWORD="${\$self->accessPass()}"
			EA_PORT_NUMBER="${\$self->accessPort()}"
			EA_USER_NAME="${\$self->accessUser()}"
			EA_WORKSTATION="${\$self->accessHost()}"
		/>
		<ts_agent 
			TS_AGENT_NAME="${\$self->source()->datastoreName()}" 
			TS_HOST_NAME="${\$self->source()->datastoreHost()}" 
			TS_PORT="${\$self->source->getCdc()->instancePort()}" 
			TS_VERSION="V6R3" 
		    TS_DATABASE_NAME="${\$self->source()->getCdc()->database()->dbName()}" 
			TS_USERID="${\$self->source()->getCdc()->database()->dbUser()}" 
			TS_PASSWORD="${\$self->source()->getCdc()->database()->dbPass()}"
			TS_SCHEMA="$schema_s"
		/>
		<database 
			DB_HOST_NAME="${\$self->source()->datastoreHost()}" 
			DB_NAME="${\$self->source()->getCdc()->database()->dbName()}"
			DB_TYPE="$dbtype_s"
			DB_PORT="${\$self->source()->getCdc()->database()->dbPort()}"
			DB_TABLESPACE="" 
			DB_VERSION="V6R5"
			DB_SCHEMA="$schema_s"
			DB_CATALOG="$schema_s"
			DB_USERID="${\$self->source()->getCdc()->database()->dbUser()}" 
			DB_PASSWORD="${\$self->source()->getCdc()->database()->dbPass()}"
			$informixConn_s
		/>
	</definition>

	<definition name="${\$self->target()->datastoreName()}" type="$dbtype_t">
		<ea 
			EA_PASSWORD="${\$self->accessPass()}"
			EA_PORT_NUMBER="${\$self->accessPort()}"
			EA_USER_NAME="${\$self->accessUser()}" 
			EA_WORKSTATION="${\$self->accessHost()}"
		/>
		<ts_agent 
			TS_AGENT_NAME="${\$self->target()->datastoreName()}"
			TS_HOST_NAME="${\$self->target()->datastoreHost()}"
			TS_PORT="${\$self->target()->getCdc()->instancePort()}"
			TS_VERSION="V6R3"
			TS_DATABASE_NAME="${\$self->target()->getCdc()->database()->dbName()}"
			TS_USERID="${\$self->target()->getCdc()->database()->dbUser()}"
			TS_PASSWORD="${\$self->target()->getCdc()->database()->dbPass()}"
			TS_SCHEMA="$schema_t"
		/>
		<database 
			DB_HOST_NAME="${\$self->target()->datastoreHost()}" 
			DB_NAME="${\$self->target()->getCdc()->database()->dbName()}"
			DB_TYPE="$dbtype_t"
			DB_PORT="${\$self->target()->getCdc()->database()->dbPort()}"
			DB_TABLESPACE="" 
			DB_VERSION="V6R5"
			DB_SCHEMA="$schema_t" 
			DB_CATALOG="$schema_t"
			DB_USERID="${\$self->target()->getCdc()->database()->dbUser()}" 
			DB_PASSWORD="${\$self->target()->getCdc()->database()->dbPass()}" 
			$informixConn_t
		/>
	</definition>

</environment>
END

	# Split path to environment file and make backup
	my ($name,$path) = File::Basename::fileparse($self->getEnv()->testbedEnvName());

	chdir($self->tbHome()); # Create environment file in testbed home directory for now
	open(ENV,'>',$name) or Environment::fatal("Could not open environment file $path$name: $!\n");
	Environment::logf(">>Writing testbed environment to \"" . $self->tbHome() . $name . "\"\n");
	print ENV $ENVXML;
	close(ENV);
}




#-----------------------------------------------------------------------
# $ob->run([$cfg])
#-----------------------------------------------------------------------
#
# Launches testcase in TestBed console.
# Takes optional testbed run configuration object (TestBedConfig) as input
# e.g.
# $tb_parms = {tb_user => 'mooreof', # user name
#				tb_test_single => 'V46_MirrorContinuous_9999', # single test name 
#				tb_test_list => '', # list name (to contain list of tests to run)
#				tb_email => 'mooreof@ie.ibm.com', # email to receive report
#				tb_clean => 1, # Testbed clean up option
#				tb_prefix => 'TB', # Testbed prefix (2-character)
# };
# $testbed->run(TestBedConfig->createFromHash($tb_parms));
#
# see POD for details on valid parameter names and their default values
#
#-----------------------------------------------------------------------
sub run
{
	my $self = shift;
	my $cfg = shift; # Optional testbed configuration object
	my $tb_cfg;
	my $command;
	my $testname;
	my ($envname,$path);
	
	# Make sure we get valid configuration for testbed run
	if (defined($cfg) && (ref($cfg) ne 'TestBedConfig')) {
		Environment::fatal("TestBed::run Testbed configuration not of type \"TestBedConfig\"\nExiting...\n");
	} else {
		$tb_cfg = new TestBedConfig();
		
		# Initialise testbed config parameters to default values
		$tb_cfg->initFromConfig({tb_user => 'mooreof',
								 tb_test_single => 'V46_MirrorContinuous_9999',
								 tb_test_list => '',
								 tb_email => 'mooreof@ie.ibm.com',
								 tb_clean => '1',
								 tb_prefix => 'TB',
								 tb_cmd_opt => '-t'});
								 
		# override defaults for testbed config with parameters passed
		if (defined($cfg)) { $tb_cfg->initFromConfig($cfg->getParams()); }
		$self->TestbedConfig($tb_cfg);

		# Check that test bed config is fully initialised
		$self->TestbedConfig()->checkRequired() or 
			Environment::fatal("Testbed::run: Error(s) occurred. Exiting...\n");
	}
	$testname = ($self->tbTestList() ? $self->tbTestList() : $self->tbTestSingle());
	($envname,$path) = File::Basename::fileparse($self->getEnv()->testbedEnvName());

	chdir($self->tbHome());
	$command = "java -jar dmtstb.jar " . $self->tbCmdOpt() . ' ' . $testname . " -src " . $self->source()->datastoreName() .
				" -tgt " . $self->target()->datastoreName() . " -cleanup " . $self->tbClean() .
				" -export 2 -debug -prefix " . $self->tbPrefix() . " -timeout 120" .
#				" -email " . $self->tbEmail() .
				" -env " . $self->tbHome() . $envname .
				' > ' . $self->tbHome() . $self->tbLog();
				
	Environment::logf(">>COMMAND: $command\n");
	Environment::logf(">>Starting testcase(s) \"$testname\" in TestBed...\n");
	system($command) and Environment::logf("***Error occurred in Testbed::run***\n");
	Environment::logf(">>done\n");
}


#-----------------------------------------------------------------------
# $ob->parseResults()
#-----------------------------------------------------------------------
#
# Analyse Testbed output log(s) and generated summarised report
#
#-----------------------------------------------------------------------
sub parseResults
{
	my $self = shift;
	my $line = '';
	my $summary;
	my $total = 0;
	my $pass = 0;
	my $fail = 0;
	my $kpass = 0;
	my $kfail = 0;
	my $testcase = ($self->tbTestList() ? $self->tbTestList() : $self->tbTestSingle());
	my $testname = undef;

	open(LOG,'<', $self->tbHome() . $self->tbLog()) or Environment::logf("Cannot open testbed log\n");

	# Grab test summary and test name
	while (defined($line = <LOG>) && ($line !~ m/\* SUMMARY \*/i)) { }
	$summary .= $line;
	while (defined($line = <LOG>) && ($line !~ m/\* TEST ENVIRONMENT \*/i)) {
		$testname = $1 if ($line =~ m/Test name: ([\w\d_]+)/i);
		$summary .= $line;
	}

	# Grab result counts
	#* RESULTS *
	#--------------------------------------------------------------------------------
	#Total: 1
	#PASS : 0
	#FAIL : 1
	#KFAIL: 0
	#KPASS: 0
	while (defined($line = <LOG>) && ($line !~ m/\* RESULTS \*/i)) { }
	while (defined($line = <LOG>) && ($line !~ m/\* Functionality Summary \*/i)) {
		$total = $1 if ($line =~ m/\#Total[ :]+([0-9]+)/i);
		$pass = $1 if ($line =~ m/\#PASS[ :]+([0-9]+)/i);
		$fail = $1 if ($line =~ m/\#FAIL[ :]+([0-9]+)/i);
		$kfail = $1 if ($line =~ m/\#KFAIL[ :]+([0-9]+)/i);
		$kpass = $1 if ($line =~ m/\#KPASS[ :]+([0-9]+)/i);
	}
	if (!defined($line)) {
		$fail = 1;
		$summary = "Abnormal termination of Testbed\n\n";
	}
	$summary .= "Total: $total\nPass: $pass\nFail: $fail\n" . "KPass: $kpass\nKFail: $kfail\n\n";
	$summary .= $line;

	# Grab summary
	while (defined($line = <LOG>) && ($line !~ m/\*\* End of the report \*\*/i)) { 
		$summary .= $line;
	}
	$summary .= $line . "\n" if ($line);

	close(LOG);

	# Subject line for email report
	my $pre = $fail ? '(FAIL) ' : '(SUCCESS) ';
	$self->tbResultsHeader("${pre}Test results for: $testname");
	
	# If there's a fail pull fail description from error log in abridged_logs directory
	if ($fail > 0 && defined($testname)) {
		my $ps = $self->getEnv()->getPathSeparator();
		my $errlog =  $self->tbPrefix() . '_' . $testcase;
		my $logpath = $self->tbHome().'reports'.$ps.$testname.$ps.'abridged_logs'.$ps;

		# Strip tail from testname and add to errlog name
		# xxx_SOLID_V6R3_SOLID_V6R3_310_100706466 (tail=_310_100706466)
		$errlog .= $1 if ($testname =~ m/.*(_[0-9]+_[0-9]+)/);
		
		if (-f $logpath.$errlog) {
			open(LOG,'<',$logpath.$errlog)
				or Environment::fatal("Failed to open error log \"$logpath$errlog\": $!\n");
			while (defined($line = <LOG>)) {
				$summary .= "ERROR DETAILS:\n$line\n" if ($line =~ m/ E \[FAIL\]/i);
			}
			close(LOG);
		} else {
			Environment::logf("Cannot find error log: $logpath$errlog\n");
		}
	}
	$self->tbResults($summary);
}


#-----------------------------------------------------------------------
# $ob->processResults()
#-----------------------------------------------------------------------
#
# Parse Testbed output logs and send email with summary report to 
# designated contact
#
#-----------------------------------------------------------------------
sub processResults
{
	my $self = shift;

	$self->parseResults();
	$self->emailResults();
#	$self->copyToRepository();
#	$self->restoreTestbedEnv();
}


#-----------------------------------------------------------------------
# $ob->emailResults()
#-----------------------------------------------------------------------
#
# Send email with summary of testcase output to designated contact
#
#-----------------------------------------------------------------------
sub emailResults
{
	my $self = shift;
	my $from = 'Testbed Results <mooreof@ie.ibm.com>';
	my %mail;

	return unless (defined($self->tbResults()));

	if (require Mail::Sendmail) {
		%mail = (To => $self->tbEmail(),
				 From => $from,
				 subject => $self->tbResultsHeader(),
				 message => $self->tbResults(),
				 smtp => $self->getEnv()->smtpServer());
		Mail::Sendmail::sendmail(%mail) or croak($Mail::Sendmail::error);
	} else {
		Environment::logf("Unable to send email as Mail::Sendmail module cannot be found\n");
	}
}


#-----------------------------------------------------------------------
# $ob->copyToRepository()
#-----------------------------------------------------------------------
#
# Copy Testcase summary to repository
#
#-----------------------------------------------------------------------
sub copyToRepository
{
}


#-----------------------------------------------------------------------
# $ob->printout()
#-----------------------------------------------------------------------
#
# Prints out contents of object's hash in a human-readable form
#
#-----------------------------------------------------------------------
sub printout
{
	my $self = shift;
	
	Environment::logf(Dumper($self));
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
# $ds = $ob->source()
# $ob->source($ds)
#-----------------------------------------------------------------------
#
# Get/set object representing source datastore (class Datastore)
#
#-----------------------------------------------------------------------
sub source
{
	my ($self,$ds) = @_;
	if (defined($ds) && (ref($ds) ne 'Datastore')) {
		Environment::fatal("TestBed::source: expecting parameter of type Datastore\nExiting...\n");
	}
	$self->{'SRC'} = $ds if defined($ds);
	return $self->{'SRC'};
}


#-----------------------------------------------------------------------
# $ds = $ob->target()
# $ob->target($ds)
#-----------------------------------------------------------------------
#
# Get/set object representing target datastore (class Datastore)
#
#-----------------------------------------------------------------------
sub target
{
	my ($self,$ds) = @_;
	if (defined($ds) && (ref($ds) ne 'Datastore')) {
		Environment::fatal("TestBed::target: expecting parameter of type Datastore\nExiting...\n");
	}
	$self->{'TGT'} = $ds if defined($ds);
	return $self->{'TGT'};
}


#-----------------------------------------------------------------------
# $cfg = $ob->TestbedConfig()
# $ob->TestbedConfig($cfg)
#-----------------------------------------------------------------------
#
# Get/set active Testbed run configuration object (class TestBedConfig)
#
#-----------------------------------------------------------------------
sub TestbedConfig
{
	my ($self,$cfg) = @_;
	$self->{'TBCONFIG'} = $cfg if (defined($cfg));
	return $self->{'TBCONFIG'};
}


#-----------------------------------------------------------------------
# $ref = $ob->getTestbedConfigParams()
#-----------------------------------------------------------------------
#
# Get reference to active Testbed configuration parameters hash
#
#-----------------------------------------------------------------------
sub getTestbedConfigParams
{
	my $self = shift;
	return $self->TestbedConfig()->getParams();
}


#-----------------------------------------------------------------------
# $cfg = $ob->AccessConfig()
# $ob->AccessConfig($cfg)
#-----------------------------------------------------------------------
#
# Get/set Access Server configuration object (class AccessServerConfig)
#
#-----------------------------------------------------------------------
sub AccessConfig
{
	my ($self,$cfg) = @_;
	$self->{'ASCONFIG'} = $cfg if (defined($cfg));
	return $self->{'ASCONFIG'};
}


#-----------------------------------------------------------------------
# $ref = $ob->getAccessConfigParams()
#-----------------------------------------------------------------------
#
# Get reference to Access Server configuration parameters hash
#
#-----------------------------------------------------------------------
sub getAccessConfigParams
{
	my $self = shift;
	return $self->AccessConfig()->getParams();
}


#-----------------------------------------------------------------------
# $dir = $ob->tbHome()
# $ob->tbHome($dir)
#-----------------------------------------------------------------------
#
# Get/set Testbed home directory
#
#-----------------------------------------------------------------------
sub tbHome
{
	my ($self,$name) = @_;

	$self->tbApprovedDir($name) if (defined($name));
	return $self->tbApprovedDir();
}


#-----------------------------------------------------------------------
# $log = $ob->tbLog()
# $ob->tbLog($log)
#-----------------------------------------------------------------------
#
# Get/set Testbed log name
#
#-----------------------------------------------------------------------
sub tbLog
{
	my ($self,$name) = @_;
	$self->{'TBLOG'} = $name if defined($name);
	return $self->{'TBLOG'};
}


#-----------------------------------------------------------------------
# $res = $ob->tbResults()
# $ob->tbResults($res)
#-----------------------------------------------------------------------
#
# Get/set merged results from Testbed testcase
#
#-----------------------------------------------------------------------
sub tbResults
{
	my ($self,$name) = @_;
	$self->{'TBRESULTS'} = $name if defined($name);
	return $self->{'TBRESULTS'};
}


#-----------------------------------------------------------------------
# $res = $ob->tbResultsHeader()
# $ob->tbResultsHeader($res)
#-----------------------------------------------------------------------
#
# Get/set results header from Testbed testcase
#
#-----------------------------------------------------------------------
sub tbResultsHeader
{
	my ($self,$name) = @_;
	$self->{'TBRESHEAD'} = $name if defined($name);
	return $self->{'TBRESHEAD'};
}



#-----------------------------------------------------------------------
# $dir = $ob->tbApprovedDir()
# $ob->tbApprovedDir($dir)
#-----------------------------------------------------------------------
#
# Get/set Testbed qa_approved directory
#
#-----------------------------------------------------------------------
sub tbApprovedDir
{
	my ($self,$name) = @_;

	$self->getEnv()->testbedQAApprovedDir($name) if (defined($name));
	return $self->getEnv()->testbedQAApprovedDir();
}


#-----------------------------------------------------------------------
# $name = $ob->tbUser()
# $ob->tbUser($name)
#-----------------------------------------------------------------------
#
# Get/set Testbed testcase user name
#
#-----------------------------------------------------------------------
sub tbUser
{
	my ($self,$name) = @_;
	$self->getTestbedConfigParams()->{'tb_user'} = $name if defined($name);
	return $self->getTestbedConfigParams()->{'tb_user'};
}


#-----------------------------------------------------------------------
# $name = $ob->tbTestSingle()
# $ob->tbTestSingle($name)
#-----------------------------------------------------------------------
#
# Get/set name of single testcase to run
#
#-----------------------------------------------------------------------
sub tbTestSingle
{
	my ($self,$name) = @_;
	$self->getTestbedConfigParams()->{'tb_test_single'} = $name if defined($name);
	return $self->getTestbedConfigParams()->{'tb_test_single'};
}


#-----------------------------------------------------------------------
# $file = $ob->tbTestList()
# $ob->tbTestList($file)
#-----------------------------------------------------------------------
#
# Get/set filename with list of testcases to run
#
#-----------------------------------------------------------------------
sub tbTestList
{
	my ($self,$name) = @_;
	$self->getTestbedConfigParams()->{'tb_test_list'} = $name if defined($name);
	return $self->getTestbedConfigParams()->{'tb_test_list'};
}


#-----------------------------------------------------------------------
# $name = $ob->tbEmail()
# $ob->tbEmail($name)
#-----------------------------------------------------------------------
#
# Get/set email contact for active Testbed testcase
#
#-----------------------------------------------------------------------
sub tbEmail
{
	my ($self,$name) = @_;
	$self->getTestbedConfigParams()->{'tb_email'} = $name if defined($name);
	return $self->getTestbedConfigParams()->{'tb_email'};
}


#-----------------------------------------------------------------------
# $opt = $ob->tbClean()
# $ob->tbClean($opt)
#-----------------------------------------------------------------------
#
# Get/set Testbed testcase clean up option
# 0 - Do not cleanup.
# 1 - Always cleanup (default). 
# 2 - Do not cleanup if test case fails or known fails or unknown passes.
# 3 - Do not cleanup if test case fails)
#
#-----------------------------------------------------------------------
sub tbClean
{
	my ($self,$opt) = @_;
	$self->getTestbedConfigParams()->{'tb_clean'} = $opt if defined($opt);
	return $self->getTestbedConfigParams()->{'tb_clean'};
}


#-----------------------------------------------------------------------
# $name = $ob->tbPrefix()
# $ob->tbPrefix($name)
#-----------------------------------------------------------------------
#
# Get/set 2-character prefix for testcases
#
#-----------------------------------------------------------------------
sub tbPrefix
{
	my ($self,$name) = @_;
	$self->getTestbedConfigParams()->{'tb_prefix'} = $name if defined($name);
	return uc($self->getTestbedConfigParams()->{'tb_prefix'});
}


#-----------------------------------------------------------------------
# $opt = $ob->tbCmdOpt()
# $ob->tbCmdOpt($opt)
#-----------------------------------------------------------------------
#
# Get/set command-line options
#
#-----------------------------------------------------------------------
sub tbCmdOpt
{
	my ($self,$opt) = @_;
	$self->getTestbedConfigParams()->{'tb_cmd_opt'} = $opt if defined($opt);
	return $self->getTestbedConfigParams()->{'tb_cmd_opt'};
}


#-----------------------------------------------------------------------
# $host = $ob->accessHost()
# $ob->accessHost($host)
#-----------------------------------------------------------------------
#
# Get/set Access Server Host
#
#-----------------------------------------------------------------------
sub accessHost
{
	my ($self,$name) = @_;
	$self->getAccessConfigParams()->{'ac_host'} = $name if defined($name);
	return $self->getAccessConfigParams()->{'ac_host'};
}


#-----------------------------------------------------------------------
# $port = $ob->accessPort()
# $ob->accessPort($port)
#-----------------------------------------------------------------------
#
# Get/set Access Server port number
#
#-----------------------------------------------------------------------
sub accessPort
{
	my ($self,$name) = @_;
	$self->getAccessConfigParams()->{'ac_port'} = $name if defined($name);
	return $self->getAccessConfigParams()->{'ac_port'};
}


#-----------------------------------------------------------------------
# $user = $ob->accessUser()
# $ob->accessUser($user)
#-----------------------------------------------------------------------
#
# Get/set Access Server user name
#
#-----------------------------------------------------------------------
sub accessUser
{
	my ($self,$name) = @_;
	$self->getAccessConfigParams()->{'ac_user'} = $name if defined($name);
	return $self->getAccessConfigParams()->{'ac_user'};
}


#-----------------------------------------------------------------------
# $pass = $ob->accessPass()
# $ob->accessPass($pass)
#-----------------------------------------------------------------------
#
# Get/set Access Server user password
#
#-----------------------------------------------------------------------
sub accessPass
{
	my ($self,$name) = @_;
	$self->getAccessConfigParams()->{'ac_pass'} = $name if defined($name);
	return $self->getAccessConfigParams()->{'ac_pass'};
}


#-----------------------------------------------------------------------
# $init = $ob->initialised()
# $ob->initialised($init)
#-----------------------------------------------------------------------
#
# Get/set flag indicating whether object has been initialised.
# This is done to prevent object being initialised later by a user
# which would set all parameters back to their default values
#
#-----------------------------------------------------------------------
sub initialised
{
	my ($self,$init) = @_;
	if (!defined($self->{'INIT'})) { $self->{'INIT'} = 0; }
	$self->{'INIT'} = $init if defined($init);
	return $self->{'INIT'};
}



1;


=head1 NAME

TestBed - Class for interacting with TestBed console

=head1 SYNOPSIS

use IBM::UC::TestBed;

#################
# class methods #
#################

 $ob = TestBed->new($as_cfg);
   where:
     $as_cfg=Access server configuration object describing Access Server propeties

The constructor initialises itself from a configuration object defining parameters
for Access Server.

#######################
# object data methods #
#######################

### get versions ###

 $env = $ob->getEnv()
 $src = $ob->source() # Source datastore
 $tgt = $ob->target() # Target datastore
 $home = $ob->tbHome()
 $log = $ob->tbLog()
 $qa = $ob->tbApprovedDir()
 $user = $ob->tbUser()
 $test = $ob->tbTestSingle()
 $list = $ob->tbTestList()
 $email = $ob->tbEmail()
 $clean = $ob->tbClean()
 $pfx = $ob->tbPrefix()
 $opt = $ob->tbCmdOpt()
 $ach = $ob->accessHost()
 $acp = $ob->accessPort()
 $acu = $ob->accessUser()
 $acp = $ob->accessPass()

### set versions ###

 $ob->source($ds_src)		# Assign datastore as source
 $ob->target($ds_tgt)		# Assign datastore as target
 $ob->tbHome()
 $ob->tbLog()
 $ob->tbApprovedDir()
 $ob->tbUser()
 $ob->tbTestSingle()
 $ob->tbTestList()
 $ob->tbEmail()
 $ob->tbClean()
 $ob->tbPrefix()
 $ob->tbCmdOpt()
 $ob->accessHost('localhost')
 $ob->accessPort(11011)
 $ob->accessUser('admin')
 $ob->accessPass('admin')


########################
# other object methods #
########################

 $ob->writeEnvironment();	# Write environment file
 $ob->run([$tb_cfg]);		# Launch testcase(s) in Testbed
				# where $tb_cfg=configuration object of class TestBedConfig describing 
				# TestBed configuration (optional parameter)
 $ob->processResults();		# Analyse output logs, email test results, copy logs to repository

=head1 DESCRIPTION

The TestBed module interacts with Testbed console in order to launch multiple testcases and 
analyse the results of those testcases.

The AccessServer module is intended to encapsulate the functionality of Management console:
create source and target datastores, create subscriptions and mappings, start/stop
replication, start/stop access server.

Initialisation of a TestBed instance is via configuration parameters describing Access Server 
properties:

Valid configuration parameters and their default values follow (see AccessServerConfig.pm):

 ---------------------------------------------------------------------------------------------------------
 Parameter		Description					Default value
 ---------------------------------------------------------------------------------------------------------
 ac_host		Host name/ip address of access server		localhost
 ac_port		Communication port of access server		10101
 ac_user		User name with rights to use access server	Admin
 ac_pass		User password					admin123
 ---------------------------------------------------------------------------------------------------------

each testcase run takes a testbed configuration object of class TestBedConfig as input. Valid testbed run
parameters and their values follow (see TestBedConfig.pm).

 ---------------------------------------------------------------------------------------------------------
 Parameter		Description					Default value
 ---------------------------------------------------------------------------------------------------------
 tb_user		Testbed testcase user name			mooreof
 tb_test_single		Testbed testcase name				V46_MirrorContinuous_9999
 tb_test_list		Testbed testcase list filename			none
 tb_email		Testbed testcase email contact			mooreof@ie.ibm.com
 tb_clean		Testbed testcase cleanup option			1
 tb_prefix		Testbed testcase prefix				TB
 ---------------------------------------------------------------------------------------------------------

if initialisation is via a configuration ini file the Testbed section must start with [TESTBED]
and end with [/TESTBED] or end of file, e.g.:

 [TESTBED]

 ; Test bed user 
 tb_user=mooreof

 ; Name of single test to run (blank if running multiple tests, see tb_test_list)
 tb_test_single=V46_MirrorContinuous_9999

 ; Name of file containing  multiple test cases to run. If blank, tb_test_single above is run
 ; Assumed to be located in tb_home
 tb_test_list=

 ; Email contact(s) to whom results report is sent
 tb_email=mooreof@ie.ibm.com

 ; Testbed cleanup option (0 - Do not cleanup. 1 - Always cleanup (default). 
 ;                         2 - Do not cleanup if test case fails or known fails or unknown passes.
 ;                         3 - Do not cleanup if test case fails)
 tb_clean=1

 ; 2-character user prefix
 tb_prefix=tb

=head1 EXAMPLES

Following is an example which launches the default testcase after creating/starting databases, cdc
instances and datastores:

 # Install SolidDB from server, CDC for SolidDB from CVS and run mirroring test in TestBed
 # with Solid as source and DB2 as target
 sub nightlies_sol_to_db2
 {
	my $inp;
	my ($env_parms,$db2_params);
	my ($db_src, $db_tgt);
	my ($cdc_src, $cdc_tgt);
	my ($as_cfg, $mConsole);
	my ($ds_src, $ds_tgt);
	my ($testbed,$tb_parms);


 eval { # trap errors so we can clean up before exiting

	# Initialise some environment parameters 
	 $env_parms = {
		debug => 1,
		smtp_server => 'D06DBE01',
		cvs_user => 'dmbuild',
		cvs_pass => 'dmbuild',
		cvs_repository => ':pserver:dmbuild:dmbuild@dmccvs.torolab.ibm.com:/home/cvsuser/cvsdata',
		cvs_home => '/home/db2inst1/cvs',
		cvs_tag => 'BR_SJKRWLPY_2837_UC_6-5-0-0',
		cdc_solid_root_dir => '/home/db2inst1/Transformation Server for solidDB/',
		ant_version => 'apache-ant-1.6.2',
		solid_root_dir => '/home/db2inst1/soliddb-6.5/',
		solid_licence_file => '/home/db2inst1/automation_workspace/Nightlies/solid.lic',
		testbed_head_dir => '/home/db2inst1/workspace/TestBed_HEAD/',
		testbed_qa_approved_dir => '/home/db2inst1/workspace/QA_Approved/',
		java_home => '/home/db2inst1/ibm-java2-i386-50',
		java6_home => '/home/db2inst1/ibm-java-i386-60',
	};
	Environment->createFromConfig(EnvironmentConfig->createFromHash($env_parms));

	# Install CDC for solid
 	CDCSolid->install();
	# Install SolidDB
 	SolidDB->install();

	# create and start source database
	$db_src = SolidDB->createSimple('/home/db2inst1/solid/src',2315);
	$db_src->start();
	
	# create source CDC
	$cdc_src = CDCSolid->createSimple('solsrc_ts',11101,$db_src);

	# create and start target database
	my $db2_params = {
		db_dir => '/home/db2inst1/db2inst1/NODE0000/TEST',
		db_name => 'TEST',
		db_user => 'db2inst1',
		db_pass => 'db2inst1',
	};
	$db_tgt = Db2DB->createComplex($db2_params);
	$db_tgt->start();
	# Create target database, connect to it
	$db_tgt->createDatabase();
	# Create schema 
	$db_tgt->createSchema('db2inst1');
	
	# create target CDC
	$cdc_tgt = CDCDb2->createSimple('db2tgt_ts',11102,$db_tgt);

	# create and start source/target cdc's
	$cdc_src->create();
	$cdc_tgt->create();

	$cdc_src->start();
	$cdc_tgt->start();

	# Access server configuration 
	# (config will be reused in TestBed, hence not using AccessServer->createSimple())
	$as_cfg = {ac_host => 'localhost', # Access server host
	 			ac_port => '10101', # Access server port
				ac_user => 'Admin', # Access server user
				ac_pass => 'admin123'}; # Access server password
	
	# Create mConsole/Access server instance
	$mConsole = AccessServer->createFromConfig(AccessServerConfig->createFromHash($as_cfg));

	# create datastores
	$ds_src = $mConsole->createDatastoreSimple(
		'solsrc_ds', # datastore name
		'Source datastore', # datastore description
		'localhost', # datastore host
		$cdc_src, # cdc instance
	);
	$ds_tgt = $mConsole->createDatastoreSimple(
		'db2tgt_ds', # datastore name
		'Target datastore', # datastore description
		'localhost', # datastore host
		$cdc_tgt,  # cdc instance
	);
	$mConsole->source($ds_src); # assign source datastore
	$mConsole->target($ds_tgt); # assign target datastore
	
	# Following commands currently not working
	$mConsole->assignDatastoreUser($ds_src);
	$mConsole->assignDatastoreUser($ds_tgt);

	# Testbed initialsed from access server config only, common testbed config stuff is 
	# initialised in Environment config
	$testbed = TestBed->new(AccessServerConfig->createFromHash($as_cfg));

	# Assign source and target datastores
	$testbed->source($ds_src);
	$testbed->target($ds_tgt);

	$testbed->writeEnvironment(); # Write environment.xml file
		
	# Testbed config for run() routine (all these parameters have defaults)
	$tb_parms = {tb_user => 'mooreof', # user name
				 tb_test_single => 'V46_MirrorContinuous_9999', # single test name 
				 tb_test_list => '', # list name (to contain list of tests to run)
				 tb_email => 'mooreof@ie.ibm.com', # email to receive report
				 tb_clean => 1, # Testbed clean up option
				 tb_prefix => 'TB', # Testbed prefix (2-character)
	};

	# run test using parameters specified in config object
	$testbed->run(TestBedConfig->createFromHash($tb_parms));
	$testbed->processResults(); # parse result logs and send email
 };

 # Error thrown in eval {...}
 if ($@) { Environment::logf("\n\nErrors found: $@\n"); }

	# CLEANUP

	# Delete datastores
	$mConsole->deleteDatastore($ds_tgt);
	$mConsole->deleteDatastore($ds_src);

	# stop and delete cdc instances
	$cdc_src->stop();
	$cdc_tgt->stop();
	$cdc_src->delete();
	$cdc_tgt->delete();

	# shut down databases
	$db_src->stop();
	$db_tgt->stop();
 }


=cut
