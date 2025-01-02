########################################################################
# 
# File   :  InformixDB.pm
# History:  Nov-2009 () module created as part of 'Nightlies' 
#            implementation
#
########################################################################
#
# InformixDB.pm is a sub-class of Database.pm.
# It provides routines to create and interact with a Informix database
# It can also be used to connect with an existing Informix database 
# (either remote or local) and interact with it
# 
########################################################################
package InformixDB;

use IBM::UC::Database;
use IBM::UC::Environment;
use Cwd;
use Config;
use File::Path;
use Net::Domain qw (hostname hostfqdn hostdomain);

use strict;

our @ISA = qw(Database); # database super class


#-----------------------------------------------------------------------
# $ob = Database->createSimple([$user, $password, $installDir, $portNumber)
#-----------------------------------------------------------------------
#
# Creates and initialises for an informix database server 
#
#-----------------------------------------------------------------------

sub createSimple
{
    my $class = shift;
    my $user = shift;
    my $password = shift;
    my $installDir = shift;
    my $serverName = shift;
    my $dbName = shift;
    my $portNumber = shift;
    my $schema = shift;
    my $ps;
    my $hostname;        
    my $self = $class->SUPER::new();

    bless $self, $class;
    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $hostname = `hostname`;
    }
    else {
         $hostname = $ENV{'HOSTNAME'};
    }

    # initialise for server usage
    $self->getConfig()->initFromConfig({db_dir => $installDir,
                                        db_dir_clean => 'no',
                                        db_host => $hostname,
                                        db_port => $portNumber,
                                        db_inst => $serverName,
                                        db_name => $dbName,
                                        db_user => $user,
                                        db_pass => $password,
                                        db_sql_output => 'sqloutput.log',
                                        db_schema => $schema
                                       });
    $self->setDbDirPath($self->dbDir());                                   
    $self->{'response_file'} = 'informix_response_file.ini';

    # Check that config is fully initialised    
    $self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");
    $ps = Environment::getEnvironment()->getPathSeparator();

    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $self->{'ext'} = '.bat';
        $self->{'ext_r'} = '.bat';
        $self->{'cmd'} = '';
        $self->{'extractToDir'} = "c:${ps}temp${ps}informix";
    }
    else {
        $self->{'ext'} = '';
        $self->{'ext_r'} = '.sh';
        $self->{'cmd'} = 'sh ';
        $self->{'onconfig'} = 'onconfig';
        $self->{'sqlhosts'} = 'sqlhosts';
        $self->{'extractToDir'} = "${ps}tmp${ps}informix";
    }

    $self->instanceName($serverName);

    $hostname = $self->dbHost();
    $hostname =~ s/\n//;         # remove lf character
    $self->dbHost($hostname);    # update 

    $self->{'connectionStr'} = '';
    $self->{'workFile'} = "workfile$self->{'ext'}";

    return $self;
}

#-----------------------------------------------------------------------
# $ob = SolidDB->createFromFile($ini)
#-----------------------------------------------------------------------
#
# Create informix object using configuration info from ini file (in the form
# of name=value records).
# See POD for allowed parameter names and format of the ini file
# e.g. $ob = InformixDB->createFromFile('informix_instance.ini')
#
#-----------------------------------------------------------------------
sub createFromFile
{
    my $class = shift;
    my $ini = shift;
    my $self = {};
    my $ps;

    # Check that param was passed and that file exists 
    if (defined($ini) && -f $ini) { # Call super class constructor
        $self = $class->SUPER::new($ini);
    } else {
        Environment::fatal("InformixDB::createFromFile needs valid *.ini file as input\nExiting...\n");
    }

    bless $self, $class;
    $self->dbSqlOutputFile('sqloutput.log');
    $self->init();

    # Check that config is fully initialised    
    $self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");
    $ps = Environment::getEnvironment()->getPathSeparator();
    my $serverName = $self->instanceName();
    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $self->{'ext'} = '.bat';
        $self->{'ext_r'} = '.bat';
        $self->{'cmd'} = '';
        $self->{'extractToDir'} = "c:${ps}temp${ps}informix";
    }
    else {
        $self->{'ext'} = '';
        $self->{'ext_r'} = '.sh';
        $self->{'cmd'} = 'sh ';
        $self->{'onconfig'} = 'onconfig';
        $self->{'sqlhosts'} = 'sqlhosts';
        $self->{'extractToDir'} = "${ps}tmp${ps}informix";
    }
    $self->{'connectionStr'} = '';
    $self->{'workFile'} = "workfile$self->{'ext'}";
    $self->{'response_file'} = 'informix_response_file.ini';
    $self->instanceName($serverName);
    # Make sure dbDir has a full path and ends with path separator
    $self->setDbDirPath($self->dbDir());
 
    return $self;
}

#-----------------------------------------------------------------------
# $ob = InformixDB->createFromConfig($config)
#-----------------------------------------------------------------------
#
# Create informix object using DatabaseConfig object which is essentially a hash
# of parameter name/value pairs.
# See POD for allowed parameter names and their default values
# $config_values = { db_port => 2317, db_dir => '/home/user/solid/sol_tgt' }
# e.g. $ob = InformixDB->createComplex(DatabaseConfig->createFromHash($config_values))
#
#-----------------------------------------------------------------------
sub createFromConfig
{
    my $class = shift;
    my $config = shift;
    my $self = $class->SUPER::new();

    bless $self, $class;
    $self->dbSqlOutputFile('sqloutput.log');
    $self->init();    

    # override defaults with parameters passed
    if (ref($config) eq 'DatabaseConfig') {
        $self->getConfig()->initFromConfig($config->getParams());    
    } else {
        Environment::fatal("InformixDB::createFromConfig: config parameter not of type \"DatabaseConfig\"\n");
    }
    
    # Check that config is fully initialised    
    $self->getConfig()->checkRequired() or Environment::fatal("Error(s) occurred. Exiting...\n");
    my $ps = Environment::getEnvironment()->getPathSeparator();
    my $serverName = $self->instanceName();
    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $self->{'ext'} = '.bat';
        $self->{'ext_r'} = '.bat';
        $self->{'cmd'} = '';
        $self->{'extractToDir'} = "c:${ps}temp${ps}informix";
    }
    else {
        $self->{'ext'} = '';
        $self->{'ext_r'} = '.sh';
        $self->{'cmd'} = 'sh ';
        $self->{'onconfig'} = 'onconfig';
        $self->{'sqlhosts'} = 'sqlhosts';
        $self->{'extractToDir'} = "${ps}tmp${ps}informix";
    }
    $self->{'connectionStr'} = '';
    $self->{'workFile'} = "workfile$self->{'ext'}";
    $self->{'response_file'} = 'informix_response_file.ini';
    $self->instanceName($serverName);

    # Make sure dbDir has a full path and ends with path separator
    $self->setDbDirPath($self->dbDir());
    return $self;
}

#-----------------------------------------------------------------------
# Database->install([$pathToInstallFromFile)
#-----------------------------------------------------------------------
#
# Reads a zip file by extracting the contents and installs and configures an informix server 
#
#-----------------------------------------------------------------------

sub install
{
    my $self = shift;
    my $fileToBeExtractedFrom = shift;
    my $extractionCmd;
    my $copyCmd;
    my $ps;
    my $instCmd;

    # Generate response file
    $self->generateInstallResponseFile();
    $ps = Environment::getEnvironment()->getPathSeparator();

    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $self->{'response_file'} = Cwd::abs_path($self->{'response_file'});
        $extractionCmd = "7z.exe x $fileToBeExtractedFrom -o$self->{'extractToDir'}>nul 2>&1";
        $self->{'installCmd'} = "$self->{'extractToDir'}${ps}IIF${ps}setup.exe -s ";
        $self->{'installCmd'} = $self->{'installCmd'}.
                                "-f1\"$self->{'response_file'}\" -f2\"c:${ps}temp${ps}log\">nul 2>&1";
        $copyCmd = "copy $self->{'response_file'} $self->{'extractToDir'}${ps}>nul 2>&1"; 
    }
    else {
        # create informix user/group
        system("groupadd ${\$self->dbUser()}"); # create a group
        system("useradd -g ${\$self->dbUser()} -m ${\$self->dbUser()}"); # an informix user
        system("echo ${\$self->dbPass()} | passwd --stdin ${\$self->dbUser()}>&/tmp/out 2>&1"); #...and give it a password  

        # create directory to be extracted to if it does not exist 
        unless (-d $self->{'extractToDir'}) {
            system("mkdir $self->{'extractToDir'}>&/tmp/out 2>&1");
        }

        # create directory to be installed if it does not exist
        unless (-d $self->dbDir()) {
            system("mkdir ${\$self->dbDir()} >&/tmp/out 2>&1");
            system("chown ${\$self->dbUser()}:${\$self->dbUser()} ${\$self->dbDir()}");
        }

        $extractionCmd = "cd $self->{'extractToDir'}; tar xvf $fileToBeExtractedFrom>&/dev/null 2>&1\n";
        $self->{'installCmd'} = "cd $self->{'extractToDir'}${ps}SERVER${ps};";
        $self->{'installCmd'} = $self->{'installCmd'}.$self->{'cmd'}.
                                "./installserver -silent -options $self->{'response_file'}>&/dev/null 2>&1"; 
        #$self->{'installCmd'} = $self->{'installCmd'}.$self->{'cmd'}.
        #                        "./installserver -silent -options $self->{'response_file'}"; 

        $copyCmd = "mv $self->{'response_file'} $self->{'extractToDir'}${ps}SERVER${ps}"; 

        # sqlhosts file create & populate
        $self->generateSQLHosts();

        # onconfig file creat & populate
        $self->generateOnconfig();


        # save their locations
        $self->{'onconfig'} = Cwd::abs_path($self->{'onconfig'});
        $self->{'sqlhosts'} = Cwd::abs_path($self->{'sqlhosts'});
    }

    # perform extraction of zip
    Environment::logf("\n>> Extracting...\n");
    system($extractionCmd);

    # Execute installer using response file
    Environment::logf(">> Installing Informix 11.5 to ${\$self->dbDir()}\n");
    system($copyCmd); 

    # Create script for installing
    $self->createScript($self->{'workFile'});
    open(OUT,">>$self->{'workFile'}") || die ("Could not open file $self->{'workFile'}!");

    print OUT "$self->{'installCmd'}";
    close OUT;

    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        system("$self->{'cmd'}$self->{'workFile'}>nul 2>&1");
    }
    else {
        system("chmod +x $self->{'workFile'}");
        system("$self->{'cmd'}$self->{'workFile'}>/dev/null 2>&1");
    }

    # installation done

    Environment::logf(">> Configuring Informix 11.5...\n");
    if (Environment::getEnvironment()->getOSName() ne 'windows') {
        # informix files
        system("mv $self->{'onconfig'} ${\$self->dbDir()}etc${ps}"); 
        system("mv $self->{'sqlhosts'} ${\$self->dbDir()}etc${ps}"); 

        # sqlhosts
        system("chmod 660 ${\$self->dbDir()}etc${ps}sqlhosts"); 
        system("chgrp ${\$self->dbUser()} ${\$self->dbDir()}etc${ps}sqlhosts"); 
        system("chown ${\$self->dbUser()} ${\$self->dbDir()}etc${ps}sqlhosts"); 

        # onconfig
        system("chmod 660 ${\$self->dbDir()}etc${ps}onconfig"); 
        system("chgrp ${\$self->dbUser()} ${\$self->dbDir()}etc${ps}onconfig"); 
        system("chown ${\$self->dbUser()} ${\$self->dbDir()}etc${ps}onconfig"); 

        system("touch ${\$self->dbDir()}tmp${ps}${\$self->instanceName()}.rootdbs"); 
        system("chmod 660 ${\$self->dbDir()}tmp${ps}${\$self->instanceName()}.rootdbs"); 
        system("chgrp ${\$self->dbUser()} ${\$self->dbDir()}tmp${ps}${\$self->instanceName()}.rootdbs"); 
        system("chown ${\$self->dbUser()} ${\$self->dbDir()}tmp${ps}${\$self->instanceName()}.rootdbs"); 
        system("chown ${\$self->dbUser()} ${\$self->dbDir()}tmp${ps}${\$self->instanceName()}.rootdbs"); 
        system("cd;mkdir logs;mkdir dbspaces;cd dbspaces;touch online_root;chmod 660 online_root");
        
        # /etc/services 
        unless (-e "/etc/services.auto.bak") {
        	system("cp /etc/services /etc/services.auto.bak");
        }
        print "Adding service " . $self->instanceName() . " " . $self->dbPort() . "/tcp\n";
        $self->addInformixUnixService($self->instanceName(), $self->dbPort() . "/tcp", "IBM Informix Instance");
    }
 
    sleep(60); # wait for tidy up

    # initialise database server
    $self->createScript($self->{'workFile'});
    open(OUT, ">>$self->{'workFile'}") || die("Could not open file $self->{'workFile'}!");
    
    if (Environment::getEnvironment()->getOSName() eq 'windows') {
         print OUT "dbaccess - ${\$self->dbDir()}${ps}etc${ps}syscdcv1.sql\n";
         close OUT;

         $instCmd = "$self->{'cmd'}$self->{'workFile'}>nul 2>&1"; # initialise database server
    }
    else {
        Environment::logf(">> Initialising server \"${\$self->instanceName()}\"\n");
        print OUT "oninit -iy\n";
        print OUT "dbaccess - ${\$self->dbDir()}${ps}etc${ps}sysmaster.sql\n";
        print OUT "dbaccess - ${\$self->dbDir()}${ps}etc${ps}syscdcv1.sql\n";
		print OUT "onmode -ky\n";
        close OUT;
        
        system("chmod +x $self->{'workFile'}>&/tmp/out 2>&1");
        $instCmd = "$self->{'cmd'}$self->{'workFile'}>nul 2>&1"; # initialise database server
    }

    system("$instCmd");
    unlink("$self->{'workFile'}");

    # tidy up
    unlink("$self->{'response_file'}");
    Environment::logf(">> Installation Complete for server \"${\$self->instanceName()}\"\n");
}

#-----------------------------------------------------------------------
# Database->setDatabase([$databaseName)
#-----------------------------------------------------------------------
#
# sets object to selected database and creates a connection string
#
#-----------------------------------------------------------------------

sub setDatabase
{
    my $self = shift;
    my $name = shift;
    
    # If no DB selected choose a default to connect to - that is always there
    if (defined($name)) {
    	$self->dbName($name);
    }
    else { # no name passed in
    	$self->dbName('sysadmin');
    }

    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $self->{'connectionStr'} = "connect to '$name\@${\$self->instanceName()}' ".
                                   "user '${\$self->dbUser()}' ".
                                   "using '${\$self->dbPass()}';\n";
    }
    else {
        $self->{'connectionStr'} = "connect to '$name\@" . $self->instanceName() . "';\n";
    }
}

#-----------------------------------------------------------------------
# Database->createDatabase([$databaseName)
#-----------------------------------------------------------------------
#
# creates a database 
#
#-----------------------------------------------------------------------

sub createDatabase
{
    my $self = shift;
    my $name = shift;
    my $cmd;
    
    # Connect ot server first
    $self->setDatabase();
    
    open(OUT, ">$name.sql") || die("Could not open file ${\$self->dbName()}.sql!");
    $cmd = "set lock mode to wait;\n";
    $cmd = $cmd."create database $name with log;\n";
    print OUT "$cmd";
    close OUT;

    $self->dbName($name);
    $self->perform();
    $self->setDatabase($name);
}

#-----------------------------------------------------------------------
# Database->execSqlStmt([$sqlString)
#-----------------------------------------------------------------------
#
# Performs SQL command requested by user 
#
#-----------------------------------------------------------------------

sub execSqlStmt()
{
    my $self = shift;
    my $inCmd = shift;
    my $cmdFile = "$self->{'workFile'}";
    my $cmd;

    $cmd = "$self->{'connectionStr'}\n";
    $cmd = $cmd.$inCmd."\n";

    $self->createScript($cmdFile);

    # populate SQL file
    open(OUT, ">${\$self->dbName()}.sql") || die("Could not open file ${\$self->dbName()}.sql!");
    print OUT "$cmd";
    close OUT;

    $self->perform();
}

#-----------------------------------------------------------------------
# Database->execSql([$sqlFileName)
#-----------------------------------------------------------------------
#
# Executes SQL script from a file 
#
#-----------------------------------------------------------------------

sub execSql()
{
    my $self = shift;
    my $inFile = shift; # name of file with SQL to be performed
    my $cmd;
    my @sqlCmds;

    open(SQL, $inFile) || die("Could not open file $inFile!");
    @sqlCmds=<SQL>;

    # create our SQL script
    open(OUT, ">${\$self->dbName()}.sql") || die("Could not open file ${\$self->dbName()}.sql!");
    print OUT "$self->{'connectionStr'}";    # connection string

    foreach $cmd (@sqlCmds)
    {
        print OUT "$cmd";
    }

    close SQL;
    close(OUT);
    $self->perform();
}

#-----------------------------------------------------------------------
# Database->deleteDatabase([$dbName)
#-----------------------------------------------------------------------
#
# Removes a database from server 
#
#-----------------------------------------------------------------------

sub deleteDatabase()
{ 
    my $self = shift;
    my $dbName = shift; # name of database to be deleted
    my $current_name='';
    my $cmd;
    $cmd = "set lock mode to wait;\n";

    # check are we connected to database to be deleted
    if ($dbName == $self->dbName()) {
        $cmd = $cmd."disconnect $dbName\@${\$self->instanceName()};\n";
    }
    elsif ($self->dbName() == '') {
        $self->dbName($dbName); # we were not connected to anything
    }
    else { # save the name of the database currently working with
        $current_name = $self->dbName();
    }

    $cmd = $cmd."drop database $dbName\@${\$self->instanceName()};\n";

    open(OUT, ">$dbName.sql") || die("Could not open file $dbName.sql!");
    print OUT "$cmd";
    close OUT;

    $self->perform(); # remove it

    if ($dbName == $self->dbName()) {
        $self->dbName('');
    }
    elsif ($current_name ne '') { # there was a database selected
        # put back the name of the database we're working with
        $self->dbName($current_name);
    }
}

#-----------------------------------------------------------------------
# Database->uninstall()
#-----------------------------------------------------------------------
#
# Removes the server from system 
#
#-----------------------------------------------------------------------

sub uninstall
{
    my $self = shift;

    Environment::logf("\n>> Uninstalling \"${\$self->instanceName()}\"...\n");
    
    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        # Generate response file
        $self->generateUninstallResponseFile();
        
        # Update response file to be an absolute path, as this is required for installer
        $self->{'response_file'} = Cwd::abs_path($self->{'response_file'});
    
        # ... now uninstall
        system("$self->{'extractToDir'}\\IIF\\setup.exe -s -f1\"$self->{'response_file'}\"");
        unlink($self->{'$response_file'});
    }
    else {
        # initialise database server
        $self->createScript($self->{'workFile'});

        open(OUT, ">>$self->{'workFile'}") || die("Could not open file $self->{'workFile'}!");
        print OUT "onmode -ky\n"; # stop Informix server    
        close OUT;

        system("$self->{'cmd'}$self->{'workFile'}");
        # remove all trace of user/group
        system("userdel -r informix"); # remove user
    }
    
    # ...and tidyup
    rmtree([$self->dbDir()], 0, 0);
    rmtree([$self->{'extractToDir'}], 0, 0);
    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        unlink(".${\$self->instanceName()}.alarm");
    }
    Environment::logf("\n>> Uninstalled \"${\$self->instanceName()}\"\n");
}

#-----------------------------------------------------------------------
# Database->generateSQLHosts()
#-----------------------------------------------------------------------
#
# Private Function 
# Generates SQL hosts file.
#
#-----------------------------------------------------------------------

sub generateSQLHosts
{
    my $self = shift;
    my $SQLHOSTS_FILE;

    $SQLHOSTS_FILE=<<END;
    ${\$self->instanceName()} onsoctcp ${\$self->dbHost()} ${\$self->instanceName()}
END

    open(OUT, ">$self->{'sqlhosts'}") || die("Could not open file $self->{'sqlhosts'}!");
    print OUT $SQLHOSTS_FILE . "\n";
    close(OUT);
}

#-----------------------------------------------------------------------
# Database->generateOnconfig()
#-----------------------------------------------------------------------
#
# Private Function 
# Generates onconfig file.
#
#-----------------------------------------------------------------------

sub generateOnconfig
{
    my $self = shift;
    my $ONCONFIG_FILE;
    my $ps = Environment::getEnvironment()->getPathSeparator();

    if (Environment::getEnvironment()->getOSName() ne 'windows') {
$ONCONFIG_FILE=<<END;
###################################################################
# Licensed Material - Property Of IBM
#
# "Restricted Materials of IBM"
#
# IBM Informix Dynamic Server
# Copyright IBM Corporation 1996, 2009. All rights reserved.
#
# Title: onconfig.std
# Description: IBM Informix Dynamic Server Configuration Parameters
#
#
# For additional information on the parameters:
# http://publib.boulder.ibm.com/infocenter/idshelp/v115/index.jsp
###################################################################

###################################################################
# Root Dbspace Configuration Parameters
###################################################################
# ROOTNAME     - The root dbspace name to contain reserved pages and
#                internal tracking tables.
# ROOTPATH     - The path for the device containing the root dbspace
# ROOTOFFSET   - The offset, in KB, of the root dbspace into the 
#                device. The offset is required for some raw devices. 
# ROOTSIZE     - The size of the root dbspace, in KB.  The value of 
#                200000 allows for a default user space of about 
#                100 MB and the default system space requirements.
# MIRROR       - Enable (1) or disable (0) mirroring
# MIRRORPATH   - The path for the device containing the mirrored 
#                root dbspace
# MIRROROFFSET - The offset, in KB, into the mirrored device 
#
# Warning: Always verify ROOTPATH before performing
#          disk initialization (oninit -i or -iy) to
#          avoid disk corruption of another instance
###################################################################

ROOTNAME rootdbs

ROOTPATH ${\$self->dbDir()}tmp${ps}${\$self->instanceName()}.rootdbs
ROOTOFFSET 0
ROOTSIZE 800000
MIRROR 0
MIRRORPATH ${\$self->dbDir()}tmp${ps}demo_on.root_mirror
MIRROROFFSET 0

###################################################################
# Physical Log Configuration Parameters
###################################################################
# PHYSFILE           - The size, in KB, of the physical log on disk.
#                      If RTO_SERVER_RESTART is enabled, the 
#                      suggested formula for the size of PHSYFILE 
#                      (up to about 1 GB) is:
#                          PHYSFILE = Size of BUFFERS * 1.1
# PLOG_OVERFLOW_PATH - The directory for extra physical log files
#                      if the physical log overflows during recovery
#                      or long transaction rollback
# PHYSBUFF           - The size of the physical log buffer, in KB
###################################################################

PHYSFILE 50000
PLOG_OVERFLOW_PATH  ${\$self->dbDir()}tmp
PHYSBUFF 128

###################################################################
# Logical Log Configuration Parameters
###################################################################
# LOGFILES     - The number of logical log files
# LOGSIZE      - The size of each logical log, in KB
# DYNAMIC_LOGS - The type of dynamic log allocation.
#                Acceptable values are:
#                2 Automatic. IDS adds a new logical log to the
#                  root dbspace when necessary.
#                1 Manual. IDS notifies the DBA to add new logical
#                  logs when necessary.
#                0 Disabled
# LOGBUFF      - The size of the logical log buffer, in KB
###################################################################

LOGFILES 64
LOGSIZE 10000
DYNAMIC_LOGS 2
LOGBUFF 64

###################################################################
# Long Transaction Configuration Parameters
###################################################################
# If IDS cannot roll back a long transaction, the server hangs
# until more disk space is available.
#
# LTXHWM       - The percentage of the logical logs that can be
#                filled before a transaction is determined to be a
#                long transaction and is rolled back
# LTXEHWM      - The percentage of the logical logs that have been
#                filled before the server suspends all other
#                transactions so that the long transaction being 
#                rolled back has exclusive use of the logs
#
# When dynamic logging is on, you can set higher values for
# LTXHWM and LTXEHWM because the server can add new logical logs
# during long transaction rollback. Set lower values to limit the 
# number of new logical logs added.
#
# If dynamic logging is off, set LTXHWM and LTXEHWM to
# lower values, such as 50 and 60 or lower, to prevent long 
# transaction rollback from hanging the server due to lack of 
# logical log space.
#
# When using Enterprise Replication, set LTXEHWM to at least 30%
# higher than LTXHWM to minimize log overruns.
###################################################################

LTXHWM 70
LTXEHWM 80

###################################################################
# Server Message File Configuration Parameters
###################################################################
# MSGPATH      - The path of the IDS message log file
# CONSOLE      - The path of the IDS console message file
###################################################################

MSGPATH ${\$self->dbDir()}tmp${ps}online.log
CONSOLE ${\$self->dbDir()}tmp${ps}online.con

###################################################################
# Tblspace Configuration Parameters
###################################################################
# TBLTBLFIRST    - The first extent size, in KB, for the tblspace
#                  tblspace. Must be in multiples of the page size.
# TBLTBLNEXT     - The next extent size, in KB, for the tblspace
#                  tblspace. Must be in multiples of the page size.
# The default setting for both is 0, which allows IDS to manage 
# extent sizes automatically.
#
# TBLSPACE_STATS - Enables (1) or disables (0) IDS to maintain 
#                  tblspace statistics
###################################################################

TBLTBLFIRST 0
TBLTBLNEXT 0
TBLSPACE_STATS 1

###################################################################
# Temporary dbspace and sbspace Configuration Parameters
###################################################################
# DBSPACETEMP  - The list of dbspaces used to store temporary
#                tables and other objects. Specify a colon
#                separated list of dbspaces that exist when the
#                server is started. If no dbspaces are specified, 
#                or if all specified dbspaces  are not valid, 
#                temporary files are created in the /tmp directory
#                instead.
# SBSPACETEMP  - The list of sbspaces used to store temporary 
#                tables for smart large objects. If no sbspace
#                is specified, temporary files are created in
#                a standard sbspace.
###################################################################

DBSPACETEMP 
SBSPACETEMP

###################################################################
# Dbspace and sbspace Configuration Parameters
###################################################################
# SBSPACENAME    - The default sbspace name where smart large objects
#                  are stored if no sbspace is specified during
#                  smart large object creation. Some DataBlade
#                  modules store smart large objects in this 
#                  location.
# SYSSBSPACENAME - The default sbspace for system statistics 
#                  collection. Otherwise, IDS stores statistics 
#                  in the sysdistrib system catalog table.
# ONDBSPACEDOWN  - Specifies how IDS behaves when it encounters a
#                  dbspace that is offline. Acceptable values 
#                  are:
#                  0 Continue
#                  1 Stop
#                  2 Wait for DBA action
###################################################################

SBSPACENAME
SYSSBSPACENAME
ONDBSPACEDOWN 2


###################################################################
# System Configuration Parameters
###################################################################
# SERVERNUM       - The unique ID for the IDS instance. Acceptable 
#                   values are 0 through 255, inclusive.
# DBSERVERNAME    - The name of the default database server
# DBSERVERALIASES - The list of up to 32 alternative dbservernames, 
#                   separated by commas
###################################################################

SERVERNUM 0
DBSERVERNAME ${\$self->instanceName()}
DBSERVERALIASES

###################################################################
# Network Configuration Parameters
###################################################################
# NETTYPE                    - The configuration of poll threads
#                              for a specific protocol. The
#                              format is:
#                              NETTYPE <protocol>,<# poll threads>
#                              ,<number of connections/thread>
#                              ,(NET|CPU)
#                              You can include multiple NETTYPE
#                              entries for multiple protocols.
# LISTEN_TIMEOUT             - The number of seconds that IDS
#                              waits for a connection
# MAX_INCOMPLETE_CONNECTIONS - The maximum number of incomplete
#                              connections before IDS logs a Denial
#                              of Service (DoS) error
# FASTPOLL             - Enables (1) or disables (0) fast  
#                              polling of your network, if your  
#                              operating system supports it.
###################################################################

NETTYPE ipcshm,1,50,CPU
LISTEN_TIMEOUT 60
MAX_INCOMPLETE_CONNECTIONS 1024
FASTPOLL 1

###################################################################
# CPU-Related Configuration Parameters
###################################################################
# MULTIPROCESSOR      - Specifies whether the computer has multiple
#                       CPUs. Acceptable values are: 0 (single
#                       processor), 1 (multiple processors or
#                       multi-core chips)
# VPCLASS cpu         - Configures the CPU VPs. The format is:
#                       VPCLASS cpu,num=<#>[,max=<#>][,aff=<#>]
#                       [,noage]
# VP_MEMORY_CACHE_KB  - Specifies the amount of private memory 
#                       blocks of your CPU VP, in KB, that the 
#                       database server can access. 
#                       Acceptable values are:
#                       0 (disable)
#                       800 through 40% of the value of SHMTOTAL
# SINGLE_CPU_VP       - Optimizes performance if IDS runs with
#                       only one CPU VP. Acceptable values are:
#                       0 multiple CPU VPs 
#                       Any nonzero value (optimize for one CPU VP)
###################################################################

MULTIPROCESSOR 0
VPCLASS cpu,num=1,noage
VP_MEMORY_CACHE_KB 0
SINGLE_CPU_VP 0

###################################################################
# AIO and Cleaner-Related Configuration Parameters
###################################################################
# VPCLASS aio  - Configures the AIO VPs. The format is:
#                VPCLASS aio,num=<#>[,max=<#>][,aff=<#>][,noage] 
# CLEANERS     - The number of page cleaner threads
# AUTO_AIOVPS  - Enables (1) or disables (0) automatic management 
#                of AIO VPs
# DIRECT_IO    - Specifies whether direct I/O is used for cooked
#                files used for dbspace chunks.
#                Acceptable values are:
#                0 Disable
#                1 Enable direct I/O
#                2 Enable concurrent I/O
###################################################################

#VPCLASS aio,num=1
CLEANERS 8
AUTO_AIOVPS 1
DIRECT_IO 0

###################################################################
# Lock-Related Configuration Parameters
###################################################################
# LOCKS              - The initial number of locks when IDS starts.
#                      Dynamic locking can add extra locks if needed.
# DEF_TABLE_LOCKMODE - The default table lock mode for new tables.
#                      Acceptable values are ROW and PAGE (default).
###################################################################

LOCKS 20000
DEF_TABLE_LOCKMODE page 

###################################################################
# Shared Memory Configuration Parameters
###################################################################
# RESIDENT         - Controls whether shared memory is resident.
#                    Acceptable values are:
#                    0 off (default)
#                    1 lock the resident segment only
#                    n lock the resident segment and the next n-1 
#                       virtual segments, where n < 100
#                    -1 lock all resident and virtual segments
# SHMBASE          - The shared memory base address; do not change
# SHMVIRTSIZE      - The initial size, in KB, of the virtual
#                    segment of shared memory
# SHMADD           - The size, in KB, of additional virtual shared
#                    memory segments
# EXTSHMADD        - The size, in KB, of each extension shared
#                    memory segment
# SHMTOTAL         - The maximum amount of shared memory for IDS,
#                    in KB. A 0 indicates no specific limit.
# SHMVIRT_ALLOCSEG - Controls when IDS adds a memory segment and
#                    the alarm level if the memory segment cannot
#                    be added.
#                    For the first field, acceptable values are: 
#                    - 0 Disabled
#                    - A decimal number indicating the percentage 
#                      of memory used before a segment is added
#                    - The number of KB remaining when a segment
#                      is added
#                    For the second field, specify an alarm level 
#                    from 1 (non-event) to 5 (fatal error).
# SHMNOACCESS      - A list of up to 10 memory address ranges 
#                    that IDS cannot use to attach shared memory. 
#                    Each address range is the start and end memory  
#                    address in hex format, separated by a hyphen.  
#                    Use a comma to separate each range in the list.
###################################################################

RESIDENT 0
SHMBASE 0x44000000L 
SHMVIRTSIZE 32656
SHMADD 8192
EXTSHMADD 8192
SHMTOTAL 0
SHMVIRT_ALLOCSEG 0,3
SHMNOACCESS

###################################################################
# Checkpoint and System Block Configuration Parameters
###################################################################
# CKPINTVL           - Specifies how often, in seconds, IDS checks
#                      if a checkpoint is needed. 0 indicates that
#                      IDS does not check for checkpoints. Ignored 
#                      if RTO_SERVER_RESTART is set.
# AUTO_CKPTS         - Enables (1) or disables (0) monitoring of 
#                      critical resource to trigger checkpoints 
#                      more frequently if there is a chance that 
#                      transaction blocking might occur.
# RTO_SERVER_RESTART - Specifies, in seconds, the Recovery Time 
#                      Objective for IDS restart after a server 
#                      failure. Acceptable values are 0 (off) and
#                      any number from 60-1800, inclusive.
# BLOCKTIMEOUT       - Specifies the amount of time, in seconds,
#                      for a system block.
###################################################################

CKPTINTVL 300
AUTO_CKPTS 1
RTO_SERVER_RESTART 0
BLOCKTIMEOUT 3600

###################################################################
# Transaction-Related Configuration Parameters
###################################################################
# TXTIMEOUT        - The distributed transaction timeout, in seconds
# DEADLOCK_TIMEOUT - The maximum time, in seconds, to wait for a 
#                    lock in a distributed transaction.
# HETERO_COMMIT    - Enables (1) or disables (0) heterogeneous 
#                    commits for a distributed transaction
#                    involving an EGM gateway. 
###################################################################

TXTIMEOUT 300
DEADLOCK_TIMEOUT 60
HETERO_COMMIT 0

###################################################################
# ontape Tape Device Configuration Parameters
###################################################################
# TAPEDEV      - The tape device path for backups. To use standard
#                I/O instead of a device, set to stdio.
# TAPEBLK      - The tape block size, in KB, for backups
# TAPESIZE     - The maximum amount of data to put on one backup
#                tape. Acceptable values are 0 (unlimited) or any
#                positive integral multiple of TAPEBLK.
###################################################################

TAPEDEV /dev/tapedev
TAPEBLK 32
TAPESIZE 0

###################################################################
# ontape Logial Log Tape Device Configuration Parameters
###################################################################
# LTAPEDEV     - The tape device path for logical logs
# LTAPEBLK     - The tape block size, in KB, for backing up logical 
#                logs
# LTAPESIZE    - The maximum amount of data to put on one logical
#                log tape. Acceptable values are 0 (unlimited) or any
#                positive integral multiple of LTAPEBLK.
###################################################################

LTAPEDEV /dev/null
LTAPEBLK 32
LTAPESIZE 0

###################################################################
# Backup and Restore Configuration Parameters
###################################################################
# BAR_ACT_LOG         - The ON-Bar activity log file location.
#                       Do not use the /tmp directory. Use a 
#                       directory with restricted permissions.
# BAR_DEBUG_LOG       - The ON-Bar debug log file location.
#                       Do not use the /tmp directory. Use a 
#                       directory with restricted permissions.
# BAR_DEBUG           - The debug level for ON-Bar. Acceptable
#                       values are 0 (off) through 9 (high).
# BAR_MAX_BACKUP      - The number of backup threads used in a
#                       backup. Acceptable values are 0 (unlimited)
#                       or any positive integer.
# BAR_RETRY           - Specifies the number of time to retry a
#                       backup or restore operation before reporting 
#                       a failure
# BAR_NB_XPORT_COUNT  - Specifies the number of data buffers that
#                       each onbar_d process uses to communicate
#                       with the database server
# BAR_XFER_BUF_SIZE   - The size, in pages, of each data buffer.
#                       Acceptable values are 1 through 15 for 
#                       4 KB pages and 1 through 31 for 2 KB pages.
# RESTARTABLE_RESTORE - Enables ON-Bar to continue a backup after a
#                       failure. Acceptable values are OFF or ON.
# BAR_PROGRESS_FREQ   - Specifies, in minutes, how often progress
#                       messages are placed in the ON-Bar activity
#                       log. Acceptable values are: 0 (record only
#                       completion messages) or 5 and above.
# BAR_BSALIB_PATH     - The shared library for ON-Bar and the 
#                       storage manager. The default value is
#                       platform-specific file extension). 
# BACKUP_FILTER       - Specifies the pathname of a filter program 
#                       to transform data during a backup, plus any 
#                       program options
# RESTORE_FILTER      - Specifies the pathname of a filter program 
#                       to transform data during a restore, plus any 
#                       program options
# BAR_PERFORMANCE     - Specifies the type of performance statistics
#                       to report to the ON-Bar activity log for backup
#                       and restore operations.
#                       Acceptable values are:
#                        0 = Turn off performance monitoring (Default)
#                        1 = Display the time spent transferring data
#                            between the IDS instance and the storage
#                            manager
#                        2 = Display timestamps in microseconds
#                        3 = Display both timestamps and transfer
#                            statistics
###################################################################

BAR_ACT_LOG ${\$self->dbDir()}tmp${ps}bar_act.log
BAR_DEBUG_LOG ${\$self->dbDir()}tmp${ps}bar_dbug.log
BAR_DEBUG 0
BAR_MAX_BACKUP 0
BAR_RETRY 1
BAR_NB_XPORT_COUNT 20
BAR_XFER_BUF_SIZE 31
RESTARTABLE_RESTORE ON
BAR_PROGRESS_FREQ 0
BAR_BSALIB_PATH
BACKUP_FILTER
RESTORE_FILTER
BAR_PERFORMANCE 0

###################################################################
# Informix Storage Manager (ISM) Configuration Parameters
###################################################################
# ISM_DATA_POOL - Specifies the name for the ISM data pool
# ISM_LOG_POOL  - Specifies the name for the ISM log pool
###################################################################

ISM_DATA_POOL ISMData
ISM_LOG_POOL ISMLogs

###################################################################
# Data Dictionary Cache Configuration Parameters
###################################################################
# DD_HASHSIZE  - The number of data dictionary pools. Set to any
#                positive integer; a prime number is recommended.
# DD_HASHMAX   - The number of entries per pool.
#                Set to any positive integer.
###################################################################

DD_HASHSIZE 31
DD_HASHMAX  10

###################################################################
# Data Distribution Configuration Parameters
###################################################################
# DS_HASHSIZE  - The number of data Ddstribution pools.
#                Set to any positive integer; a prime number is 
#                recommended.
# DS_POOLSIZE  - The maximum number of entries in the data 
#                distribution cache. Set to any positive integer.
###################################################################

DS_HASHSIZE 31
DS_POOLSIZE 127

##################################################################
# User Defined Routine (UDR) Cache Configuration Parameters
##################################################################
# PC_HASHSIZE  - The number of UDR pools. Set to any
#                positive integer; a prime number is recommended.
# PC_POOLSIZE  - The maximum number of entries in the
#                UDR cache. Set to any positive integer.
###################################################################

PC_HASHSIZE 31
PC_POOLSIZE 127

###################################################################
# SQL Statement Cache Configuration Parameters
###################################################################
# STMT_CACHE         - Controls SQL statement caching. Acceptable
#                      values are: 
#                      0 Disabled
#                      1 Enabled at the session level
#                      2 All statements are cached
# STMT_CACHE_HITS    - The number of times an SQL statement must be
#                      executed before becoming fully cached.
#                      0 indicates that all statements are
#                      fully cached the first time.
# STMT_CACHE_SIZE    - The size, in KB, of the SQL statement cache
# STMT_CACHE_NOLIMIT - Controls additional memory consumption.
#                      Acceptable values are:
#                      0 Limit memory to STMT_CACHE_SIZE
#                      1 Obtain as much memory, temporarily, as needed
# STMT_CACHE_NUMPOOL - The number of pools for the SQL statement
#                      cache. Acceptable value is a positive
#                      integer between 1 and 256, inclusive.
###################################################################

STMT_CACHE 0
STMT_CACHE_HITS 0
STMT_CACHE_SIZE 512
STMT_CACHE_NOLIMIT 0
STMT_CACHE_NUMPOOL 1

###################################################################
# Operating System Session-Related Configuration Parameters
###################################################################
# USEOSTIME        - The precision of SQL statement timing.
#                    Accepted values are 0 (precision to seconds)
#                    and 1 (precision to subseconds). Subsecond
#                    precision can degrade performance.
# STACKSIZE        - The size, in KB, for a session stack
# ALLOW_NEWLINE    - Controls whether embedded new line characters
#                    in string literals are allowed in SQL 
#                    statements. Acceptable values are 1 (allowed) 
#                    and any number other than 1 (not allowed).
# USELASTCOMMITTED - Controls the committed read isolation level.
#                    Acceptable values are:
#                    - NONE Waits on a lock 
#                    - DIRTY READ Uses the last committed value in 
#                      place of a dirty read 
#                    - COMMITTED READ Uses the last committed value 
#                      in place of a committed read  
#                    - ALL Uses the last committed value in place  
#                      of all isolation levels that support the last
#                      committed option 
###################################################################

USEOSTIME 0
STACKSIZE 64
ALLOW_NEWLINE 0
USELASTCOMMITTED NONE

###################################################################
# Index Related Configuration Parameters
###################################################################
# FILLFACTOR          - The percentage of index page fullness
# MAX_FILL_DATA_PAGES - Enables (1) or disables (0) filling data
#                       pages that have variable length rows as
#                       full as possible
# BTSCANNER           - Specifies the configuration settings for all
#                       btscanner threads. The format is:
#                       BTSCANNER num=<#>,threshold=<#>,rangesize=<#>,
#                       alice=(0-12),compression=[low|med|high|default]
# ONLIDX_MAXMEM       - The amount of memory, in KB, allocated for 
#                       the pre-image pool and updator log pool for 
#                       each partition.
###################################################################

FILLFACTOR 90
MAX_FILL_DATA_PAGES 0
BTSCANNER num=1,threshold=5000,rangesize=-1,alice=6,compression=default
ONLIDX_MAXMEM 5120

###################################################################
# Parallel Database Query (PDQ) Configuration Parameters
###################################################################
# MAX_PDQPRIORITY     - The maximum amount of resources, as a
#                       percentage, that PDQ can allocate to any
#                       one decision support query
# DS_MAX_QUERIES      - The maximum number of concurrent decision
#                       support queries
# DS_TOTAL_MEMORY     - The maximum amount, in KB, of decision 
#                       support query memory
# DS_MAX_SCANS        - The maximum number of concurrent decision
#                       support scans
# DS_NONPDQ_QUERY_MEM - The amount of non-PDQ query memory, in KB.
#                       Acceptable values are 128 to 25% of
#                       DS_TOTAL_MEMORY.
# DATASKIP            - Specifies whether to skip dbspaces when
#                       processing a query. Acceptable values are:
#                       - ALL Skip all unavailable fragments
#                       - ON <dbspace1> <dbspace2>... Skip listed 
#                         dbspaces
#                       - OFF Do not skip dbspaces (default)
###################################################################

MAX_PDQPRIORITY 100
DS_MAX_QUERIES
DS_TOTAL_MEMORY
DS_MAX_SCANS 1048576
DS_NONPDQ_QUERY_MEM 128
DATASKIP

###################################################################
# Optimizer Configuration Parameters
###################################################################
# OPTCOMPIND     - Controls how the optimizer determines the best
#                  query path. Acceptable values are:
#                  0 Nested loop joins are preferred
#                  1 If isolation level is repeatable read,
#                    works the same as 0, otherwise works same as 2
#                  2 Optimizer decisions are based on cost only
# DIRECTIVES     - Specifies whether optimizer directives are
#                  enabled (1) or disabled (0). Default is 1.
# EXT_DIRECTIVES - Controls the use of external SQL directives.
#                  Acceptable values are:
#                  0 Disabled
#                  1 Enabled if the IFX_EXTDIRECTIVES environment
#                     variable is enabled
#                  2 Enabled even if the IFX_EXTDIRECTIVES 
#                     environment is not set
# OPT_GOAL       - Controls how the optimizer should optimize for
#                  fastest retrieval. Acceptable values are:
#                  -1 All rows in a query
#                  0 The first rows in a query
# IFX_FOLDVIEW   - Enables (1) or disables (0) folding views that  
#                  have multiple tables or a UNION ALL clause. 
#                  Disabled by default.
# AUTO_REPREPARE - Enables (1) or disables (0) automatically 
#                  re-optimizing stored procedures and re-preparing 
#                  prepared statements when tables that are referenced 
#                  by them change. Minimizes the occurrence of the 
#                  -710 error.
####################################################################

OPTCOMPIND 2
DIRECTIVES 1
EXT_DIRECTIVES 0
OPT_GOAL -1
IFX_FOLDVIEW 0
AUTO_REPREPARE 1

###################################################################
# Read-ahead Configuration Parameters
###################################################################
#RA_PAGES      - The number of pages, as a positive integer, to 
#                attempt to read ahead
#RA_THRESHOLD  - The number of pages, as a postive integer, left 
#                before the next read-ahead group
###################################################################

RA_PAGES     64
RA_THRESHOLD 16

###################################################################
# SQL Tracing and EXPLAIN Plan Configuration Parameters
###################################################################
# EXPLAIN_STAT - Enables (1) or disables (0) including the Query 
#                Statistics section in the EXPLAIN output file
# SQLTRACE     - Configures SQL tracing. The format is:
#                SQLTRACE level=(low|med|high),ntraces=<#>,size=<#>,
#                mode=(global|user)
###################################################################

EXPLAIN_STAT 1
#SQLTRACE level=low,ntraces=1000,size=2,mode=global

###################################################################
# Security Configuration Parameters
###################################################################
# DBCREATE_PERMISSION        - Specifies the users who can create
#                              databases (by default, any user can).
#                              Add a DBCREATE_PERMISSION entry
#                              for each user who needs database
#                              creation privileges. Ensure user
#                              informix is authorized when you
#                              first initialize IDS.
# DB_LIBRARY_PATH            - Specifies the locations, separated
#                              by commas, from which IDS can use
#                              UDR or UDT shared libraries. If set,
#                              make sure that all directories containing 
#                      the blade modules are listed, to
#                              ensure all DataBlade modules will  
#                              work.
# IFX_EXTEND_ROLE            - Controls whether administrators 
#                              can use the EXTEND role to specify
#                              which users can register external
#                              routines. Acceptable values are:
#                              0 Any user can register external 
#                                 routines
#                              1 Only users granted the ability
#                                to register external routines
#                                can do so (Default)
# SECURITY_LOCALCONNECTION   - Specifies whether IDS performs
#                              security checking for local
#                              connections. Acceptable values are: 
#                              0 Off
#                              1 Validate ID
#                              2 Validate ID and port
# UNSECURE_ONSTAT            - Controls whether non-DBSA users are
#                              allowed to run all onstat commands.
#                              Acceptable values are:
#                              1 Enabled 
#                              0 Disabled (Default)
# ADMIN_USER_MODE_WITH_DBSA  - Controls who can connect to IDS
#                              in administration mode. Acceptable
#                              values are:
#                              1 DBSAs, users specified by
#                                 ADMIN_MODE_USERS, and the user
#                                 informix
#                              0 Only the user informix (Default) 
# ADMIN_MODE_USERS           - Specifies the user names, separated by
#                              commas, who can connect to IDS in
#                              administration mode, in addition to
#                              the user informix
# SSL_KEYSTORE_LABEL         - The label, up to 512 characters, of
#                   the IDS certificate used in Secure
#                   Sockets Layer (SSL) protocol 
#                   communications.
###################################################################


#DBCREATE_PERMISSION informix
#DB_LIBRARY_PATH 
IFX_EXTEND_ROLE 1
SECURITY_LOCALCONNECTION
UNSECURE_ONSTAT
ADMIN_USER_MODE_WITH_DBSA
ADMIN_MODE_USERS
SSL_KEYSTORE_LABEL
###################################################################
# LBAC Configuration Parameters
###################################################################
# PLCY_POOLSIZE - The maximum number of entries in each hash 
#                 bucket of the LBAC security information cache
# PLCY_HASHSIZE - The number of hash buckets in the LBAC security 
#                 information cache
# USRC_POOLSIZE - The maximum number of entries in each hash 
#                 bucket of the LBAC credential memory cache
# USRC_HASHSIZE - The number of hash buckets in the LBAC credential 
#                 memory cache
###################################################################

PLCY_POOLSIZE 127
PLCY_HASHSIZE 31
USRC_POOLSIZE 127
USRC_HASHSIZE 31

###################################################################
# Optical Configuration Parameters
###################################################################
# STAGEBLOB    - The name of the optical blobspace. Must be set to
#                use the optical-storage subsystem.
# OPCACHEMAX   - Maximum optical cache size, in KB
###################################################################

STAGEBLOB
OPCACHEMAX 0

###################################################################
# High Availability and Enterprise Replication Security
# Configuration Parameters
###################################################################
# ENCRYPT_HDR     - Enables (1) or disables (0) encryption for HDR.
# ENCRYPT_SMX     - Controls the level of encryption for RSS and
#                   SDS servers. Acceptable values are:
#                   0 Do not encrypt (Default)
#                   1 Encrypt if possible
#                   2 Always encrypt
# ENCRYPT_CDR     - Controls the level of encryption for ER. 
#                   Acceptable values are: 
#                   0 Do not encrypt (Default)
#                   1 Encrypt if possible
#                   2 Always encrypt
# ENCRYPT_CIPHERS - A list of encryption ciphers and modes, 
#                   separated by commas. Default is all.
# ENCRYPT_MAC     - Controls the level of message authentication
#                   code (MAC). Acceptable values are off, high, 
#                   medium, and low. List multiple values separated
#                   by commas; the highest common level between
#                   servers is used.
# ENCRYPT_MACFILE - The paths of the MAC key files, separated
#                   by commas. Use the builtin keyword to specify 
#                   the built-in key. Default is builtin.
# ENCRYPT_SWITCH  - Defines the frequencies, in minutes, at which 
#                   ciphers and keys are renegotiated. Format is:
#                   <cipher_switch_time>,<key_switch_time>
#                   Default is 60,60.
###################################################################

ENCRYPT_HDR
ENCRYPT_SMX
ENCRYPT_CDR 0
ENCRYPT_CIPHERS
ENCRYPT_MAC
ENCRYPT_MACFILE
ENCRYPT_SWITCH


###################################################################
# Enterprise Replication (ER) Configuration Parameters
###################################################################
# CDR_EVALTHREADS         - The number of evaluator threads per
#                           CPU VP and the number of additional 
#                           threads, separated by a comma. 
#                           Acceptable values are: a non-zero value
#                           followed by a non-negative value
# CDR_DSLOCKWAIT          - The number of seconds the Datasync
#                           waits for database locks.
# CDR_QUEUEMEM            - The maximum amount of memory, in KB,
#                           for the send and receive queues.
# CDR_NIFCOMPRESS         - Controls the network interface 
#                           compression level.
#                           Acceptable values are: 
#                           -1 Never 
#                           0 None
#                           1-9 Compression level
# CDR_SERIAL              - Specifies the incremental size and
#                           the starting value of replicated 
#                           serial columns. The format is:
#                           <delta>,<offset>
# CDR_DBSPACE             - The dbspace name for the syscdr
#                           database.
# CDR_QHDR_DBSPACE        - The name of the transaction record
#                           dbspace. Default is the root dbspace.
# CDR_QDATA_SBSPACE       - The names of sbspaces for spooled
#                           transaction data, separated by commas.
# CDR_MAX_DYNAMIC_LOGS    - The maximum number of dynamic log
#                           requests that ER can make within one
#                           server session. Acceptable values are:
#                           -1 (unlimited), 0 (disabled),
#                           1 through n (limit to n requests)
# CDR_SUPPRESS_ATSRISWARN - The Datasync error and warning code 
#                           numbers to be suppressed in ATS and RIS 
#                           files. Acceptable values are: numbers
#                           or ranges of numbers separated by commas.  
#                           Separate numbers in a range by a hyphen.
###################################################################

CDR_EVALTHREADS 1,2
CDR_DSLOCKWAIT 5
CDR_QUEUEMEM 4096
CDR_NIFCOMPRESS 0
CDR_SERIAL 0
CDR_DBSPACE
CDR_QHDR_DBSPACE
CDR_QDATA_SBSPACE
CDR_MAX_DYNAMIC_LOGS 0
CDR_SUPPRESS_ATSRISWARN


###################################################################
# High Availability Cluster (HDR, SDS, and RSS) 
# Configuration Parameters
###################################################################
# DRAUTO            - Controls automatic failover of primary  
#                     servers. Valid for HDR, SDS, and RSS.
#                     Acceptable values are: 
#                     0 Manual
#                     1 Retain server type
#                     2 Reverse server type
#                     3 Connection Manager Arbitrator controls 
#                       server type                    
# DRINTERVAL        - The maximum interval, in seconds, between HDR
#                     buffer flushes. Valid for HDR only.
# DRTIMEOUT         - The time, in seconds, before a network
#                     timeout occurs. Valid for HDR only.
# DRLOSTFOUND       - The path of the HDR lost-and-found file.
#                     Valid of HDR only.
# DRIDXAUTO         - Enables (1) or disables (0) automatic index 
#                     repair for an HDR pair. Default is 0. 
# HA_ALIAS          - The server alias for a high-availability 
#                     cluster. Must be the same as a value of 
#                     DBSERVERNAME or DBSERVERALIASES that uses a  
#                     network-based connection type. Valid for HDR, 
#                     SDS, and RSS.
# LOG_INDEX_BUILDS  - Enable (1) or disable (0) index page logging.
#                     Required for RSS. Optional for HDR and SDS.
# SDS_ENABLE        - Enables (1) or disables (0) an SDS server.
#              Set this value on an SDS server after setting 
#              up the primary. Valid for SDS only.
# SDS_TIMEOUT       - The time, in seconds, that the primary waits  
#               for an acknowledgement from an SDS server  
#              while performing page flushing before marking  
#                     the SDS server as down. Valid for SDS only.
# SDS_TEMPDBS       - The temporary dbspace used by an  SDS server.
#                     The format is:
#              <dbspace_name>,<path>,<pagesize in KB>,<offset in KB>,
#                     <size in KB> 
#                     You can include up to 16 entries of SDS_TEMPDBS to 
#              specify additional dbspaces. Valid for SDS.
# SDS_PAGING        - The paths of two buffer paging files, 
#                     Separated by a comma. Valid for SDS only.
# UPDATABLE_SECONDARY - Controls whether secondary servers can accept 
#                     update, insert, and delete operations from clients.
#                     If enabled, specifies the number of connection 
#                     threads between the secondary and primary servers 
#                     for transmitting updates from the secondary. 
#                     Acceptable values are: 
#                         0  Secondary server is read-only (default)
#                         1 through twice the number of CPU VPs, threads 
#                            for performing updates from the secondary.
#                     Valid for HDR, SDS, and RSS.
# FAILOVER_CALLBACK - Specifies the path and program name called when a 
#                     secondary server transitions to a standard or 
#                     primary server. Valid for HDR, SDS, and RSS.
# TEMPTAB_NOLOG     - Controls the default logging mode for temporary
#                     tables that are explicitly created with the 
#                     CREATE TEMP TABLE or SELECT INTO TEMP statements.
#                     Secondary servers must not have logged temporary 
#                     tables. Acceptable values are:
#                     0 Create temporary tables with logging enabled by
#                       default.
#                     1 Create temporary tables without logging.
#                     Required to be set to 1 on HDR, RSS, and SDS 
#                     secondary servers.
# DELAY_APPLY       - Specifies a delay factor for RSS 
#                     secondary nodes.  The format is ###[DHMS] where
#                     D stands for days
#                     H stands for hours
#                     M stands for minutes
#                     S stands for seconds (default)
# STOP_APPLY        - Halts the apply on an RSS node
#                     1 halts the apply
#                     0 resumes the apply (default)
#                     YYYY:MM:DD:hh:mm:ss  - time at which to stop 
# LOG_STAGING_DIR   - Specifies a directory in which to stage log files
###################################################################

DRAUTO                  0
DRINTERVAL              30
DRTIMEOUT               30
HA_ALIAS
DRLOSTFOUND             ${\$self->dbDir()}etc${ps}dr.lostfound
DRIDXAUTO               0
LOG_INDEX_BUILDS
SDS_ENABLE
SDS_TIMEOUT             20
SDS_TEMPDBS
SDS_PAGING
UPDATABLE_SECONDARY     0
FAILOVER_CALLBACK
TEMPTAB_NOLOG           0
DELAY_APPLY             0
STOP_APPLY              0
LOG_STAGING_DIR         

###################################################################
# Logical Recovery Parameters
###################################################################
# ON_RECVRY_THREADS  - The number of logical recovery threads that 
#                      run in parallel during a warm restore.
# OFF_RECVRY_THREADS - The number of logical recovery threads used 
#                      in a cold restore. Also, the number of  
#                      threads used during fast recovery.
###################################################################

ON_RECVRY_THREADS  1
OFF_RECVRY_THREADS 10

###################################################################
# Diagnostic Dump Configuration Parameters
###################################################################
# DUMPDIR      - The location Assertion Failure (AF) diagnostic 
#                files
# DUMPSHMEM    - Controls shared memory dumps. Acceptable values 
#                are:
#                0 Disabled
#                1 Dump all shared memory
#                2 Exclude the buffer pool from the dump
# DUMPGCORE    - Enables (1) or disables (0) whether IDS dumps a 
#                core using gcore
# DUMPCORE     - Enables (1) or disables (0) whether IDS dumps a 
#                core after an AF
# DUMPCNT      - The maximum number of shared memory dumps or 
#                core files for a single session
###################################################################

DUMPDIR ${\$self->dbDir()}tmp
DUMPSHMEM 1
DUMPGCORE 0
DUMPCORE 0
DUMPCNT 1

###################################################################
# Alarm Program Configuration Parameters
###################################################################
# ALARMPROGRAM       - Specifies the alarm program to display event
#                      alarms. To enable automatic logical log backup,
#                      edit alarmprogram.sh and set BACKUPLOGS=Y.
# ALRM_ALL_EVENTS    - Controls whether the alarm program runs for 
#                      every event. Acceptable values are:
#                      0 Logs only noteworthy events 
#                      1 Logs all events
# STORAGE_FULL_ALARM - <time interval in seconds>,<alarm severity>
#                      specifies in what interval:
#                      - a message will be printed to the online.log file
#                      - an alarm will be raised
#                      when
#                      - a dbspace becomes full
#                        (ISAM error -131)
#                      - a partition runs out of pages or extents
#                        (ISAM error -136)
#                      time interval = 0 : OFF
#                      severity = 0 : no alarm, only message
# SYSALARMPROGRAM    - Specifies the system alarm program triggered
#                      when an AF occurs
###################################################################

ALARMPROGRAM ${\$self->dbDir()}etc${ps}alarmprogram.sh

ALRM_ALL_EVENTS 0
STORAGE_FULL_ALARM 600,3
SYSALARMPROGRAM ${\$self->dbDir()}etc${ps}evidence.sh

###################################################################
# RAS Configuration Parameters
###################################################################
# RAS_PLOG_SPEED - Technical Support diagnostic parameter.
#                  Do not change; automatically updated.
# RAS_LLOG_SPEED - Technical Support diagnostic parameter.
#                  Do not change; automatically updated.
###################################################################

RAS_PLOG_SPEED  25000           
RAS_LLOG_SPEED 0

###################################################################
# Character Processing Configuration Parameter
###################################################################
# EILSEQ_COMPAT_MODE - Controls whether when processing characters,  
#               IDS checks if the characters are valid for  
#               the locale and returns error -202 if they are 
#                      not. Acceptable values are:
#                   0 Return an error for characters that are not
#                  valid (Default)
#                    1 Allow characters that are not valid
####################################################################

EILSEQ_COMPAT_MODE  0

###################################################################
# Statistic Configuration Parameters
###################################################################
# QSTATS  - Enables (1) or disables (0) the collection of queue  
#           statistics that can be viewed with onstat -g qst 
# WSTATS  - Enables (1) or disables (0) the collection of wait  
#           statistics that can be viewed with onstat -g wst 
####################################################################

QSTATS 0
WSTATS 0
# Java Configuration Parameters
###################################################################
# VPCLASS jvp  - Configures the Java VP. The format is:
#                VPCLASS jvp,num=<#>[,max=<#>][,aff=<#>][,noage]
# JVPJAVAHOME  - The JRE root directory
# JVPHOME      - The Krakatoa installation directory
# JVPPROPFILE  - The Java VP property file
# JVPLOGFILE   - The Java VP log file
#                This parameter is deprecated and is no longer required
# JDKVERSION   - The version of JDK supported by this server
# JVPJAVALIB   - The location of the JRE libraries, relative
#                to JVPJAVAHOME
# JVPJAVAVM    - The JRE libraries to use for the Java VM
# JVPARGS      - Configures the Java VM. To display JNI calls,
#                use JVPARGS -verbose:jni. Separate options with
#                semicolons.
# JVPCLASSPATH - The Java classpath to use. Use krakatoa_g.jar
#                for debugging. Comment out the JVPCLASSPATH
#                entry you do not want to use.
###################################################################

#VPCLASS        jvp,num=1
JVPJAVAHOME     ${\$self->dbDir()}extend${ps}krakatoa${ps}jre
JVPHOME         ${\$self->dbDir()}extend${ps}krakatoa
JVPPROPFILE     ${\$self->dbDir()}extend${ps}krakatoa${ps}.jvpprops
JVPLOGFILE      ${\$self->dbDir()}jvp.log
#JDKVERSION      1.5
#JVPJAVALIB      ${ps}bin${ps}j9vm
JVPJAVAVM       jvm 
#JVPARGS        -verbose:jni
#JVPCLASSPATH  ${\$self->dbDir()}extend${ps}krakatoa${ps}krakatoa_g.jar:${\$self->dbDir()}extend${ps}krakatoa${ps}jdbc_g.jar
JVPCLASSPATH  ${\$self->dbDir()}extend${ps}krakatoa${ps}krakatoa.jar:${\$self->dbDir()}extend${ps}krakatoa${ps}jdbc.jar


###################################################################
# Buffer pool and LRU Configuration Parameters
###################################################################
# BUFFERPOOL      - Specifies the default values for buffers and LRU 
#                   queues in each buffer pool. Each page size used 
#                   by a dbspace has a buffer pool and needs a
#                   BUFFERPOOL entry. The onconfig.std file contains 
#                   two initial entries: a default entry from which 
#                   to base new page size entries on, and an entry 
#                   for the operating system default page size.                   
#                   When you add a dbspace with a different page size,
#                   IDS adds a BUFFERPOOL entry to the onconfig file 
#                   with values that are the same as the default 
#                   BUFFERPOOL entry, except that the default 
#                   keyword is replaced by size=Nk, where N is the
#                   new page size. With interval checkpoints, these 
#                   values can now be set higher than in previous 
#                   versions of IDS in an OLTP environment.
# AUTO_LRU_TUNING - Enables (1) or disables (0) automatic tuning of
#                   LRU queues. When this parameter is enabled, IDS 
#                   increases the LRU flushing if it cannot find low 
#                   priority buffers for number page faults.
###################################################################

BUFFERPOOL    default,buffers=10000,lrus=8,lru_min_dirty=50.000000,lru_max_dirty=60.500000
BUFFERPOOL    size=2K,buffers=50000,lrus=8,lru_min_dirty=50.000000,lru_max_dirty=60.000000
AUTO_LRU_TUNING 1
END
# onconfig file =========================================================

    open(OUT, ">$self->{'onconfig'}") || die("Could not open file $self->{'onconfig'}!");
    print OUT $ONCONFIG_FILE . "\n";
    close(OUT);
    }
}

#-----------------------------------------------------------------------
# Database->generateUninstallResponseFile()
#-----------------------------------------------------------------------
#
# Private Function 
# Generates uninstall response file for uninstalling server.
#
#-----------------------------------------------------------------------

sub generateUninstallResponseFile
{
    my $self = shift;
    my $INFORMIX_RESPONSE_FILE;

    if (Environment::getEnvironment()->getOSName() eq 'windows') {
$INFORMIX_RESPONSE_FILE=<<END;
[InstallShield Silent]
Version=v7.00
File=Response File
[File Transfer]
OverwrittenReadOnly=NoToAll
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-DlgOrder]
Dlg0={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdWelcomeMaint-0
Count=3
Dlg1={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-IBM Informix Dynamic Server uninstall options-0
Dlg2={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdFinish-0
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdWelcomeMaint-0]
Result=303
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-IBM Informix Dynamic Server uninstall options-0]
Retains all databases, but removes all server binaries=0
Removes server binaries and all databases associated with them=1
Remove User(s)=1
Remove Group(s)=1
Result=1
[Application]
Name=IBM Informix Dynamic Server
Version=11.50
Company=IBM
Lang=0009
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdFinish-0]
Result=1
bOpt1=0
bOpt2=0
[{AC1EC567-96CD-417B-B642-3816113A4313}-DlgOrder]
Count=0
[{DE4A2961-81F6-4807-9F18-D0957EEA9C44}-DlgOrder]
Count=0
[{CE49034E-EC17-4312-B34B-2D4024D7C858}-DlgOrder]
Count=0
END
    }
    else
    {
    }
# End response file =========================================================
    open(OUT, ">$self->{'response_file'}") || die("Could not open file $self->{'response_file'}!");
    print OUT $INFORMIX_RESPONSE_FILE . "\n";
    close(OUT);
}

sub generateInstallResponseFile
{
    my $self = shift;
    my $ps = Environment::getEnvironment()->getPathSeparator();
    my $INFORMIX_RESPONSE_FILE;

# Begin response file =======================================================
    if (Environment::getEnvironment()->getOSName() eq 'windows') {
$INFORMIX_RESPONSE_FILE=<<END;
[InstallShield Silent]
Version=v7.00
File=Response File
[File Transfer]
OverwrittenReadOnly=NoToAll
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-DlgOrder]
Dlg0={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdWelcome-0
Count=10
Dlg1={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-Software License Agreement-0
Dlg2={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SetupType2-0
Dlg3={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdAskDestPath2-0
Dlg4={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdComponentTree-0
Dlg5={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-Informix user setup-0
Dlg6={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-Custom server configuration setup-0
Dlg7={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-Server DBSpace SBSpace Setup-0
Dlg8={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdStartCopy-0
Dlg9={C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdFinish-0
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdWelcome-0]
Result=1
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-Software License Agreement-0]
Accept License Agreement=1
Result=1
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SetupType2-0]
Result=303
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdAskDestPath2-0]
szDir=${\$self->dbDir()}
Result=1
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdComponentTree-0]
szDir=${\$self->dbDir()}
IBM Informix Dynamic Server\\Engine-type=string
IBM Informix Dynamic Server\\Engine-count=4
IBM Informix Dynamic Server\\Engine-0=IBM Informix Dynamic Server\\Engine\\Krakatoa
IBM Informix Dynamic Server\\Engine-1=IBM Informix Dynamic Server\\Engine\\DataBlades
IBM Informix Dynamic Server\\Engine-2=IBM Informix Dynamic Server\\Engine\\Conversion Reversion
IBM Informix Dynamic Server\\Engine-3=IBM Informix Dynamic Server\\Engine\\XML Publishing
IBM Informix Dynamic Server\\GLS-type=string
IBM Informix Dynamic Server\\GLS-count=6
IBM Informix Dynamic Server\\GLS-0=IBM Informix Dynamic Server\\GLS\\WestEurope
IBM Informix Dynamic Server\\GLS-1=IBM Informix Dynamic Server\\GLS\\EastEurope
IBM Informix Dynamic Server\\GLS-2=IBM Informix Dynamic Server\\GLS\\Chinese
IBM Informix Dynamic Server\\GLS-3=IBM Informix Dynamic Server\\GLS\\Japanese
IBM Informix Dynamic Server\\GLS-4=IBM Informix Dynamic Server\\GLS\\Korean
IBM Informix Dynamic Server\\GLS-5=IBM Informix Dynamic Server\\GLS\\Other
IBM Informix Dynamic Server\\Backup Restore-type=string
IBM Informix Dynamic Server\\Backup Restore-count=4
IBM Informix Dynamic Server\\Backup Restore-0=IBM Informix Dynamic Server\\Backup Restore\\Archecker Utility
IBM Informix Dynamic Server\\Backup Restore-1=IBM Informix Dynamic Server\\Backup Restore\\OnBar Utility
IBM Informix Dynamic Server\\Backup Restore-2=IBM Informix Dynamic Server\\Backup Restore\\OnBar with ISM support
IBM Informix Dynamic Server\\Backup Restore-3=IBM Informix Dynamic Server\\Backup Restore\\OnBar with TSM support
IBM Informix Dynamic Server\\Data Load-type=string
IBM Informix Dynamic Server\\Data Load-count=3
IBM Informix Dynamic Server\\Data Load-0=IBM Informix Dynamic Server\\Data Load\\OnLoad Utility
IBM Informix Dynamic Server\\Data Load-1=IBM Informix Dynamic Server\\Data Load\\DBLoad Utility
IBM Informix Dynamic Server\\Data Load-2=IBM Informix Dynamic Server\\Data Load\\High Performance Loader
IBM Informix Dynamic Server\\Utilities-type=string
IBM Informix Dynamic Server\\Utilities-count=3
IBM Informix Dynamic Server\\Utilities-0=IBM Informix Dynamic Server\\Utilities\\Server
IBM Informix Dynamic Server\\Utilities-1=IBM Informix Dynamic Server\\Utilities\\Audit
IBM Informix Dynamic Server\\Utilities-2=IBM Informix Dynamic Server\\Utilities\\DBA Tools
IBM Informix Dynamic Server-type=string
IBM Informix Dynamic Server-count=8
IBM Informix Dynamic Server-0=IBM Informix Dynamic Server\\Core
IBM Informix Dynamic Server-1=IBM Informix Dynamic Server\\Engine
IBM Informix Dynamic Server-2=IBM Informix Dynamic Server\\GLS
IBM Informix Dynamic Server-3=IBM Informix Dynamic Server\\Backup Restore
IBM Informix Dynamic Server-4=IBM Informix Dynamic Server\\Demo
IBM Informix Dynamic Server-5=IBM Informix Dynamic Server\\Data Load
IBM Informix Dynamic Server-6=IBM Informix Dynamic Server\\Enterprise Replication
IBM Informix Dynamic Server-7=IBM Informix Dynamic Server\\Utilities
HIBM Informix Dynamic Server\\HCore\\GSKit_32-type=string
HIBM Informix Dynamic Server\\HCore\\GSKit_32-count=1
HIBM Informix Dynamic Server\\HCore\\GSKit_32-0=HIBM Informix Dynamic Server\\HCore\\GSKit_32\\GSKit 32-Bit
HIBM Informix Dynamic Server\\HCore\\VCRuntime_32-type=string
HIBM Informix Dynamic Server\\HCore\\VCRuntime_32-count=1
HIBM Informix Dynamic Server\\HCore\\VCRuntime_32-0=HIBM Informix Dynamic Server\\HCore\\VCRuntime_32\\VC++32
HIBM Informix Dynamic Server\\HCore\\VCRuntime_64-type=string
HIBM Informix Dynamic Server\\HCore\\VCRuntime_64-count=1
HIBM Informix Dynamic Server\\HCore\\VCRuntime_64-0=HIBM Informix Dynamic Server\\HCore\\VCRuntime_64\\VC++64
HIBM Informix Dynamic Server\\HCore-type=string
HIBM Informix Dynamic Server\\HCore-count=3
HIBM Informix Dynamic Server\\HCore-0=HIBM Informix Dynamic Server\\HCore\\GSKit_32
HIBM Informix Dynamic Server\\HCore-1=HIBM Informix Dynamic Server\\HCore\\VCRuntime_32
HIBM Informix Dynamic Server\\HCore-2=HIBM Informix Dynamic Server\\HCore\\VCRuntime_64
HIBM Informix Dynamic Server-type=string
HIBM Informix Dynamic Server-count=1
HIBM Informix Dynamic Server-0=HIBM Informix Dynamic Server\\HCore
Component-type=string
Component-count=2
Component-0=IBM Informix Dynamic Server
Component-1=HIBM Informix Dynamic Server
Result=1
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-Informix user setup-0]
User=${\$self->dbHost()}${ps}${\$self->dbUser()}
Install in Domain=0
Start database server as Local System User=0
Do not create user informix account=0
Password=${\$self->dbPass()}
Confirm Password=${\$self->dbPass()}
Enable Role Separation=0
Result=1
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-Custom server configuration setup-0]
Server Name=${\$self->instanceName()}
Service Name=svc_custom_1
Port=${\$self->dbPort()}
Server number=0
Create Server=1
Initialize Server=1
Enable DRDA Support=1
Server Alias=svc_drda_2
DRDA Port=9093
Result=1
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-Server DBSpace SBSpace Setup-0]
DBSpace Name=${\$self->instanceName()}
Primary Data Location=C:
Mirror Data Location (optional)=' '
Size (MB)=200
SBSpace Name=sbspace
SBSpace Primary Data Location=C:
SBSpae Mirror Data Location (optional)=' '
SBSpace Size (MB)=200
Page Size (in pages)=1
Result=1
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdStartCopy-0]
Result=1
[Application]
Name=IBM Informix Dynamic Server
Version=11.50
Company=IBM
Lang=0009
[{C07D62E2-B2E7-4DAE-B3C9-34A2D3EE30B8}-SdFinish-0]
Result=1
bOpt1=0
bOpt2=0
[{AC1EC567-96CD-417B-B642-3816113A4313}-DlgOrder]
Count=0
[{DE4A2961-81F6-4807-9F18-D0957EEA9C44}-DlgOrder]
Count=0
[{CE49034E-EC17-4312-B34B-2D4024D7C858}-DlgOrder]
Count=0
END
}
else
{
$INFORMIX_RESPONSE_FILE=<<END;
################################################################################
#
# InstallShield Options File
#
# Wizard name: Install
# Wizard source: IIF.jar
# Created on: Mon Dec 07 10:31:30 GMT 2009
# Created by: InstallShield Options File Generator
#
# This file contains values that were specified during a recent execution of
# Install. It can be used to configure Install with the options specified below
# when the wizard is run with the "-options" command line option. Read each
# setting's documentation for information on how to change its value.
# 
# A common use of an options file is to run the wizard in silent mode. This lets
# the options file author specify wizard settings without having to run the
# wizard in graphical or console mode. To use this options file for silent mode
# execution, use the following command line arguments when running the wizard:
# 
#    -options "isilent.ini" -silent
#
################################################################################


################################################################################
#
# Has the license been accepted
#
# The license must be accepted before installation so this value must be true
# for the install to be successful. Example: -G licenseAccepted=true
#


-G licenseAccepted=true


################################################################################
#
# IBM Informix Dynamic Server Version 11.50 Install Location
#
# The install location of the product. Specify a valid directory into which the
# product should be installed. If the directory contains spaces, enclose it in
# double-quotes. For example, to install the product to C:\\Program Files\\My
# Product, use
# 
#    -P installLocation="C:\\Program Files\\My Product"
#


-P installLocation=${\$self->dbDir()}

################################################################################
#
# User Input Field - securedirectoryaction
#
# (Description for this to be filled in later) Possible values are auto - Let
# the installation program automatically secure the path (recommended). generate
# - Continue installation with automatic generation of the scripts to secure the
# path, and manually run the scripts later custom - View other security-related
# options
#


-W informixdirNonsecure.securedirectoryaction="custom"


################################################################################
#
# User Input Field - securedirectoryowneraction
#
# (Description for this to be filled in later) Possible values are changeowner -
# Change the owner trustowner - Add an owner to list of trusted owners
# ignoreowner - Ignore the owner problem
#


-W informixdirsecureoption.securedirectoryowneraction="trustowner"


################################################################################
#
# User Input Field - securedirectorygroupaction
#
# # (Description for this to be filled in later) Possible values are changegroup
# - Change the group removegroupwrite - Remove group write permission trustgroup
# - Add a group to list of trusted groups ignoregroup - Ignore the group
# permissions problem
#


-W informixdirsecureoption.securedirectorygroupaction="trustgroup"


################################################################################
#
# User Input Field - securedirectorypermissionsaction
#
# # (Description for this to be filled in later) Possible values are
# removepublicwrite - Remove public write permissions trustdirectory - Add a
# directory to list of untrustworthy but trusted directories ignoredirectory -
# Ignore the public permissions problem
#


-W informixdirsecureoption.securedirectorypermissionsaction="trustdirectory"


################################################################################
#
# Setup Type
#
# The setup type to be used when installing the product. Legal values are:
# 
#    typical - Typical: The program will be installed with the suggested
#              configuration. Recommended for most users.
#    custom  - Custom: The program will be installed with the features you
#              choose. Recommended for advanced users.
# 
# For example, to specify that the "Typical" setup type is selected, use
# 
#    -W setupTypes.selectedSetupTypeId=typical
# 
# You may also set the setup type to nothing by using
# 
#    -W setupTypes.selectedSetypTypeId=
# 
# This clears the current setup type and prevents any changes to the set of
# selected features. Use this option whenever you set feature active states in
# this options file. If you do not clear the selected setup type, the setup type
# panel will override any changes you make to feature active states using this
# file.
#


-W setupTypes.selectedSetupTypeId=typical


################################################################################
#
# Base Server
#
# Specifies whether to install Base Server
#


-P IDS-CORE.active="true"


################################################################################
#
# Database Server Extensions
#
# Specifies whether to install Database Server Extensions
#


-P serverfeature.active="true"


################################################################################
#
# J/Foundation
#
# Specifies whether to install J/Foundation
#


-P IDS-KRAKATOA.active="true"


################################################################################
#
# Built-in DataBlade Modules
#
# Specifies whether to install Built-in DataBlade Modules
#


-P IDS-BLADE.active="true"


################################################################################
#
# Conversion and Reversion Support
#
# Specifies whether to install Conversion and Reversion Support
#


-P IDS-CONVREV.active="true"


################################################################################
#
# XML Publishing
#
# Specifies whether to install XML Publishing
#


-P IDS-XMLPUB.active="true"


################################################################################
#
# Global Language Support (GLS)
#
# Specifies whether to install Global Language Support (GLS)
#


-P IDS-GLS.active="true"


################################################################################
#
# West European and Americas
#
# Specifies whether to install West European and Americas
#


-P IDS-WESTEURO.active="true"


################################################################################
#
# East European and Cyrillic
#
# Specifies whether to install East European and Cyrillic
#


-P IDS-EASTEURO.active="true"


################################################################################
#
# Chinese
#
# Specifies whether to install Chinese
#


-P IDS-CHINESE.active="true"


################################################################################
#
# Japanese
#
# Specifies whether to install Japanese
#


-P IDS-JAPANESE.active="true"


################################################################################
#
# Korean
#
# Specifies whether to install Korean
#


-P IDS-KOREAN.active="true"


################################################################################
#
# Other
#
# Specifies whether to install Other
#


-P IDS-PACIFIC.active="true"


################################################################################
#
# Backup and Restore
#
# Specifies whether to install Backup and Restore
#


-P backuprestorefeature.active="true"


################################################################################
#
# ON-Bar Utilities
#
# Specifies whether to install ON-Bar Utilities
#


-P IDS-ONBAR.active="true"


################################################################################
#
# Informix Interface for Tivoli Storage Manager
#
# Specifies whether to install Informix Interface for Tivoli Storage Manager
#


-P IDS-TSM.active="true"


################################################################################
#
# Informix Storage Manager
#
# Specifies whether to install Informix Storage Manager
#


-P IDS-ISM.active="true"


################################################################################
#
# archecker Utility
#
# Specifies whether to install archecker Utility
#


-P IDS-ARCHECKER.active="true"


################################################################################
#
# Demos
#
# Specifies whether to install Demos
#


-P IDS-DEMO.active="true"


################################################################################
#
# Data-Loading Utilities
#
# Specifies whether to install Data-Loading Utilities
#


-P dataloadutilitiesfeature.active="true"


################################################################################
#
# onunload and onload Utilities
#
# Specifies whether to install onunload and onload Utilities
#


-P IDS-ONUNLOAD-ONLOAD.active="true"


################################################################################
#
# dbload Utility
#
# Specifies whether to install dbload Utility
#


-P IDS-DBLOAD.active="true"


################################################################################
#
# High-Performance Loader(HPL)
#
# Specifies whether to install High-Performance Loader(HPL)
#


-P IDS-HPL.active="true"


################################################################################
#
# Enterprise Replication
#
# Specifies whether to install Enterprise Replication
#


-P IDS-ER.active="true"


################################################################################
#
# Administrative Utilities
#
# Specifies whether to install Administrative Utilities
#


-P adminutilitiesfeature.active="true"


################################################################################
#
# Performance Monitoring Utilities
#
# Specifies whether to install Performance Monitoring Utilities
#


-P IDS-PERF.active="true"


################################################################################
#
# Miscellaneous Monitoring Utilities
#
# Specifies whether to install Miscellaneous Monitoring Utilities
#


-P IDS-MONITOR.active="true"


################################################################################
#
# Auditing Utilities
#
# Specifies whether to install Auditing Utilities
#


-P IDS-AUDIT.active="true"


################################################################################
#
# Database Import and Export Utilities
#
# Specifies whether to install Database Import and Export Utilities
#


-P IDS-DBATOOLS.active="true"


################################################################################
#
# User Input Field - roleSep
#
#


-W rolesepenable.roleSep="off"


################################################################################
#
# User Input Field - dbsso_g
#
#


-W rolesep.dbsso_g="informix"


################################################################################
#
# User Input Field - aao_g
#
#


-W rolesep.aao_g="informix"


################################################################################
#
# User Input Field - user_g
#
#


-W rolesep.user_g=""


################################################################################
#
# User Input Field - CreateDemo
#
#


-W demoinput.CreateDemo="nocreate"


################################################################################
#
# User Input Field - preonconfig
#
#


-W demoinput2.preonconfig="no"


################################################################################
#
# User Input Field - preonconfig
#
#


-W demoinput2a.preonconfig="no"


################################################################################
#
# User Input Field - onconfig
#
#


-W demoinput3.onconfig=""


################################################################################
#
# User Input Field - ServerName
#
#


-W demoinput4.ServerName="demo_on"


################################################################################
#
# User Input Field - ServerNumber
#
#


-W demoinput4.ServerNumber="0"


################################################################################
#
# User Input Field - rootpath
#
#


-W demoinput4.rootpath="$ENV{PATH}($ENV{P}(absoluteInstallLocation))${ps}demo${ps}server${ps}online_root"


################################################################################
#
# User Input Field - rootsize
#
#


-W demoinput4.rootsize="200000"


################################################################################
#
# User Input Field - bufferpool
#
#


-W demoinput4.bufferpool="size=default,buffers=10000,lrus=8,lru_min_dirty=50,lru_max_dirty=60"


################################################################################
#
# User Input Field - numcpuvps
#
#


-W demoinput4.numcpuvps="1"


################################################################################
#
# User Input Field - ServerAlias
#
#


-W demoinput4.ServerAlias=""


################################################################################
#
# User Input Field - cpus
#
#


-W demoinput6.cpus="1"


################################################################################
#
# User Input Field - memory
#
#


-W demoinput6.memory="512"


################################################################################
#
# User Input Field - appclients
#
#


-W demoinput6.appclients="1"


################################################################################
#
# User Input Field - queryclients
#
#


-W demoinput6.queryclients="1"


################################################################################
#
# User Input Field - servername
#
#


-W demoinput5.servername="demo_on"


################################################################################
#
# User Input Field - servernumber
#
#


-W demoinput5.servernumber="0"


################################################################################
#
# User Input Field - rootpath
#
#


-W demoinput5.rootpath="$ENV{PATH}($ENV{P}(absoluteInstallLocation))/demo/server/online_root"


################################################################################
#
# User Input Field - rootsize
#
#


-W demoinput5.rootsize="760"


################################################################################
#
# User Input Field - ServerAlias
#
#


-W demoinput5.ServerAlias=""


################################################################################
#
# User Input Field - configure
#
#


-W kernelsystemparameters.configure="yes"


################################################################################
#
# User Input Field - TermSelection
#
#


-W TermSel.TermSelection="skip"


################################################################################
#
# User Input Field - otherTermInput
#
#


-W ManualSel.otherTermInput=""
END
}
# End response file =========================================================

    open(OUT, ">$self->{'response_file'}") || die("Could not open file $self->{'response_file'}!");
    print OUT $INFORMIX_RESPONSE_FILE . "\n";
    close(OUT);
}
#-----------------------------------------------------------------------
# Database->createScript($scriptName)
#-----------------------------------------------------------------------
#
# Private Function 
# Creates a script according to platform been run on.
#
#-----------------------------------------------------------------------
my $g_path = 0;
sub createScript
{
    my $self = shift;
    my $nameOfScript = shift;
	my $es = $self->getEnv()->getEnvSeparator();
	my $ps = $self->getEnv()->getPathSeparator();
	my $cmd='';
	
	if ($g_path == 0) {
        $ENV{'INFORMIXDIR'} = $self->dbDir();
	    $ENV{'INFORMIXSERVER'} = $self->instanceName();
        $ENV{'PATH'} = $self->dbDir() . 'bin' . $es . $ENV{'PATH'};
		$ENV{'ONCONFIG'} = "onconfig";
		$ENV{'CLASSPATH'} = $ENV{'INFORMIXDIR'} . $es . $ENV{'CLASSPATH'};
		$ENV{'CLASSPATH'} = $ps . "extend" .$ps . "krakatoa" . $ps ."krakatoa.jar" . $ENV{'CLASSPATH'};
		$ENV{'CLASSPATH'} = $ps . "extend" .$ps . "krakatoa" . $ps ."jdbc.jar" . $ENV{'CLASSPATH'};
        $ENV{'DBTEMP'} = $self->dbDir() . "infxtmp" . $ps;
		$ENV{'CLIENT_LOCALE'} = "EN_US.CP1252";
		$ENV{'DB_LOCALE'} = "EN_US.8859-1";
        $g_path = 1;
    }
    
	if (Environment::getEnvironment()->getOSName() eq 'windows') {

	} else {
	    $cmd = "#!$ENV{SHELL}\n";   
	}
	
    open(OUT, ">$nameOfScript") || die("Could not open file $nameOfScript'}!");
    print OUT "$cmd";
    close OUT;

    if (Environment::getEnvironment()->getOSName() ne 'windows') {
        system("chmod +x $nameOfScript");
    }
}

#-----------------------------------------------------------------------
# Database->perform()
#-----------------------------------------------------------------------
#
# private function which performs requested SQL 
#
#-----------------------------------------------------------------------

sub perform()
{
    my $cmd;
    my $self = shift;
    my $cmdFile = "$self->{'workFile'}";

    $self->createScript($cmdFile);

    # append the following
    $cmd = "dbaccess - " . $self->dbName() . ".sql\n";
 
    open(OUT, ">>$cmdFile") || die("Could not open file $cmdFile!");
    print OUT "$cmd";
    close OUT;

    if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $cmd = "$self->{'cmd'}${cmdFile}>" . $self->dbSqlOutputFile();
    }
    else {
        system("chmod +x $cmdFile\n");
        $cmd = "$self->{'cmd'}${cmdFile}>" . $self->dbSqlOutputFile();
    }

    # remove files just used
    system("$cmd");
    unlink("$cmdFile");
    unlink("${\$self->dbName()}.sql");
}

sub start
{
	my $self = shift;
	my $instCmd;

    $self->createScript($self->{'workFile'});
    open(OUT, ">>$self->{'workFile'}") || die("Could not open file $self->{'workFile'}!");
	Environment::logf(">> Initialising server \"${\$self->instanceName()}\"\n");  
    
	if (Environment::getEnvironment()->getOSName() eq 'windows') {
        $instCmd = "$self->{'cmd'}$self->{'workFile'}>nul 2>&1"; # initialise database server
    }
    else {
        print OUT "oninit\n";
        close OUT;       
        system("chmod +x $self->{'workFile'}>&/tmp/out 2>&1");
        $instCmd = "$self->{'cmd'}$self->{'workFile'}>/dev/null 2>&1"; # initialise database server
  
    }
    system("$instCmd");
    unlink("$self->{'workFile'}");
}

sub stop
{
	my $self = shift;
	my $instCmd;
	
    $self->createScript($self->{'workFile'});
    open(OUT, ">>$self->{'workFile'}") || die("Could not open file $self->{'workFile'}!");
	Environment::logf(">> Stopping server \"${\$self->instanceName()}\"\n");   
    
	if (Environment::getEnvironment()->getOSName() eq 'windows') {
       $instCmd = "$self->{'cmd'}$self->{'workFile'}>nul 2>&1"; # initialise database server
    }
    else { 	 
 	    print OUT "onmode -ky\n";
        close OUT;         
        system("chmod +x $self->{'workFile'}>&/tmp/out 2>&1");
        $instCmd = "$self->{'cmd'}$self->{'workFile'}>/dev/null 2>&1"; # initialise database server
    }

    system("$instCmd");
    unlink("$self->{'workFile'}");
}

#-----------------------------------------------------------------------
# $port = $ob->dbPort()
# $ob->dbPort($port)
#-----------------------------------------------------------------------
#
# Get/set database communication port
#
#-----------------------------------------------------------------------
sub dbPort
{
    my ($self,$name) = @_;
 
	$self->getConfigParams()->{'db_port'} = $name if defined($name);

    return $self->getConfigParams()->{'db_port'};
}

#-----------------------------------------------------------------------
# $name = $ob->dbSchema()
# $ob->dbSchema($name)
#-----------------------------------------------------------------------
#
# Get/set database schema name
#
#-----------------------------------------------------------------------
sub dbSchema
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_schema'} = $name if defined($name);
	return $self->getConfigParams()->{'db_schema'};
}

#-----------------------------------------------------------------------
# $name = $ob->dbTableName()
# $ob->dbTableName($name)
#-----------------------------------------------------------------------
#
# Get/set database table name
# Useful if you use placeholder %TABLE% in an sql batch file to represent
# a table name, rather than explicitly specifying the table name, e.g.:
# $source->dbTableName('src')
# $source->execSql('create_table.sql')
# (%TABLE% in 'create_table.sql' replaced with 'src')
#
#-----------------------------------------------------------------------
sub dbTableName
{
	my ($self,$name) = @_;
	$self->getConfigParams()->{'db_tbl_name'} = $name if defined($name);
	return $self->getConfigParams()->{'db_tbl_name'};
}

#-----------------------------------------------------------------------
# private
#-----------------------------------------------------------------------
# defines informix service to unix, i.e. adds an entry to /etc/services if required)
#-----------------------------------------------------------------------
sub addInformixUnixService() {
	my $self = shift;
	my $service = shift;
	my $port = shift;
	my $comment = shift;
	if ($self->existsUnixService($service) eq 0) {
		$self->addUnixService($service, $port, "IBM Informix service")
	}
}

#-----------------------------------------------------------------------
# private
#-----------------------------------------------------------------------
# checks if a unix service exists
#-----------------------------------------------------------------------
sub existsUnixService() {
	my $self = shift;
	my $service = shift;
	my @result = $self->getUnixServices("^$service\\s");
	if ($#result > 0) {
		return 1;
	}
	return 0;
}

#-----------------------------------------------------------------------
# private
#-----------------------------------------------------------------------
# returns all unix services matching a given regular expression, each line includes name, port, comment (if available)
#-----------------------------------------------------------------------
sub getUnixServices() {
	my $self = shift;
	my $service = shift;

	open (SERVICES, "/etc/services") || die("Cannot open services file");
    my @result = {};
    my $line = "";
	while ($line = <SERVICES>) {
   		if ($line =~ m/$service/) {
   			push(@result, $line);
   		}
	}
	close(SERVICES);
	return @result;
}

#-----------------------------------------------------------------------
# private
#-----------------------------------------------------------------------
# adds an entry to /etc/services
#-----------------------------------------------------------------------
sub addUnixService() {
	my $self = shift;
	my $service = shift;
	my $port = shift;
	my $comment = shift;
	
    open(SERVICES,">>/etc/services")  || die("Cannot open services file");
    print SERVICES "$service        $port       # $comment\n";
    close(SERVICES); 
}

1;

