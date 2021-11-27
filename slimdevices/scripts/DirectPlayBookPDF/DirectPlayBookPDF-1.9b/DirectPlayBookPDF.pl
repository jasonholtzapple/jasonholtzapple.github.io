#!/usr/bin/perl

# DirectPlayBookPDF.pl by Chris LaPlante (chrisla23@gmail.com)
# based on DirectPlayBook.pl by Jason Holtzapple (jasonholtzapple@yahoo.com)
# see AUTHORS file for complete details
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
#
# You will probably need to modify the very first line of the script
# to point to the version of perl used by SlimServer and also
# the $slim_home variable.

use strict;
#use diagnostics;
use Config;
use File::Spec::Functions qw(:ALL);
#use Time::HiRes;
use DBI;
use PDF::Reuse;                       # Mandatory  
use PDF::Reuse::Barcode;                       # Mandatory  
use Image::Info qw(image_info dim);
use Image::Magick;
use LWP::Simple;
use File::Copy;
use IO::Socket;

# set slimserver's directory you may need to edit the slim_home variable
# this is set before perl compiles
BEGIN {

        # Set to your slimserver home directory
        # eg. 

        # (Fedora RPM) 
	our $slim_home = '/usr/local/slimserver'; 
	
	# (OSX Systemwide install)
	# our $slim_home = '/Library/PreferencePanes/SlimServer.prefPane/Contents/server';

	# (Debian package)
        # our $slim_home = '/usr/share/slimserver';
	
	#our $slim_home = '~';
	#our $slim_home = '/usr/slimserver';

	# please email me if you are using another location not listed above
}

# path to the slimserver preferences file; this should be detected on its own
# only define if your preferences file can not be found.
# eg. /etc /etc/slimserver /Users/chris/Library/SlimDevices
our $prefsPath = '';

# name of the slimserver preferences file
# eg slimserver.pref (OSX, Windows, Some variations of 6.2.x/6.3.x Linux/UNIX, All variations of 6.5.x Linux/UNIX)
# /etc/slimserver.conf Some variations of 6.2.x/6.3.x Linux/UNIX
# .slimserver.pref Some older versions of slimserver.
# only define if your preferences file can not be found.
our $prefsFile = '';

# set default temp location
# only define to use a non standard location for your OS.
#my $tmp='/tmp';
my $tmp;

# debug on or off 
# 0 off / 1 on
my $debug;
$debug = '0';

# run silent except for errors
# 0 off / 1 on
my $quiet;
$quiet = '0';

# stop on a particular album id number - used for debugging script problems
# leave empty to run thru to the end
my $stoponalbum = '';

# output PDf filename
my $outputfile='covers.pdf';

# first page printed on cardstock on or off
# this just puts it on a single sided page even if duplexing is on so it can be 
# put in the clear front of a binder
# 0 off / 1 on
my $cardstock;
$cardstock = '1';

# assume duplex printing on or off
# 0 off / 1 on
my $duplex;
$duplex = '1';

# handle compilations
# false off / 1 on
# the is will allow compilatons to be handled correctly, but may cause errors if your tags are not pristine (something marked as a compilation when its not)
# compilations will show up under the artist of the last track / I have not decided how to handle various artists yet

my $handlecompilations = '1';
#my $handlecompilations = 'false';
	
# if the album only has less than a certain number of tracks, skip it - no need to kill a tree over that
# set to 0 to disable
my $mintracks = '2';
#my $mintracks = '0';

# heading text of the first page
my $covertitle='Our Music';

# turn on/off building of an index page at the end
# 0 off / 1 on
my $makeindex;
$makeindex = '1';

# script assumes you have cover art named cover.jpg extracted into your music
# folders, it will not currently read this data from mp3 tags
# set the  cover art to use if none is found in the db
my $defaultart='/usr/share/note.jpg';

# path to ImageMagic's 'convert' app default assumes it is in your path
my $convert='convert';

# modify perl lib include paths
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
# these can't be used until some of the above is setup
use Slim::Utils::OSDetect;
use Slim::Utils::Prefs;

# set the prefs file location based on the os
# only runs if $prefsPath is not defined above

unless ($prefsPath) {
        if (Slim::Utils::OSDetect::OS() eq 'mac') {
                $prefsPath = catdir($ENV{'HOME'}, 'Library', 'SlimDevices');
		$tmp = '/tmp' unless($tmp);
        } 
	elsif (Slim::Utils::OSDetect::OS() eq 'win')  {
                $prefsPath = $::slim_home;
		$tmp = 'C:\temp' unless($tmp);
        } 

	elsif (Slim::Utils::OSDetect::OS() eq 'unix') {
		if (-d '/etc/slimserver') {
                	$prefsPath = '/etc/slimserver';
			$tmp = '/tmp' unless($tmp);  
		}

		elsif (-d '/etc') {
                	$prefsPath = '/etc';
			$tmp = '/tmp' unless($tmp);
		}
	}
	else {
               	$prefsPath = $ENV{'HOME'};
		$tmp = '/tmp' unless($tmp);
       	}
}

# set the prefs file location based on the os
# only runs if $prefsFile is not defined above

unless ($prefsFile) {

if (Slim::Utils::OSDetect::OS() eq 'win')  {
        $prefsFile = catdir($prefsPath, 'slimserver.pref');
	$tmp = 'C:\temp' unless($tmp);
} 
elsif (Slim::Utils::OSDetect::OS() eq 'mac') {
        $prefsFile = catdir($prefsPath, 'slimserver.pref');
	$tmp = '/tmp' unless($tmp);
}
elsif (Slim::Utils::OSDetect::OS() eq 'unix') {
        if (-f catdir($prefsPath, 'slimserver.pref')) {
                $prefsFile = catdir($prefsPath, 'slimserver.pref');
		$tmp = '/tmp' unless($tmp);
	}
        elsif (-f catdir($prefsPath, 'slimserver.conf')) {
                $prefsFile = catdir($prefsPath, 'slimserver.conf');
		$tmp = '/tmp' unless($tmp);
	}
        elsif (-f catdir($prefsPath, '.slimserver.pref')) {
                $prefsFile = catdir($prefsPath, 'slimserver.pref');
		$tmp = '/tmp' unless($tmp);
	}

        elsif (-f catdir($prefsPath, '.slimserver.conf')) {
                $prefsFile = catdir($prefsPath, 'slimserver.conf');
		$tmp = '/tmp'
	}
} 

}

# check to see if the environment looks sane
unless (-f "$prefsFile") {        die "Your preferences file can not be found. Your preferences path is: $prefsPath. Your preferencese file is: $prefsFile. You will need to define your preferences file name and/or your preferences path.";
}

unless (-d "$tmp") {
        die "Your temp directory can not be found. Your temp directory is set to: $tmp";
}

unless (-f "$defaultart" ) {
        warn "Your default cover art can not be found. Your default art is set to: $defaultart";
}

# load the preferences file
print "Using preferences file: $prefsFile  \n" if $debug;
Slim::Utils::Prefs::load($prefsFile, 1);


# these two lines will need to be uncommented, and the next $db line commented  if you are using the stock db
# I have not tested this and this access can and will lock up slimserver due to locking
# issues using the stock 6.2.x file based DB though although it should continue to access the db  and complete.
# switch to mysql to avoid this
# this should be the default on 6.5
# my $db = Slim::Utils::OSDetect::OS() eq 'unix' ? '.slimserversql.db' : 'slimserversql.db';
# $db = catdir(Slim::Utils::Prefs::get('cachedir'), $dbname);

# the name of your slimserver database comment this if you are using the stock DB
my $db = 'slimserver';

# fetch the source information for the database
# DB
my $source   = sprintf(Slim::Utils::Prefs::get('dbsource'), $db);
#my $source   = 'dbi:mysql:database=slimserver';
#my $source   = 'dbi:mysql:database=slimservercopy';

# DB Username
my $user = Slim::Utils::Prefs::get('dbusername');
#my $user = 'root';

# DB Password
my $password = Slim::Utils::Prefs::get('dbpassword');
#my $password = 'PASSWORD';

# get band sorting pref, see declaration below for more info
my $useBandAsAlbumArtist = Slim::Utils::Prefs::get('useBandAsAlbumArtist');

# Albums that contain songs that are tagged with a band may be listed under that band# name or with the other artists for that album.
# The band tag is also known as TPE2 and may appear as the "album artist" in some software.
# Set this to 0 to list ablum's artists only as their band name
# Set to 1 to list albums under each contributer
# eg:
# 0. Only list:  Van Halen -- 1984
# 1. List: Van Halen -- 1984 As well as: Alex Van Halen/David Lee Roth/Eddie Van Halen/Michael Anthony -- 1984
# leave commented to pull in the setting from your slimserver configuration
#$useBandAsAlbumArtist = '1';


# You can specify if multiple disc sets are treated as a single 
# album (with a single name) or as multiple albums, each with a i
# unique name per disc, for example "Album Title (Disc 2 of 3)". 
# 0. Treat multi-disc sets as multiple albums
# 1. Treat multi-disc sets as a single album
# note that setting this to 1  currently will mean scanning the barcode for this album will only play the first disc's tracks - to be fixed
# leave commented to pull in the setting from your slimserver configuration
my $groupdiscs = Slim::Utils::Prefs::get('groupdiscs');
#$groupdiscs = '1';

# hostname of your slimserver
my $host="localhost";

my $httpport = Slim::Utils::Prefs::get('httpport');

# define album variables
my @albums        = ();
my @tracks        = ();
my @artists       = ();
my ($sth1, $sth2) = '';
my $page;


# setup the index hash
my %index;
my @subindex;

# set the column sep
$" = " - ";

#connect to MySQL database
my $dbh   = DBI->connect ("$source",
                           $user,
                           $password, 
			   { 
			   RaiseError => 1,
		           AutoCommit => 0,
		           PrintError => 1,
		           Taint      => 1,})

                           or die "Can't connect to database: $DBI::errstr\n";
# fail if it does not connect
unless ($dbh) {
	die "Couldn't connect to database $db. Error $!\n";
}

# Change server details below if necessary
# connect to the slim server CLI sockset

my $socket = IO::Socket::INET->new (PeerAddr => "$host",
                                    PeerPort => 9090,
                                    Proto    => 'tcp',
                                    Type     => SOCK_STREAM)
or die 'Couldn\'t connect to slimserver';

# setup a routine to talk to the server 
# Send given cmd to $socket and return answer with original command removed from
# front if present.  Routine nicked from code by Felix Mueller. :-)

sub sendAndReceive {
  my $cmd = shift;

  return if( $cmd eq "");
  print $socket "$cmd\n";  $debug > 1 && print "Sent $cmd to server\n";
  my $answer = <$socket>;
  $debug > 1 && print "Server replied: $answer\n";
  $answer =~ s/$cmd //i;
  $answer =~ s/\n//;
  return $answer;
}

# Setup the document
my $textx = 300; #  pixels from the right edge
my $texty = 763; #  pixels from the bottom
my $step = 14; # spacing between lines for a 12 point font
my $align = 'center';
my $oldfirstchar;
prFile("$outputfile");                 # Mandatory, with or without a file name

# catch interupts and close out the PDF doc cleanly
$SIG{INT} = \&catch_int;
sub catch_int {
     print "$$ - Ieeee! I was murdered. \n";
# write out the index if enabled
&buildindex if $makeindex;
# close out the PDF file
     prEnd();                              # Mandatory
     die "Some day I will get revenge.\n";
 }


# write out a first page title
my $font = 'Courier-Bold';
my $fontsize = '60';
prFont($font);                    # Sets font
prFontSize($fontsize);                            # And font size
my $string = "$covertitle";
prText($textx, $texty, $string, $align );


# setup a hash of command barcodes
my %command = (
"91000000000" => "Clear playlist and load album mode",
"92000000000" => "Insert album after the current album mode",
"93000000000" => "Insert album after the current song  mode",
"94000000000" => "Delete the album from the playlist mode",
"95000000000" => "Save the current playlist as the current date",
"96000000000" => "Re-Save the current playlist",
"97000000000" => "Clear the current playlist",
);

# generate a list of squeezeboxen attached to this server
# Get the number of players
my @playerIds;
my $playerCount = sendAndReceive('player count ?');
$debug && print "$playerCount players found\n";

for (my $i = 0; $i <  $playerCount; $i++) {
# Get the player's internal id and store for future reference
        $playerIds[$i] = sendAndReceive("player id $i ?");
        $debug && print "Player $i has ID $playerIds[$i]\n";

# Get the player's name
        my $playerName = sendAndReceive("player name $playerIds[$i] ?");
	# repack the string as unicode
	$playerName = pack "U0C*", unpack "C*", $playerName;
        $debug && print "Player ${i}'s name is $playerName\n";
        my $playerModel = sendAndReceive("player model $playerIds[$i] ?");
        $debug && print "Player ${i}'s model is $playerModel\n";

# replace control codes with actual spaces to make the names human readable
# are there other codes that should be replaced?
	$playerName =~ s/%20/ /g;

# pad the id

# add the players to the command bardcode hash used to generate the cover page
	my $id = ($i+1).'0000000000';
	$command{$id} = "Control $playerName" if $playerModel ne 'slimp3';
}




# setup variables for the command barcodes
my ($barcode, $command);
my $barcodex = 33;
$textx = 37;
my $barcodey = 705;
my $barcodestep = 79;
my $barcodesize = 1.5;
$align = 'left';
$font = 'Times-Bold';
$fontsize = '10';
prFont($font);                    # Sets font
prFontSize($fontsize);                            # And font size

# write out the command barcodes on the cover page
my $rowcount=0;
my $maxrows=8;
foreach $barcode (sort keys %command) {
         # pop to the top of the next column
                        # in a column
			if ($rowcount > $maxrows) {
			$barcodey = 705;
                        $barcodex = $barcodex + 200;
                        $textx = $textx + 200;
                                if ($barcodex >= '450') {
                                        prPage();
                                        $barcodex=33;
                                        $barcodey=705;
                                        $textx=37;
                                }
                                $rowcount = 0;
                        }

	print "Command: $command{$barcode} Barcode: $barcode\n" if $debug;
	my $code = $barcode;
	PDF::Reuse::Barcode::UPCA (x       => $barcodex,
                              y       => $barcodey,
                              value   => $code,
                              size    => $barcodesize,
                              mode    => 'graphic');
	$string = "$command{$barcode}";
	$texty = $barcodey - 10;
	#$texty = 690;
	prText($textx, $texty, $string, $align );
	$barcodey -= $barcodestep;
	$rowcount++;
}

# insert a page so the cover is on its own page when duplex printed, don't do this if the first page will be printed on its own cardstock
prPage() unless $cardstock;                              # Page break
prText($textx, $texty, ' ', $align ) unless $cardstock;

# fetch the albums
# 
# handle different cases
# this section sucks, ideas wanted


# 1. List: Van Halen -- 1984 As well as: Alex Van Halen/David Lee Roth/Eddie Van Halen/Michael Anthony -- 1984
# 1. Treat multi-disc sets as a single album
# note that this currently will mean scanning the barcode for this album will only play the first tracks of this album - to be fixed
if ($useBandAsAlbumArtist && $groupdiscs) {
	$sth1 = $dbh->prepare("
       		select distinct
         	  min(A1.id), A2.name, A1.title, A2.id, A2.namesort, A1.disc, A1.discc, A1.compilation
       		from
         	  albums A1, contributors A2, contributor_album CA
       		where
         	  CA.contributor = A2.id
       		and
         	  A1.id = CA.album
       		group by
         	 A2.id, A1.title, A2.name
         	--    A2.id, A1.title
       		order by
         	  A1.compilation, A2.namesort, A1.title
	");
}

# 1. List: Van Halen -- 1984 As well as: Alex Van Halen/David Lee Roth/Eddie Van Halen/Michael Anthony -- 1984
# 0. Treat multi-disc sets as multiple albums
elsif ($useBandAsAlbumArtist && ! $groupdiscs) {
        $sth1 = $dbh->prepare("
                select distinct
                  min(A1.id), A2.name, A1.title, A2.id, A2.namesort, A1.disc, A1.discc, A1.compilation
                from
                  albums A1, contributors A2, contributor_album CA
                where
                  CA.contributor = A2.id
                and
                  A1.id = CA.album
                group by
		  -- A2.id, A1.title, A1.disc
                  A2.id, A1.title, A2.name, A1.disc
                order by
                  A1.compilation, A2.namesort, A1.title, A1.disc
        ");
}

# 0. Only list:  Van Halen -- 1984
# 1. Treat multi-disc sets as a single album
# note that this currently will mean scanning the barcode for this album will only play the first tracks of this album - to be fixed
elsif (! $useBandAsAlbumArtist && $groupdiscs) {
        $sth1 = $dbh->prepare("                
		select distinct 
                  min(A1.id), A2.name, A1.title, A2.id, A2.namesort, A1.disc, A1.discc, A1.compilation
                from
                  albums A1, contributors A2, contributor_album CA
                where
                  CA.contributor = A2.id
                and
                  A1.id = CA.album
		and
		 ROLE = 1
                group by
                 A2.id, A1.title, A2.name
                order by
                 A1.compilation, A2.namesort, A1.title
        ");
}

# 0. Only list:  Van Halen -- 1984
# 0. Treat multi-disc sets as multiple albums
elsif (! $useBandAsAlbumArtist && ! $groupdiscs) {
        $sth1 = $dbh->prepare("
                select distinct
                  min(A1.id), A2.name, A1.title, A2.id, A2.namesort, A1.disc, A1.discc, A1.compilation
                from
                  albums A1, contributors A2, contributor_album CA
                where
                  CA.contributor = A2.id
                and
                  A1.id = CA.album
                and
                 ROLE = 1
                group by
                 A2.id, A1.title, A2.name, A1.disc
                order by
                  A1.compilation, A2.namesort, A1.title, A1.disc
        ");
}

$sth1->execute;

# iterate thru them
while (@albums = $sth1->fetchrow_array) {

# strip out the artist name on compilations.
#	if ($albums[7]) {
#        	$albums[4] = 'VARIOUS ARTISTS';
#        	$albums[1] = 'Various Artists';
#	}

# fetch the track and artwork info
# 1. List: Van Halen -- 1984 As well as: Alex Van Halen/David Lee Roth/Eddie Van Halen/Michael Anthony -- 1984
#if ($useBandAsAlbumArtist) {
        $sth2 = $dbh->prepare("
	 select min(t.id), t.title as title, t.tracknum, t.cover, t.disc, a.compilation
    from albums a,
         tracks t,
         contributor_track ct,
         contributor_album ca
    where t.album = $albums[0]
      and ca.album = a.id
      and ca.contributor = $albums[3]
      and t.album = a.id
      and ct.track = t.id
      and (ct.contributor = ca.contributor or ((a.compilation = '0' and ct.contributor = ca.contributor) or a.compilation = $handlecompilations))
    group by t.title, t.disc, t.tracknum, t.cover, t.disc, a.compilation
    order by disc, tracknum
    ;







	");
#}

# 0. Treat multi-disc sets as multiple albums
#else {
#        $sth2 = $dbh->prepare("
#               select
#                 min(t.id), t.title as title, t.tracknum, t.cover
#               from
##                 albums a,
#                 tracks t,
#                 contributor_track ct,
#                 contributor_album ca
#               where
#                 t.album = $albums[0] and
#                 ca.album = a.id and
#                 ca.contributor = $albums[3] and
#                 t.album = a.id and
#                 ct.contributor = ca.contributor and
#                 ct.track = t.id
#                 group by t.title, t.tracknum
#                 order by tracknum
#        ");

#}
        $sth2->execute;
        my $rowcount = $sth2->rows;
	# if the album only has too few tracks skip it - no need to kill a tree over that
	next if ($rowcount <= $mintracks && $mintracks);
        print "Track count was: $rowcount\n" if $debug;
	#print "\t$albums[3]\n";
	    # next page
	prPage();                              # Page break
	$page++;
	
	my $firstchar = substr($albums[4],0,1);
	# if the first important character of the artist name has changed since the last loop, and the page
	# number is even (ie. the back of a duplex
	# printed page), insert an extra space and increment the page count. This way it will spilt up nice between an alphabetic tab page
	# divider
	if (! $page % 2 && $page ne '1' && $firstchar ne $oldfirstchar && $duplex ) {
		print "Extra Page: $page First: $firstchar Old First: $oldfirstchar\n" if $debug;
        	prPage();                              # Page break
        	prText($textx, $texty, ' ', $align );
        	prPage();                              # Page break
        	$page++;

	} 
	$oldfirstchar = $firstchar;



# add an index entry for this album to the hash to be used later
# setup a hash of arrays with the artists sortable id as the key, the artists name as the first value, and their albums after that
	# if the key for the sortable name of the artist already exists
	# push the name of the album onto the index
	if ($index{"$albums[4]"}) {
		if ($albums[5] && $albums[5] <= $albums[6] && $albums[6] > '1' && ! $groupdiscs) {
			push @{ $index{"$albums[4]"} }, "$albums[2] ($albums[5] of $albums[6])";
		}
		else {
			push @{ $index{"$albums[4]"} }, "$albums[2]";
		}
	}
	# else this must be the first entry for this artist
	# add the name of the artist as the first entry, then append the name
	# of the album
	else {
		if ($albums[5] && $albums[5] <= $albums[6] && $albums[6] > '1' && ! $groupdiscs) {
			push @{ $index{"$albums[4]"} }, "$albums[1]", "$albums[2] ($albums[5] of $albums[6])";
		}
		else {
			push @{ $index{"$albums[4]"} }, "$albums[1]", "$albums[2]";
		}
	}
	# reset the character positions for the new page
	my $textx = 105; # 105 pixels from the right edge
	my $texty = 400; # 400 pixels from the bottom
	my $step = 14; # spacing between lines for a 12 point font

# break on a certain album code to catch problems
# uncomment the next three lines and enter the album you want the script to stop at
# it will stop at the ablum BEFORE this album is sent to the output
	if ($stoponalbum && $albums[0] == "$stoponalbum") {
	print "Stopping at album $albums[0] for investigation\n";
	&catch_int;
}

# setup the album barcode variables
$align = 'left';
$font = 'Times-Bold';
$fontsize = '10';
prFont($font);                    # Sets font
prFontSize($fontsize);                            # And font size
my $barcodex = 327; 
$textx = $barcodex + 46;
my $barcodey = 440; 
my $barcodesize = 1.5; 

# write out the album barcode
die "You must have allot of music, the ID is too big for the barcode." if (length($albums[3]) > 5 || length($albums[0]) > 5);
my $codea = sprintf("%06d", $albums[3]);
my $codeb = sprintf("%05d", $albums[0]);
my $code = $codea.$codeb;
print "Code: $code\n" if $debug;
PDF::Reuse::Barcode::UPCA (x       => $barcodex,
                              y       => $barcodey,
                              value   => $code,
                              size    => $barcodesize,
                              mode    => 'graphic');
			      $string = "Play this album";
        		      $texty = $barcodey - 10;
      			      prText($textx, $texty, $string, $align );

# setup up the play everything by this artist barcode
$barcodex = 117;
$textx = $barcodex + 36;
$barcodey = 440;
# pad the id with zeros
# set the fifth digit to 1 to signify this is an artist barcode
$codea = sprintf("%06d", $albums[3]);
$codeb = '00000';
$code = $codea.$codeb;
print "Code: $code\n" if $debug;

# write out the artist barcode
PDF::Reuse::Barcode::UPCA (x       => $barcodex,
                              y       => $barcodey,
                              value   => $code,
                              size    => $barcodesize,
                              mode    => 'graphic');
                              $string = "Play all by this artist";
                              $texty = $barcodey - 10;
                              prText($textx, $texty, $string, $align );


# set the fonts and write the artist and album name
	$textx ='300';
	$texty = 400; # 400 pixels from the bottom
	my $align = 'center';
	$font = 'Times-Bold';
	$fontsize = '14';
	prFont($font);                    # Sets font
	prFontSize($fontsize);                            # And font size
# write out the Artist and Album names waffle
		if ($albums[5] && $albums[5] <= $albums[6] && $albums[6] > '1' && ! $groupdiscs) {
			$string = "$albums[1] - $albums[2] ($albums[5] of $albums[6])";	
		}
		else {
			$string = "$albums[1] - $albums[2]";	
		}
	print "$string \n" unless $quiet;
# chop down the artist and album line so it does not run off the page
	$string = substr($string, 0, 87);
# repack the string as unicode
	$string = pack "U0C*", unpack "C*", $string;
	prText($textx, $texty, $string, $align );
	$texty -= $step;
	$texty -= $step;

# set the locations for the track listings
	$textx = '39';
	$font = 'Times-Roman';
	$fontsize = '12';
	prFont($font);                    # Sets font
	my $file;
	my $height;
	my $width;
	my $addedart = '0';
	my $frameheight = '0';
	my $framewidth = '0';
	my $coverx = '150';
	my $covery = '500';
	my $maxstringlength = '0';
	my $maxrows = '23';
	undef $file;
	my $trackcount = '0';
	my $oldtrack;

# iterate over the tracks and write them out to the pdf
	while (@tracks = $sth2->fetchrow_array) {
		print "\tSong ID: $tracks[0] Track: $tracks[2] Song: $tracks[1] Art: $tracks[3] \n" if $debug;

# add the album art if it exists and has not already been added
		# small known bug, the element for tracks[3] may not always exist
		if ($file eq undef && !$addedart) {
		my $content;
		my $url;
# fetch the cover art from the web server
# there must be a better way to do this, the path to the cover art for a given 
# track used to be stored in the DB in earlier versions ... grrr...
			my $url="http://$host:$httpport/music/$tracks[0]/cover.jpg";
			print "Cover status: $tracks[3] Fetching art: $url\n" if $debug;
			$content=get($url);
			warn "Could not fetch cover art for track: $tracks[0]." if (!defined($content));
			open(FH, "> $tmp/cover-tmp.jpg");
			print FH $content;
			close(FH);
##

        	        $file = "$tmp/cover-tmp.jpg";
			print "Adding art: $file\n" if $debug;
                	my $info = image_info($file);
                	($width, $height) = dim($info);    # Get the dimensions
# resize the art if it is too large
			if ($width  >= 302  || $height >= 302) {
				print "Resizing ... old image $width x $height\n" if $debug;
				my($image, $x);
  				$image = Image::Magick->new;
  				$x = $image->Read($file);
				die "$x" if "$x";
  				$x = $image->Resize(geometry=>'300x300');
  				warn "$x" if "$x";
# write out the resized image
				$file = "$tmp/cover.jpg";
  				$x = $image->Write($file);
  				warn "$x" if "$x";
# reset the height and width to the exact end result (sometimes maintaining aspect ratio means it is not 300x300
				($width, $height) = $image->Ping("$tmp/cover.jpg");
				print "Resizing ... new image $width x $height\n" if $debug;
				#$x = $image->Display('10.0.0.83:0.0');
                                #warn "$x" if "$x";
				undef $image;
				undef $x;
			}
# if the art is too small center it
			if ($width  < 300 || $height < 300) {
				$frameheight = ('300' - $height) / 2 ; 
				$framewidth = ('300' - $width) / 2 ;
				print "Framing image $height x $width with frame $frameheight x $framewidth\n" if $debug;
			}

# check to see that the file is really a jpeg, don't trust the file extension.

			     my($image, $x);
                                $image = Image::Magick->new;
                                $x = $image->Read($file);
                                die "$x" if "$x";
			 	my $filetype =  $image->Get('magick');
# conver the file to a JPEG if it is an image file
				if ($filetype ne 'JPEG' && $filetype ne '') {
					print "Converting image $file to a JPEG \n" if $debug;
					eval {
# this eval is pretty UNIX centric it may bomb on windows
						copy("$file","$tmp/x.$filetype") or die "Copy failed: $!";
						system("$convert $tmp/x.$filetype $tmp/cover1.jpg");
					}; die "There was an error converting: $file to a JPEG from filetype: $filetype. Error was: $@" if $@;
					$file = "$tmp/cover1.jpg";

				}	
                                undef $image;
                                undef $x;
# actually write the image into the PDF
                	my $intName = prJpeg("$file",         # Define the image
                        	 $width,         # in the document
                         	$height);

                	my $str = "q\n";
			my $widthborder = $framewidth + $coverx;
			my $heightborder = $frameheight + $covery;
                	$str   .= "$width 0 0 $height $widthborder $heightborder cm\n";
                	$str   .= "/$intName Do\n";
                	$str   .= "Q\n";
                	prAdd($str);
			undef $height;
			undef $width;
			$addedart = '1';
	        }

# write out the track listing text and increment the track counter
			#warn about duplicate tracks; your tags are all perfect right?
			warn "Error current track number is the same as the last one, check your tags. Track: $tracks[2] Old track: $oldtrack Album: $albums[1] - $albums[2] -- select distinct tracks.id, tracks.title, tracks.tracknum, tracks.cover from tracks, contributors where tracks.album = $albums[0] order by tracknum \n;" if ($tracks[2] && $oldtrack && $tracks[2] == $oldtrack); 
		# if this is a multi disc set with track numbers include the disc number and the track number.
			if ($tracks[2] && $tracks[4]  && $groupdiscs) {
				$string = "$tracks[4].$tracks[2]. $tracks[1]";
				# repack the string as unicode
				$string = pack "U0C*", unpack "C*", $string;
				$oldtrack=$tracks[2];
			}
		# else if it not a multi disc set and only includes the track number only include that
			elsif ($tracks[2]) {
				$string = "$tracks[2]. $tracks[1]";
				# repack the string as unicode
				$string = pack "U0C*", unpack "C*", $string;
				$oldtrack=$tracks[2];
			}
			# else just write out the track name
			else {
				$string = " $tracks[1]";
				# repack the string as unicode
				$string = pack "U0C*", unpack "C*", $string;
			}
# if we are multi column we need to lay down the law on string length or risk a mess
		if ($rowcount > $maxrows) {
			$string = substr($string, 0, 45);
		} 
# find the max string length to align the next column
		my $stringlength = prStrWidth($string, $font, $fontsize);
		$maxstringlength = $stringlength if ($stringlength > $maxstringlength);
		prText($textx, $texty, $string) if $textx <= '450';
		$texty -= $step;
		$trackcount++;

# start a new column if we get to the bottom of the page
		if ($trackcount >= $maxrows) {
			$textx = $textx + $maxstringlength + 60;
			$texty = 400;
			$texty -= $step;
			$texty -= $step;
			$maxstringlength=0;
			$trackcount = 0;
		}
	}
# add some default art if it has not been added already
        unless ($addedart) {
                $file = "$defaultart";
                my $info = image_info($file);
                ($width, $height) = dim($info);    # Get the dimensions

                print "Adding default art: $file.\n" if $debug;
                        my $intName = prJpeg("$file",         # Define the image
                                 $width,         # in the document
                                $height);

                        my $str = "q\n";
# border is frame size + initial indent
                        my $widthborder = $framewidth + $coverx;
                        my $heightborder = $frameheight + $covery;
                        $str   .= "$width 0 0 $height $widthborder $heightborder cm\n";
                        $str   .= "/$intName Do\n";
                        $str   .= "Q\n";
                        prAdd($str);
                        undef $height;
                        undef $width;

        }

}

# create the index pages
# routine to create an index page
sub buildindex {

my $artist;
my $i;
my $tabx = 15;
$textx = '55';
$texty = '800';
#$font;
#$fontsize;
my $maxrows = '52';
my $trackcount = '0';
#$string;
prFont($font);                    # Sets font
prPage();                              # Page break
$page++;

# make sure the index does not start on the back of the last album
if (! $page % 2) {
	print "Extra Page: $page\n" if $debug;
	prPage();                              # Page break
	prText($textx, $texty, ' ', $align );
	prPage();                              # Page break
	$page++;
        }


# write out the index pages
foreach $artist ( sort keys %index ) {
     foreach $i ( 0 .. $#{ $index{$artist} } ) {
                if ($i == 0) {
                        $trackcount++;
                        $font = 'Times-Bold';
                        $fontsize = '12';
                        prFont($font);
                        prFontSize($fontsize);                            # And font size
                        $string = "$index{$artist}[0]";
			# repack the string as unicode
			$string = pack "U0C*", unpack "C*", $string;
                        $string = substr($string, 0, 40);

			# pop to the top of the next column instead of writing out the artist name as the last item 
			# in a column
			if ($trackcount == $maxrows) {
                        $textx = $textx + 300;
                        $texty = 800;
                                if ($textx >= '450') {
                        	        prPage();
                                	$textx=55;
                                }
                        	$trackcount = 0;
			}
                        $textx -= $tabx;
			# repack the string as unicode
			$string = pack "U0C*", unpack "C*", $string;
			prText($textx, $texty, $string, $align);
                        $textx += $tabx;
                        $texty -= $step;
                        print "$index{$artist}[0]\n" unless $quiet;
                }
                else {
                        $font = 'Times-Roman';
                        $fontsize = '10';
                        prFont($font);
                        prFontSize($fontsize);                            # And font size

                        # tab in a bit for the albums
                        $string = "$index{$artist}[$i]";
			# repack the string as unicode
			$string = pack "U0C*", unpack "C*", $string;
                        $string = substr($string, 0, 45);
                        prText($textx, $texty, $string, $align);
                        $texty -= $step;
                        print "\t$index{$artist}[$i]\n" unless $quiet;
                        $trackcount++
                }
#                # start a new column if we get to the bottom of the page
                if ($trackcount >= $maxrows) {
                        $textx = $textx + 300;
                        $texty = 800;
                                if ($textx >= '450') {
                                	prPage();
                                	$textx=55;
                                }
                        $trackcount = 0;
                }


     }
}

}

# create the index pages
&buildindex if $makeindex;

# closeout the PDF file
prEnd();                              # Mandatory

# disconnect from the database
$sth1->finish;
$sth2->finish;
$dbh->disconnect;
