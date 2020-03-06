#!/usr/bin/perl
use strict 'vars';
use warnings;
use DBI;
use Data::Dumper;
my $debug = shift;
my $myConnection = DBI->connect("DBI:Pg:dbname=testdb;host=localhost", "testuser", "testpassword");
my $query = $myConnection->prepare("SELECT id,name,pass,lastlogin FROM testusers WHERE lastlogin <= CURRENT_DATE - INTERVAL '3 months'");
my $result = $query->execute();
warn Dumper $result;
if ($result) {
	while (my $item = $query->fetchrow_hashref) {		
		print "The following entry: \n";
		print qq|$item->{id} : $item->{name} : $item->{pass} : $item->{lastlogin} \n|;
		if ($debug) {
			print "Will not be deleted, because debug mode is set\n";
		} else { 
			print "Will be deleted, because user not logged in for several months\n";
			my $query = $myConnection->prepare("DELETE FROM testusers WHERE id=?");
			my $result = $query->execute($item->{id});
		}
	}
}
$myConnection->disconnect;

