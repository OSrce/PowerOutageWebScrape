#!/usr/bin/perl
use DBI;

use Time::HiRes qw(usleep nanosleep);


while(1) {
	print "test\n";
  usleep(200000);

}


my $dbh;
$dbh = DBI->connect("DBI:Pg:dbname=sitrep;host=localhost", "sitrepadmin", "", {'RaiseError' => 1});

my $group_id = 2013;
my $currentDataTimeDB = '2013-03-11 10:10:10';

my $updateStr = "UPDATE event SET data_end='$currentDataTimeDB' WHERE group_id=$group_id AND has_end=false";
#print "TEST=$updateStr\n";
my $rows = $dbh->do($updateStr);

my @testArr = ( '10', 'NONE', 'No idea',  '-73.9821049915525', '40.7771316116684' ,'someurl');
my $matchArr = \@testArr;

	#INSERT EACH ROW INTO location
	my $insertStr = "INSERT INTO location (source, geometry) VALUES ( 7,  ST_SetSRID(ST_MakePoint(".${$matchArr}[4].",".${$matchArr}[3].",0),4326) ) RETURNING id";
#	my $rows = $dbh->do($insertStr);
	my $insert_handle = $dbh->prepare($insertStr);
	$insert_handle->execute();
	my $locid = $insert_handle->fetch()->[0];

#	$insert_handle->dump_results();
	$insert_handle->finish();

	#INSERT EACH ROW INTO event
	my $insertStr = "INSERT INTO event (group_id, data, data_begin, location) VALUES ( $group_id, '\"CustomersAffected\"=>".${$matchArr}[0].", \"EstTimeOfRest\"=>\"".${$matchArr}[1]."\", \"CauseOfOutage\" =>\"".${$matchArr}[2]."\"'::hstore, '$currentDataTimeDB', $locid )";
	#print LOGFILE "INSERT_STMT=$insertStr\n";
	my $rows = $dbh->do($insertStr);
	


$dbh->disconnect();
