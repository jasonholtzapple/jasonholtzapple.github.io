#!/usr/bin/perl

# DirectPlayBookODF.pl by Jason Holtzapple (jasonholtzapple@yahoo.com)
#
# Contains code copied from Slim Device's main slimserver distribution
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
#
# You will probably need to modify the very first line of the script
# to point to the version of perl used by SlimServer and also
# the $slim_home variable.
#
#-> Changelog
#
# Sat Jul  8 12:04:44 MST 2006 - prerelease version 1

use strict;
use File::Spec::Functions qw(:ALL);
use OpenOffice::OODoc;

BEGIN {

	# Set to your slimserver home directory

	our $slim_home = '/export/home/slim/SlimServer_v6.3.0';
}

# Adjustable Document Parameters

# cover art size
our $coverart_x = '3cm';
our $coverart_y = '3cm';

# Define these only if necessary

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

my @albums                    = ();
my @tracks                    = ();
my $albumtracks               = '';
my @artists                   = ();
my @art                       = ();
my ($id, $name, $title, $art) = '';
my ($sth1, $sth2, $sth3)      = '';

$" = " - ";

my $doc = ooDocument(create => 'text', file => 'DirectPlayBook.odt');

$doc->createStyle (
    'Header1',
    family          => 'paragraph',
    parent          => 'Text body',
    properties      => {
        'area'                  => 'text',
        'style:font-name'       => 'Helvetica',
        'style:font-weight'     => 'bold',
        'fo:font-size'          => '24pt',
    }
);

$doc->createStyle (
    'Album',
    family          => 'paragraph',
    parent          => 'Text body',
    properties      => {
        'area'                  => 'text',
        'style:font-name'       => 'Times New Roman',
        'style:font-weight'     => 'bold',
        'fo:font-size'          => '12pt',
    }
);

$doc->createStyle (
    'Track',
    family          => 'paragraph',
    parent          => 'Text body',
    properties      => {
        'area'                  => 'text',
        'style:font-name'       => 'Times New Roman',
        'fo:font-size'          => '10pt',
    }
);


$doc->createImageStyle('Image');

my $np = $doc->appendParagraph (
    text            => 'My Music Collection',
    style           => 'Header1'
);

$sth1 = $dbh->prepare("select A1.id, A2.name, A1.title, A1.artwork_path from albums A1, contributors A2 where A1.contributor = A2.id order by A2.name, A1.title");
$sth1->execute;
while (@albums = $sth1->fetchrow_array) {
    my $np = $doc->appendParagraph (
        text            => "$albums[1] - $albums[2] ($albums[0])",
        style           => 'Album'
    );
    if ($albums[3]){
        $sth3 = $dbh->prepare("select distinct tracks.thumb, tracks.cover from tracks where tracks.album = $albums[0]");
	$sth3->execute;
        @art = $sth3->fetchrow_array;
	if (defined $art[0] && -r $art[0]) {
            $doc->createImageElement (
                "$albums[0]",
                style           => "Image",
                attachment      => $np,
                import          => "$art[0]",
		link            => "Pictures/$albums[0]",
		size            => "$coverart_x, $coverart_y",
		position        => "0, 0"
            );
        } elsif (defined $art[1] && -r $art[1]) {
            $doc->createImageElement (
                "$albums[0]",
                style           => "Image",
                attachment      => $np,
                import          => "$art[1]",
                link            => "Pictures/$albums[0]",
		size            => "$coverart_x, $coverart_y",
		position        => "0, 0"
            );
	}
	undef $sth3;
    }
    $sth2 = $dbh->prepare("select distinct tracks.id, tracks.title from tracks, contributors where tracks.album = $albums[0] order by tracknum");
    $sth2->execute;

    $albumtracks = '';
    while (@tracks = $sth2->fetchrow_array) {
        $albumtracks .= "@tracks\n";
    }
    $np = $doc->appendParagraph (
         text            => "$albumtracks",
         style           => 'Track'
    );
}

$doc->save;

$dbh->disconnect;
