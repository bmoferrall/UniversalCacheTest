#!/bin/sh

pod2html --infile Database.pm --outfile Database.htm
pod2html --infile CDC.pm --outfile CDC.htm
pod2html --infile Environment.pm --outfile Environment.htm
pod2html --infile TestBed.pm --outfile TestBed.htm
pod2html --infile UCConfig.pm --outfile UCConfig.htm
pod2html --infile Install.pm --outfile Install.htm
rm *.tmp
mv *.htm html

cd AccessServer
pod2html --infile AccessServer.pm --outfile AccessServer.htm
pod2html --infile Datastore.pm --outfile Datastore.htm
rm *.tmp
mv *.htm ../html

cd ..
cd Database
pod2html --infile SolidDB.pm --outfile SolidDB.htm
pod2html --infile Db2DB.pm --outfile Db2DB.htm
pod2html --infile RemoteDB.pm --outfile RemoteDB.htm
pod2html --infile InformixDB.pm --outfile InformixDB.htm
rm *.tmp
mv *.htm ../html

cd ..
cd CDC
pod2html --infile CDCSolid.pm --outfile CDCSolid.htm
pod2html --infile CDCDb2.pm --outfile CDCDb2.htm
pod2html --infile CDCRemote.pm --outfile CDCRemote.htm
pod2html --infile CDCInformix.pm --outfile CDCInformix.htm
rm *.tmp
mv *.htm ../html

cd ..
cd Repository
pod2html --infile CVS.pm --outfile CVS.htm
pod2html --infile CDCSolidRepository.pm --outfile CDCSolidRepository.htm
rm *.tmp
mv *.htm ../html

cd ..
cd UCConfig
pod2html --infile ConfigParser.pm --outfile ConfigParser.htm
pod2html --infile DatabaseConfig.pm --outfile DatabaseConfig.htm
pod2html --infile DatastoreConfig.pm --outfile DatastoreConfig.htm
pod2html --infile TestBedConfig.pm --outfile TestBedConfig.htm
pod2html --infile CDCConfig.pm --outfile CDCConfig.htm
pod2html --infile EnvironmentConfig.pm --outfile EnvironmentConfig.htm
pod2html --infile AccessServerConfig.pm --outfile AccessServerConfig.htm
pod2html --infile InstallConfig.pm --outfile InstallConfig.htm
rm *.tmp
mv *.htm ../html
