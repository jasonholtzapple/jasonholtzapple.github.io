#	QuickAccess.pm
#
#	Author: Felix Mueller <felix(dot)mueller(at)gwendesign(dot)com>
#
#	Copyright (c) 2003-2005 by GWENDESIGN
#	All rights reserved.
#
#	Based on: Several Plugins and the Alarm Clock
#
#	----------------------------------------------------------------------
#	Function:
#
#	Quick access to preassigned playlists pressing and holding a button
#	New: Or the current playlist from another player
#
#	----------------------------------------------------------------------
#	Installation:
#
#	- Copy this file into the 'Plugins' directory
#	- Add three lines for each remote button to the file 'IR/custom.map'
#	- If the file is not present, add a new one to the 'IR' directory
#	  Example:
#		0		= dead
#		0.single	= numberScroll_0
#		0.hold		= modefunction_PLUGIN.QuickAccess->numberScroll_0
#		1		= dead
#		1.single	= numberScroll_1
#		1.hold		= modefunction_PLUGIN.QuickAccess->numberScroll_1
#	...
#		9		= dead
#		9.single	= numberScroll_9
#		9.hold		= modefunction_PLUGIN.QuickAccess->numberScroll_9
#
#	- Restart the server
#	- Select the 'custom.map' file in the Additional Player Settings (Web GUI)
#	- Assign playlists to the remote number buttons (0-9) in the plugin
#	- Press and hold a remote number button to play the assigned playlist
#	  even if Squeezebox / SLIMP3 was turned off.
#	----------------------------------------------------------------------
#	History:
#
#	2005/02/08 v0.8 - SlimServer V6 ready
#	2004/12/23 v0.7 - iTunes playlists were broken
#	2004/07/21 v0.6 - Turn target player on explicitly
#	2004/07/10 v0.5 - Fix a problem with %20 in strings
#	2003/12/29 v0.4 - Playlist can also be from another player
#	2003/11/19 v0.3 - Adaption to SlimServer v5.0
#	2003/08/19 v0.2 - French translation by Nicolas Guillemain
#	2003/08/17 v0.1	- Initial version
#	----------------------------------------------------------------------
#       To do:
#
#       - Multi language
#       - Clean up code
#	- Use new INPUT.List mode
#
#	This program is free software; you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation; either version 2 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
#	02111-1307 USA
#
package Plugins::QuickAccess;
use strict;

use Slim::Player::Playlist;
use Slim::Player::Source;
use Slim::Player::Sync;
use Slim::Utils::Strings qw (string);

use vars qw($VERSION);
$VERSION = substr(q$Revision: 0.8 $,10);

# ----------------------------------------------------------------------------
# Global variables
# ----------------------------------------------------------------------------

my $debug		= 0;	# 0 = off, 1 = on


my @browseMenuChoices;
my %menuSelection;
my @playerItems;

# ----------------------------------------------------------------------------
sub setMode {
	my $client = shift;

	@browseMenuChoices = (
		Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_SELECT_PLAYLIST_FOR_BUTTON') . ' 0',
		Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_SELECT_PLAYLIST_FOR_BUTTON') . ' 1',
		Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_SELECT_PLAYLIST_FOR_BUTTON') . ' 2',
		Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_SELECT_PLAYLIST_FOR_BUTTON') . ' 3',
		Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_SELECT_PLAYLIST_FOR_BUTTON') . ' 4',
		Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_SELECT_PLAYLIST_FOR_BUTTON') . ' 5',
		Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_SELECT_PLAYLIST_FOR_BUTTON') . ' 6',
		Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_SELECT_PLAYLIST_FOR_BUTTON') . ' 7',
		Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_SELECT_PLAYLIST_FOR_BUTTON') . ' 8',
		Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_SELECT_PLAYLIST_FOR_BUTTON') . ' 9',
		);
	if( !defined( $menuSelection{$client})) { $menuSelection{$client} = 0; };
	$client->lines( \&lines);
}

# ----------------------------------------------------------------------------
my %functions = (
	'up' => sub {
		my $client = shift;
		my $newposition = Slim::Buttons::Common::scroll( $client, -1, ( $#browseMenuChoices + 1), $menuSelection{$client});
		$menuSelection{$client} = $newposition;
		$client->update();
	},
	'down' => sub {
	   my $client = shift;
		my $newposition = Slim::Buttons::Common::scroll( $client, +1, ( $#browseMenuChoices + 1), $menuSelection{$client});
		$menuSelection{$client} = $newposition;
		$client->update();
	},
	'left' => sub {
		my $client = shift;
		Slim::Buttons::Common::popModeRight( $client);
	},
	'right' => sub {
		my $client = shift;
		Slim::Buttons::Common::pushModeLeft( $client, 'quickaccesssetplaylist');
	},
	'play' => sub {
		my $client = shift;
	},
	'numberScroll' => sub {
		my $client = shift;
		my $button = shift;
		my $digit = shift;

		# Get playlist or player name
		my $iEntry = Slim::Utils::Prefs::clientGet( $client, "quickaccess" . $digit . "playlist");
		$debug && printf("*** Entry to start: $iEntry\n");
		# Check for player name
		if( $iEntry =~ /^\*\*\*Player\*\*\* /) {
			$iEntry =~ s/^\*\*\*Player\*\*\* //;
			my $playerName = $iEntry;
			if( defined $playerName) {
				my $sourcePlayer;

				# Get all player
				@playerItems=();
				@playerItems = Slim::Player::Client::clients();
				# Search for our player
				foreach my $cur (@playerItems) {
					if ($playerName eq $cur->name()) {
						$sourcePlayer = $cur;
						last;
					}
				}
				if( defined $sourcePlayer) {
					# Save 'prefsaveshuffle'
					my $iOldPrefSaveShuffled = Slim::Utils::Prefs::get( "saveShuffled");
					$debug && printf("*** Old save shuffle mode: $iOldPrefSaveShuffled\n");
					Slim::Utils::Prefs::set( "saveShuffled", "1");
					# Source player: Save current playlist
					Slim::Control::Command::execute( $sourcePlayer, ["playlist", "save", "__followMePlaylist"]);
					# Restore 'prefsaveshuffle'
					Slim::Utils::Prefs::set( "saveShuffled", $iOldPrefSaveShuffled);
					# Source player: Save song position
					my $iTime = Slim::Player::Source::songTime($sourcePlayer);
					$debug && printf("*** Current song time: $iTime\n");
					# Source player: Turn off
					Slim::Control::Command::execute( $sourcePlayer, ["power", "0", ]);

					# Target player: Turn on
					Slim::Control::Command::execute( $client, ["power", "1", ]);
					# Target player: Get shuffle mode
					my $iOldShuffleMode = Slim::Utils::Prefs::clientGet( $client, "shuffle");
					$debug && printf("*** Old target shuffle mode: $iOldShuffleMode\n");
					# Target player: Turn off shuffle
					Slim::Utils::Prefs::clientSet( $client, "shuffle", "0");
					# Target show message
					Slim::Display::Animation::showBriefly( $client,
										Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_MODULE_NAME'),
										Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_PLAYING_FROM') . ' ' . $playerName,
										2);
					select( undef, undef, undef, 1.0);
					# Target player: Resume saved playlist
					Slim::Control::Command::execute( $client, ["playlist", "resume", "__followMePlaylist"]);
					# Target player: Set song time
					Slim::Control::Command::execute( $client, ["time", $iTime]);
					# Target player: Set old shuffle mode
					Slim::Utils::Prefs::clientSet( $client, "shuffle", $iOldShuffleMode);
				}
				else {
					# Show error message
					Slim::Display::Animation::showBriefly( $client,
										Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_MODULE_NAME'),
										Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_PLAYLIST_NOT_AVAILABLE'),
										3);
				}
			}
		}
		# Load playlist
		elsif( defined Slim::Utils::Prefs::clientGet( $client, "quickaccess" . $digit . "playlist")) {
			Slim::Control::Command::execute( $client, ["stop"]);
			Slim::Display::Animation::showBriefly( $client,
								Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_MODULE_NAME'),
								Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_PLAYING_FROM'),
								2);
			select( undef, undef, undef, 1.0);
			Slim::Control::Command::execute( $client, ["playlist", "load", Slim::Utils::Prefs::clientGet( $client, "quickaccess" . $digit . "playlist")]);
		}
		else {
			Slim::Display::Animation::showBriefly( $client,
								Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_MODULE_NAME'),
								Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_PLAYLIST_NOT_AVAILABLE'),
								3);
		}
	},
);

# ----------------------------------------------------------------------------
sub lines {
	my $client = shift;
	my $line1 = Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_MODULE_NAME');
	my $line2 = $browseMenuChoices[$menuSelection{$client}];
	my $overlay = overlay( $client);

	return( $line1, $line2, undef, $overlay);
}

# ----------------------------------------------------------------------------
sub overlay {
	my $client = shift;

	return Slim::Hardware::VFD::symbol( 'rightarrow');
	return undef;
}

# ----------------------------------------------------------------------------
sub getFunctions {
	return \%functions;
}

# ----------------------------------------------------------------------------
sub strings {
	local $/ = undef;
	<DATA>;
}

# ----------------------------------------------------------------------------
sub getDisplayName() {
	return 'PLUGIN_QUICKACCESS_MODULE_NAME';
}

#################################################################################
#################################################################################
#################################################################################
my %quickAccessSetPlaylistFunctions = (
	'left' => sub {
		my $client = shift;
		my $button = $menuSelection{ $client};

		Slim::Utils::Prefs::clientSet( $client, "quickaccess" . $button . "playlist", $client->dirItems( $client->currentDirItem));
		@{$client->dirItems}=(); #Clear list and get outta here
		Slim::Buttons::Common::popModeRight($client);
	},
	'up' => sub {
		my $client = shift;
		my $newposition = Slim::Buttons::Common::scroll( $client, -1, $client->numberOfDirItems(), $client->currentDirItem());
		$client->currentDirItem( $newposition);
		$client->update();
	},
	'down' => sub {
		my $client = shift;
		my $newposition = Slim::Buttons::Common::scroll( $client, +1, $client->numberOfDirItems(), $client->currentDirItem());
		$client->currentDirItem( $newposition);
		$client->update();
	},
	'right' => sub { Slim::Display::Animation::bumpRight(shift); },
	'add' => sub { Slim::Display::Animation::bumpRight(shift); },
	'play' => sub { Slim::Display::Animation::bumpRight(shift); },
	'numberScroll' => sub  {
		my $client = shift;
		my $button = shift;
		my $digit = shift;
		my $i = Slim::Buttons::Common::numberScroll( $client, $digit, $client->dirItems);
		$client->currentDirItem( $i);
		$client->update();
	},
);

# ----------------------------------------------------------------------------
sub getQuickAccessSetPlaylistFunctions {
	return \%quickAccessSetPlaylistFunctions;
}

# ----------------------------------------------------------------------------
sub quickAccessSetPlaylistLines {
	my $client = shift;
	my $line1 = Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_SELECT_BUTTON_PLAYLIST');
	my $line2;

	if( defined $client->dirItems( $client->currentDirItem)) {
		if( Slim::Music::Info::isURL( $client->dirItems( $client->currentDirItem))) {
			$line2 = Slim::Music::Info::standardTitle( $client, $client->dirItems( $client->currentDirItem));
		} else {
			# Player entry
			$line2 = $client->dirItems( $client->currentDirItem);
		}
	}
	else {
		$line2 = Slim::Utils::Strings::string( 'PLUGIN_QUICKACCESS_EMPTY');
	}
	if( $client->numberOfDirItems()) {
		$line1 .= sprintf(" (%d ".string('OUT_OF')." %s)", $client->currentDirItem + 1, $client->numberOfDirItems());
	}
	return( $line1, $line2);
}

# ----------------------------------------------------------------------------
sub setQuickAccessSetPlaylist {
	my $client = shift;
	my $button = $menuSelection{$client};

	$client->lines( \&quickAccessSetPlaylistLines);
	@{$client->dirItems}=();

	# Get all playlists
	Slim::Utils::Scan::addToList( $client->dirItems, Slim::Utils::Prefs::get('playlistdir'), 0);

# iTunes fix
#	if( Slim::Music::iTunes::useiTunesLibrary()) {
#		push @{$client->dirItems}, @{Slim::Music::iTunes::playlists()};
#	}

	push @{$client->dirItems}, @{Slim::Music::Info::playlists()};

	# Get all players except ourselfs
	@playerItems=();
	@playerItems = Slim::Player::Client::clients();
	foreach my $player (@playerItems) {
		$debug && printf("*** " . $player->name() . "  " . $client->name() . "\n");
		if( $player->name() ne $client->name()) {
			push @{$client->dirItems}, "***Player*** ". $player->name();
		}
	}

	# Set last value
	$client->numberOfDirItems( scalar @{$client->dirItems});
	$client->currentDirItem( 0);
	my $list = Slim::Utils::Prefs::clientGet( $client, "quickaccess" . $button . "playlist");
	if( $list) {
		my $i = 0;
		my $items = $client->dirItems;
		foreach my $cur (@$items) {
			if ($list eq $cur) {
				$client->currentDirItem( $i);
				last;
			}
			$i++;
		}
	}
	Slim::Utils::Prefs::clientSet( $client, "quickaccess" . $button . "playlist", $client->dirItems( $client->currentDirItem));
}

# some initialization code, adding modes for this module
Slim::Buttons::Common::addMode('quickaccesssetplaylist', getQuickAccessSetPlaylistFunctions(), \&setQuickAccessSetPlaylist);

1;

__DATA__

PLUGIN_QUICKACCESS_MODULE_NAME
	EN	Quick Access
	FR	Acc?s rapide

PLUGIN_QUICKACCESS_SELECT_BUTTON_PLAYLIST
	EN	Select Button Playlist
	FR	S?lectionner playlist

PLUGIN_QUICKACCESS_SELECT_PLAYLIST_FOR_BUTTON
	EN	Select Playlist for Button
	FR	S?lectionner playlist touche

PLUGIN_QUICKACCESS_PLAYING_FROM
	EN	Playing from...
	FR	Lecture depuis...

PLUGIN_QUICKACCESS_PLAYLIST_NOT_AVAILABLE
	EN	Playlist not available
	FR	Playlist introuvable

PLUGIN_QUICKACCESS_EMPTY
	EN	empty
	FR	vide

__END__

