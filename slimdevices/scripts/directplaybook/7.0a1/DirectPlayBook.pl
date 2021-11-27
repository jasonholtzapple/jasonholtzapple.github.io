#!/usr/bin/perl

# DirectPlayBook.pl by Jason Holtzapple (jasonholtzapple@yahoo.com)
#
# To use, modify the $sc_home variable to point to your SqueezeCenter
# directory. Run the script with the same perl distribution that you
# use to run SqueezeCenter. You may need to modify the first line of
# the script for this.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
#
#-> Changelog
#
# 7.0a1 - 26/11/2007
#    RFE: SqueezeCenter 7.0 ready

use strict;
use Config;
use File::Spec::Functions qw(:ALL);

use FindBin qw($Bin);

BEGIN {
	# modify $sc_home to point to your slimserver directory
	our $sc_home = '/export/home/slim/slimserver';

	my $arch = $Config::Config{'archname'};
	$arch =~ s/^i[3456]86-/i386-/;
        $arch =~ s/gnu-//;

        my @SlimINC = (
                catdir($sc_home,'CPAN','arch',(join ".", map {ord} (split //, $^V)[0,1]), $arch),
                catdir($sc_home,'CPAN','arch',(join ".", map {ord} (split //, $^V)[0,1]), $arch, 'auto'),
                catdir($sc_home,'CPAN','arch',(join ".", map {ord} split //, $^V), $Config::Config{'archname'}),
                catdir($sc_home,'CPAN','arch',(join ".", map {ord} split //, $^V), $Config::Config{'archname'}, 'auto'),
                catdir($sc_home,'CPAN','arch',(join ".", map {ord} (split //, $^V)[0,1]), $Config::Config{'archname'}),
                catdir($sc_home,'CPAN','arch',(join ".", map {ord} (split //, $^V)[0,1]), $Config::Config{'archname'}, 'auto'),
                catdir($sc_home,'CPAN','arch',$Config::Config{'archname'}),
                catdir($sc_home,'lib'), 
                catdir($sc_home,'CPAN'), 
                $sc_home,
        );

	unshift @INC, @SlimINC;
}

use DBI;

my $prefs_file = "$::sc_home/prefs/server.prefs";

my $source = sprintf(getPref('dbsource'), 'slimserver');
my $username = getPref('dbusername');
my $password = getPref('dbpassword');

my $dbh = DBI->connect($source, $username, $password, {
	RaiseError => 1,
	AutoCommit => 0,
	PrintError => 1,
	Taint      => 1,
});

unless ($dbh) {
	die "Couldn't connect to database $source. Error $!\n";
}

my @albums        = ();
my @tracks        = ();
my @artists       = ();
my ($sth1, $sth2) = '';

$" = " - ";

print "Album and track list:\n\n";

$sth1 = $dbh->prepare("select A1.id, A2.name, A1.title from albums A1, contributors A2 where A1.contributor = A2.id order by A2.name, A1.title");
$sth1->execute;
while (@albums = $sth1->fetchrow_array) {
	print "@albums\n";
	$sth2 = $dbh->prepare("select distinct tracks.id, tracks.title from tracks, contributors where tracks.album = $albums[0] order by tracknum");
	$sth2->execute;
	while (@tracks = $sth2->fetchrow_array) {
		print "\t@tracks\n";
	}
}
print "\n\n";

print "Artist list:\n\n";
$sth1 = $dbh->prepare("select name,id from contributors order by name");
$sth1->execute;
while (@artists = $sth1->fetchrow_array) {
	print "@artists\n";
}

$dbh->disconnect;

sub getPref {
	my $pref = shift;
	my $value;

	open PREF, $prefs_file or die "open: $prefs_file: $!";
	while (<PREF>) {
		if (/^$pref:\s+(.*)$/) {
			$value = $1;
			$value =~ s/^'//;
			$value =~ s/'$//;
			return $value;
		}
	}
	close PREF;
	return;
}
