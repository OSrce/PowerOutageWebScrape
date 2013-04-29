#!/usr/bin/perl

use strict;
use warnings;
use WWW::Curl::Easy;
use DBI;
use POSIX qw/strftime/;
use Time::HiRes qw(usleep nanosleep);


my $logFile = "/var/log/srd/scrapeConEd.log";
open LOGFILE, ">>", $logFile or die "Couldnt Open LogFile!\n".$!;

my $configfile = "scrapeConEd.config";
open CONFIGFILE, "+<", $configfile or die "NEED TO CONFIGURE scrapeConEd.config!\n".$!;
my $dbh;
my $group_id;
my @conedArr;
my $last_data_timestamp;
my $current_data_timestamp;

print LOGFILE "Starting scrapeConEd @ ".localtime."\n";

while( my $line = <CONFIGFILE> ) {
	if( $line =~ /GROUP_ID=(\d+)/ ) {
		$group_id = $1;
	} elsif( $line =~ /LAST_DATA_TIMESTAMP=(\w+)/ ) {
		$last_data_timestamp = $1;
	}
}
if( ! defined($group_id) ) {
	print LOGFILE "NEED TO SET : GROUP_ID=#### IN CONFIG FILE!\n";
	exit(-1);
} else {
	print LOGFILE "GROUP_ID = $group_id \n";
}
if( ! defined($last_data_timestamp) ) {
	print LOGFILE "NO EXISTING LAST_DATA_TIMESTAMP FOUND!\n";
} else {
	print LOGFILE "LAST_DATA_TIMESTAMP = $last_data_timestamp \n";
}

#my $curlResults = `curl -f http://apps.coned.com/stormcenter_external/stormcenter_externaldata/data/interval_generation_data/metadata.xml?timestamp=00000001 `
#print  "TEST=".$curlResults."=TEST\n";

my $curl = WWW::Curl::Easy->new;
$curl->setopt(CURLOPT_HEADER,1);
$curl->setopt(CURLOPT_URL, 'http://apps.coned.com/stormcenter_external/stormcenter_externaldata/data/interval_generation_data/metadata.xml?timestamp=00000001');


# A filehandle, reference to a scalar or reference to a typeglob can be used here.
my $response_body;
$curl->setopt(CURLOPT_WRITEDATA,\$response_body);

# Starts the actual request
my $retcode = $curl->perform;

# Looking at the results...
if ($retcode == 0) {
	print LOGFILE "Transfer went ok\n";
	if( $response_body =~ /<directory>(\w+)<\/directory>/ ) {
		$current_data_timestamp = $1;

		seek(CONFIGFILE, 0, 0)               or die "can't seek to start of $configfile: $!";
		print CONFIGFILE "#scrapeConEd CONFIG FILE\n"                or die "can't print to $configfile: $!";
		print CONFIGFILE "GROUP_ID=$group_id\n"                or die "can't print to $configfile: $!";
		print CONFIGFILE "LAST_DATA_TIMESTAMP=$current_data_timestamp\n"                or die "can't print to $configfile: $!";
		truncate(CONFIGFILE, tell(CONFIGFILE))        or die "can't truncate $configfile: $!";

		print LOGFILE "CURRENT_DATA_TIMESTAMP = $current_data_timestamp\n";
	}
}
close(CONFIGFILE);
if( !defined($current_data_timestamp) ) {
	print LOGFILE "ERROR: COULD NOT FIND CURRENT_DATA_TIMESTAMP!\n";
	exit(-2);
}

if( defined($last_data_timestamp) && $current_data_timestamp eq $last_data_timestamp ) {
	print LOGFILE "TIMESTAMP HAS NOT CHANGED SINCE LAST RUN! TIMESTAMP=$last_data_timestamp\n";
	exit(-3);
}

my $currentDataTimeDB;
if( $current_data_timestamp =~ /(\d\d\d\d)_(\d\d)_(\d\d)_(\d\d)_(\d\d)_(\d\d)/ ) {
	$currentDataTimeDB = "$1-$2-$3 $4:$5:$6";
} else {
	print LOGFILE "ERROR: COULD NOT FORMAT TIMESTAMP STRING:  $current_data_timestamp\n";
	exit(-4);
}

### WE'VE GOT NEW DATA, CLOSE THE EVENTS THAT ARE ALREADY IN THE DB AND THEN GET AND LOAD
### THE NEW DATA.

# connect to database
$dbh = DBI->connect("DBI:Pg:dbname=sitrep;host=localhost", "sitrepadmin", "", {'RaiseError' => 1});


####### NOW PROCESS EACH URL from coned_url_list with current_data_timestamp ###

my @urls;
my $urlfile = "coned_url_list.txt";
open URLFILE, "<", $urlfile or die "NEED TO SUPPLY URL FILE: $urlfile!\n".$!;
while( my $line = <URLFILE> ) {
	$line =~ s/REPLACE_STR_HERE/$current_data_timestamp/g;
	chomp $line;
	push (@urls, $line);	
}

#my @urls = <coned_url_list.txt>;
my $lineCount = 0;
foreach my $url (@urls) {
	$lineCount++;
	if($lineCount % 100 == 0) {
		print LOGFILE "PROGRESS AT:".localtime." RETRIEVING URL # $lineCount of ".scalar (@urls)."\n";
		print LOGFILE "URL:".$url."\n";
	}
	$curl->setopt(CURLOPT_URL, $url);
	$curl->setopt(CURLOPT_FAILONERROR,1);
	my $response_body = "";
	$curl->setopt(CURLOPT_WRITEDATA,\$response_body);
	my $retcode = $curl->perform;

#		print LOGFILE "RETCODE====$retcode\n";
#		print LOGFILE "TEST=$response_body";
	# Looking at the results...
	if ($retcode == 0) {
		print LOGFILE "Transfer of url went ok! URL= $url\n";
#		print LOGFILE "TEST=$response_body";
#		push @conedArr, [$1, $2, $3, $4, $5] while $response_body =~ /"cust_a":"(\d+)","etr":"([^"]+)","cause":"([^"]+)"\}\],"geom":\[\{"p":\[([^,]+),([^\]]+)\]/g;
		push @conedArr, [$1, $2, $3, $4, $5, $url] while $response_body =~ /"cust_a":"(\d+)","etr":"([^"]+)","cause":"([^"]+)"\}\],"geom":\[\{"p":\[([^,]+),([^\]]+)\]/g;
	}

#	while( my $line = <INFILE>) {
##		push @conedArr, [$1, $2, $3, $4, $5] while $line =~ /"cust_a":"(\d+)","etr":"([^"]+)","cause":"([^"]+)"\}\],"geom":\[\{"p":\[(\d+),(\d+)\]/g;
#		push @conedArr, [$1, $2, $3, $4, $5] while $line =~ /"cust_a":"(\d+)","etr":"([^"]+)","cause":"([^"]+)"\}\],"geom":\[\{"p":\[([^,]+),([^\]]+)\]/g;
#	}
#	close INFILE;

	usleep(200000);	
}



#UPDATE ALL ROWS FOR GROUP_ID THAT feature_end=NULL
#my $updateStr = "UPDATE event SET data_end='$currentDataTimeDB' WHERE group_id=$group_id AND has_end=false";
my $updateStr = "UPDATE event SET data_end='$currentDataTimeDB' WHERE group_id=$group_id AND has_end=false";
#print "TEST=$updateStr\n";
my $rows = $dbh->do($updateStr);


print LOGFILE "Customers Affected\tEstimated Time of Restoration\tCause of Outage\tLat\tLon\n";
foreach my $matchArr (@conedArr) {
	print LOGFILE ${$matchArr}[0]."\t".${$matchArr}[1]."\t".${$matchArr}[2] ."\t".${$matchArr}[3] ."\t".${$matchArr}[4]." URL=".${$matchArr}[5]."\n";


	#INSERT EACH ROW INTO location
	my $insertStr = "INSERT INTO location (source, geometry) VALUES ( 7,  ST_SetSRID(ST_MakePoint(".${$matchArr}[4].",".${$matchArr}[3].",0),4326) ) RETURNING id";
#	my $rows = $dbh->do($insertStr);
	my $insert_handle = $dbh->prepare($insertStr);
	$insert_handle->execute();
	my $locid = $insert_handle->fetch()->[0];
	$insert_handle->finish();

	#INSERT EACH ROW INTO event
	$insertStr = "INSERT INTO event (group_id, data, data_begin, location) VALUES ( $group_id, '\"CustomersAffected\"=>".${$matchArr}[0].", \"EstTimeOfRest\"=>\"".${$matchArr}[1]."\", \"CauseOfOutage\" =>\"".${$matchArr}[2]."\"'::hstore, '$currentDataTimeDB', $locid )";
	#print LOGFILE "INSERT_STMT=$insertStr\n";
	my $rows = $dbh->do($insertStr);




}

close(LOGFILE);

# Clean up
$dbh->disconnect();
exit(0);





