#!/usr/bin/perl -w

# slimbar.pl  by Chris LaPlante (chrisla23@gmail.com)

# parts of the script taken from:
# 
# $Date: 2005-10-30 14:26:26 +0000 (Sun, 30 Oct 2005) $ $Rev: 9 $
# Copyright 2005 Max Spicer.
# Feel free to reuse and modify, but please consider passing modifications back
# to me so they can be included in future versions.
# If you use this script, please let me know!

# sendAndreceive routine nicked from code by Felix Mueller. :-)

# Reads from a barcode reader connected via a keyboard wedge from the Linux event system, decodes the barcode, and issues commands or plays the album# or artist corresponding to the barcode.
#

use strict;
use IO::Socket;
use POSIX qw(strftime);

# specify the barcode reader deviced
my $barcodedev = '/dev/input/event3';

# specify the barcode decoder software, scripts assume UPCA barcodes
my $barcodedecoder = '/usr/local/bin/keytest';

# check to see that the barcode reader device exists and that the decoder software is installed.

if ( ! -c $barcodedev ) {
	die "Error: Can't find barcode device $barcodedev \n";
	}

if ( ! -f $barcodedecoder ) {
	die "Error: Can't execute barcode decoder software $barcodedecoder \n";
	}

# Print debug output if true.  Higher values increase verbosity.
my $debug = 1;

# Change server details below if necessary
# open a socket to the slimserver
my $socket = IO::Socket::INET->new (PeerAddr => '10.0.0.61',
                                    PeerPort => 9090,
                                    Proto    => 'tcp',
                                    Type     => SOCK_STREAM)
or die 'Couldn\'t connect to server';

#my $mac='00%3A00%3Ae2%3A2e%3Ab6%3A7a';
#my $mac='00%3A00%3Ae2%3A2e%3Ab6%3Ad8';
#my $mac='00%3A00%3Ae2%3A2e%3Ab4%3A22';

#figure out the mac address if this machine use that as a default
my $ifconfig= `/sbin/ifconfig eth0`;
my @eth = split(/\n/, $ifconfig);
my ($header,$mac) = split(/ HWaddr /, $eth[0]);

# convert mac to a format the slimserver wants it in
$mac =~ s/:/%3A/g;
$mac =~ s/ //g;

# init the barcode variable
my $barcode;

# default to clearing the playlist and loading the specified album or artist
my $playcmd='load';
while () 
{
open BARCODE, "$barcodedecoder $barcodedev |" or die "$0: exiting, couldnt execute keytest.\n";
print "Ready to scan!\n";
my $barcode = <BARCODE>;
		my $length = length($barcode);
		# check to see that the barcode is a valid length for a UPCA barcode
		# insert fancy checksum checking software here
		if ($length == '13') {

               	 	my $time = time;
			my $command=substr($barcode, 0, 1);
				if ($command == '0') {
				# this is the barcode for an album or artist
#        				$barcode = '000306003927';
#        				$barcode = '000306000000';
					my $artistcode=substr($barcode, 1, 5);	
                        		$artistcode =~ s/^0+//;
					my $albumcode=substr($barcode, 6, 5);
                        		$albumcode =~ s/^0+//;
					#my $barcode=$artistcode.$albumcode;
                        		#my $id=substr($barcode, 0, -1);
		                        print "$time $mac Artist: $artistcode Album: $albumcode \n" if $debug;
                        		sendAndReceive("$mac display Barcode%20Read:%20$albumcode");
					my $ret;
					if ($albumcode) {
					# this is a barcode for a specific album
                        			sendAndReceive("$mac display Barcode%20Read:%20$artistcode%20$albumcode");
						$ret = sendAndReceive("$mac playlistcontrol cmd:$playcmd artist_id:$artistcode album_id:$albumcode");
					}
					else {
					# this is a barcode to play everything by this artist
                        			sendAndReceive("$mac display Barcode%20Read:%20$artistcode");
						$ret = sendAndReceive("$mac playlistcontrol cmd:$playcmd artist_id:$artistcode");
					}

					sendAndReceive("$mac button now_playing");
                        		$debug && print "Return was $ret\n";
				}
				else {
				# this is a special command barcode
					print "Command: $command\n";
					sendAndReceive("$mac display Command%20Barcode%20Read:%20$command");
 					#&barcommand($command);
 					&barcommand($barcode);
				}
	               	print "$time $mac $barcode \n" if $debug;

			undef $barcode;
			undef $length;
			close BARCODE;	
		}
		else {
			print "There was an error reading the barcode: $barcode, length was $length. \n";
                        undef $barcode;
                        undef $length;
			close BARCODE;
		}
}



#  
#  my $timeString = POSIX::strftime("%H:%m:%S", localtime());
#

close $socket;

# Send given cmd to $socket and return answer with original command removed from
# front if present.  Routine nicked from code by Felix Mueller. :-)
sub sendAndReceive {
  my $cmd = shift;

  return if( $cmd eq "");

  print $socket "$cmd\n";
  $debug > 1 && print "Sent $cmd to server\n";
  my $answer = <$socket>;
  $debug > 1 && print "Server replied: $answer\n";
  $answer =~ s/$cmd //i;
  $answer =~ s/\n//;

  return $answer;
}

sub barcommand {
my ($command) = @_;
	# clear the play list and load the currently scanned artist or album
	if ($command == '910000000002') {
		$playcmd = 'load';
		print "Command issued: $playcmd\n";
	}
	# Insert the album or artist after the current album
        elsif ($command == '920000000001') {
                $playcmd = 'add';
		print "Command issued: $playcmd\n";
        }
	# Insert the album or artist after the current song
        elsif ($command == '930000000000') {
                $playcmd = 'insert';
                print "Command issued: $playcmd\n";
        }
	# Delete the album from the playlist
        elsif ($command == '940000000009') {
                $playcmd = 'delete';
		print "Command issued: $playcmd\n";
        }

        elsif ($command == '960000000007') {
	# resave the current playlist if it already has a name, else save it as "Player Name - DATE"
	# get the name of the current player
	my $playerName = sendAndReceive("player name $mac ?");
	# replace control codes with underscores to make the names human readable
	# are there other codes that should be replaced?
        $playerName =~ s/%20/_/g;
	# get the name of the current playlist
	my $playlist;
	my $playlistcmd = sendAndReceive("$mac playlist name ?");
	# slimserver always echos back the command issued even if the playlist name is null
	# thus we need to split up the results and determine if a fourth word is returned
	# split the results
	#my @words = split /\s/, $playlistcmd;
	# the last word is the playlist name if the array has four elements
		if ($playlistcmd){
			#$playlist = $words[4];
			$playlist = $playlistcmd;
        		$playlist =~ s/%3A/:/g;
        		$playlist =~ s/%20/ /g;
			print "Playlist already had a name of: $playlist resaving. \n"; 
		}
		else {
		# this playlist has no name, give it a name
		        my ($min,$hour,$mday,$mon,$year) = (localtime)[1..5];
			($min,$hour,$mday,$mon,$year) = ($min,$hour,$mday,$mon+1,$year+1900);
			my $datestring = "$year-$mon-$mday-$hour:$min";
			$playlist = "$playerName-$datestring";
			# save the playlist with the players name and current date/time	
        		$playlist =~ s/%3A/:/g;
        		$playlist =~ s/%20/ /g;
			sendAndReceive("$mac playlist save $playlist");
			print "Command issued: Save playlist as $playlist \n";
		}

        }
	elsif ($command == '950000000008') {
	# save the current playlist under a new name
	# similar to above, but always saves out a new playlist name even if it already has a name
        # get the name of the current player
	my $playlist;
        my $playerName = sendAndReceive("player name $mac ?");
        # replace control codes with underscores to make the names human readable
        # are there other codes that should be replaced?
        $playerName =~ s/%20/_/g;
        # get the name of the current playlist
        # this playlist has no name, give it a name
        my ($min,$hour,$mday,$mon,$year) = (localtime)[1..5];
        ($min,$hour,$mday,$mon,$year) = ($min,$hour,$mday,$mon+1,$year+1900);
        my $datestring = "$year-$mon-$mday-$hour:$min";
        $playlist = "$playerName-$datestring";
        # save the playlist with the players name and current date/time
        sendAndReceive("$mac playlist save $playlist");
	print "Command issued: Save playlist as $playlist \n";
        }
	
	# clear the playlist and stop
	elsif ($command == '970000000006') {
        sendAndReceive("$mac playlist clear");
       }
       # change the macadress of the player
       else {
		# Get the player's internal id and store for future reference
		# strip off this first character, thie limits the number of players the software can handle
		# this is not ideal but some tricks need to be used to allow for long enough album and artist 
		# ids in the 11 characters provided
		my $id=substr($command, 0, 1);
		# subtract one - one was added to the ID to be able to tell player 0 from an album or artist barcode
		$id = ($id - 1);
        	$mac = sendAndReceive("player id $id ?");
		#$mac = '00%3A04%3A20%3A05%3Acd%3A7c';
                print "MAC changed: $mac\n";
        }

}
