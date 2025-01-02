connect to %DB%;
create table %SCHEMA%.%TABLE% (id integer, fname char(50), sname char(50), address char(75), country char(25));
connect reset;
