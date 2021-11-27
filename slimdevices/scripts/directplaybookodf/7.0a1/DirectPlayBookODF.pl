#!/usr/bin/perl -w

# DirectPlayBookODF.pl by Jason Holtzapple (jasonholtzapple@yahoo.com)
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
# 7.0a1 - 27/11/2007
#    RFE: SqueezeCenter 7.0 ready

use strict;
use Config;
use File::Spec::Functions qw(:ALL);
use OpenOffice::OODoc;

use FindBin qw($Bin);

BEGIN {

	# Set to your slimserver home directory

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

# Adjustable Document Parameters

# cover art size
our $coverart_x = '3cm';
our $coverart_y = '3cm';

# Define these only if necessary

our $prefsPath = '';
our $prefsFile = '';

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

#$sth1 = $dbh->prepare("select A1.id, A2.name, A1.title, A1.artwork_path from albums A1, contributors A2 where A1.contributor = A2.id order by A2.name, A1.title");
$sth1 = $dbh->prepare("select A1.id, A2.name, A1.title, A1.artwork from albums A1, contributors A2 where A1.contributor = A2.id order by A2.name, A1.title");
$sth1->execute;
while (@albums = $sth1->fetchrow_array) {
    my $np = $doc->appendParagraph (
        text            => "$albums[1] - $albums[2] ($albums[0])",
        style           => 'Album'
    );
    if ($albums[3]){
#        $sth3 = $dbh->prepare("select distinct tracks.thumb, tracks.cover from tracks where tracks.album = $albums[0]");
        $sth3 = $dbh->prepare("select distinct tracks.cover from tracks where tracks.album = $albums[0]");
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
