#!/usr/bin/perl

# DirectPlayBook.pl by Jason Holtzapple (jasonholtzapple@yahoo.com)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
#
# You will probably need to modify the very first line of the script
# to point to the version of perl used by SlimServer and also
# the $slim_home variable.

use strict;
use Config;
use File::Spec::Functions qw(:ALL);
use Time::HiRes;

BEGIN {

	# Set to your slimserver home directory

	our $slim_home = '/home/slim/SlimServer_v6.2.1';
}

# Define these if necessary

our $prefsPath = '';
our $prefsFile = '';

BEGIN {
	my @SlimINC = (
		$::slim_home,
		catdir ($::slim_home, 'CPAN'),
                catdir ($::slim_home, 'CPAN', 'arch', (join ".", map {ord} split //, $^V), $Config::Config{'archname'}), 
                catdir ($::slim_home, 'CPAN', 'arch', (join ".", map {ord} split //, $^V), $Config::Config{'archname'}, 'auto'), 
                catdir ($::slim_home, 'CPAN', 'arch', (join ".", map {ord} (split //, $^V)[0,1]), $Config::Config{'archname'}), 
                catdir ($::slim_home, 'CPAN', 'arch', (join ".", map {ord} (split //, $^V)[0,1]), $Config::Config{'archname'}, 'auto'), 
                catdir ($::slim_home, 'CPAN', 'arch', $Config::Config{archname})
	);

	unshift @INC, @SlimINC;
}

use DBI;
use Slim::Utils::OSDetect;
use Slim::Utils::Prefs;

unless ($prefsPath) {
	if (Slim::Utils::OSDetect::OS() eq 'mac') {
		$prefsPath = catdir($ENV{'HOME'}, 'Library', 'SlimDevices');
	} elsif (Slim::Utils::OSDetect::OS() eq 'win')  {
		$prefsPath = $::slim_home;
	} else {
		$prefsPath = $ENV{'HOME'};
	}
}

if (Slim::Utils::OSDetect::OS() eq 'win')  {
	$prefsFile = catdir($prefsPath, 'slimserver.pref');
} elsif (Slim::Utils::OSDetect::OS() eq 'mac') {
	$prefsFile = catdir($prefsPath, 'slimserver.pref');
} else {
	if (-r '/etc/slimserver.conf') {
		$prefsFile = '/etc/slimserver.conf';
	} else {
    		$prefsFile = catdir($prefsPath, '.slimserver.pref');
	}
}

Slim::Utils::Prefs::load($prefsFile, 1);

my $dbname = Slim::Utils::OSDetect::OS() eq 'unix' ? '.slimserversql.db' : 'slimserversql.db';
$dbname = catdir(Slim::Utils::Prefs::get('cachedir'), $dbname);
my $source   = sprintf(Slim::Utils::Prefs::get('dbsource'), $dbname);
my $username = Slim::Utils::Prefs::get('dbusername');
my $password = Slim::Utils::Prefs::get('dbpassword');

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
