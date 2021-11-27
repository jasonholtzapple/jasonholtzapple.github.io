# DirectPlay.pm by Jason Holtzapple (jasonholtzapple@yahoo.com)
#
# DirectPlay will allow direct playback and addition to the playlist
# of album, track and artist database IDs.
#
# All functions are accessed in the Player Plugin menu.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
#
#-> Changelog
#
# 1.0 - 26/1/2006 - First Release (no changes from v0.2 ALPHA)

use strict;

package Plugins::DirectPlay;

use Slim::Utils::Strings qw (string);

use vars qw($VERSION);
$VERSION = '1.0';

my @browseMenuChoices = ();
my %menuSelection     = ();
my %context           = ();
my %idType            = ();

my $rightarrow = Slim::Display::Display::symbol('rightarrow');

my @validChars = (
	Slim::Display::Display::symbol('rightarrow'),
	'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
);

my @numbersOnly = (
	['0'], ['1'], ['2'], ['3'], ['4'], ['5'], ['6'], ['7'], ['8'], ['9'],
);

sub setMode {
	my $client = shift;

	@browseMenuChoices = (
		string('PLUGIN_DIRECTPLAY_ALBUM'),
		string('PLUGIN_DIRECTPLAY_TRACK'),
		string('PLUGIN_DIRECTPLAY_ARTIST'),
	);

	unless (defined($menuSelection{$client})) {
		$menuSelection{$client} = 0;
	};

	$client->lines(\&lines);
}

sub getDisplayName() {
	return 'PLUGIN_DIRECTPLAY';
}

sub enabled {
	return ($::VERSION ge '6.2');
}

my %functions = (

	'up' => sub  {
		my $client = shift;

		my $newposition = Slim::Buttons::Common::scroll
			($client, -1, ($#browseMenuChoices + 1),
			$menuSelection{$client});
		$menuSelection{$client} = $newposition;
		$client->update();
	},
	'down' => sub  {
		my $client = shift;

		my $newposition = Slim::Buttons::Common::scroll
			($client, +1, ($#browseMenuChoices + 1),
			$menuSelection{$client});
		$menuSelection{$client} = $newposition;
		$client->update();
	},
	'left' => sub  {
		my $client = shift;
		Slim::Buttons::Common::popModeRight($client);
	},
	'right' => sub  {
		my $client = shift;

		if ($browseMenuChoices[$menuSelection{$client}] eq string('PLUGIN_DIRECTPLAY_ALBUM')) {
			$idType{$client} = 'album';
			my %params = (
				'header' => string('PLUGIN_DIRECTPLAY_ALBUM'),
				'charsRef' => \@validChars,
				'numberLetterRef' => \@numbersOnly,
				'valueRef' => \$context{$client},
				'cursorPos' => 0,
				'callback' => \&Plugins::DirectPlay::callback,
			);
			Slim::Buttons::Common::pushModeLeft($client, 'INPUT.Text', \%params);
		} elsif ($browseMenuChoices[$menuSelection{$client}] eq string('PLUGIN_DIRECTPLAY_TRACK')) {
			$idType{$client} = 'track';
			my %params = (
				'header' => string('PLUGIN_DIRECTPLAY_TRACK'),
				'charsRef' => \@validChars,
				'numberLetterRef' => \@numbersOnly,
				'valueRef' => \$context{$client},
				'cursorPos' => 0,
				'callback' => \&Plugins::DirectPlay::callback,
			);
			Slim::Buttons::Common::pushModeLeft($client, 'INPUT.Text', \%params);
		} elsif ($browseMenuChoices[$menuSelection{$client}] eq string('PLUGIN_DIRECTPLAY_ARTIST')) {
			$idType{$client} = 'artist';
			my %params = (
				'header' => string('PLUGIN_DIRECTPLAY_ARTIST'),
				'charsRef' => \@validChars,
				'numberLetterRef' => \@numbersOnly,
				'valueRef' => \$context{$client},
				'cursorPos' => 0,
				'callback' => \&Plugins::DirectPlay::callback,
			);
			Slim::Buttons::Common::pushModeLeft($client, 'INPUT.Text', \%params);
		}
	},
);

sub callback {
	my ($client,$type) = @_;
	my @pargs          = ();

	if ($type eq 'backspace') {
		Slim::Buttons::Common::popModeRight($client);
	} elsif ($type eq 'play') {
		$context{$client} =~ s/$rightarrow//;
		if ($idType{$client} eq 'album') {
			@pargs = ('playlistcontrol', 'cmd:load', "album_id:$context{$client}");
			$client->showBriefly(string('PLUGIN_DIRECTPLAY_ALBUM_PLAY', ''));
		} elsif ($idType{$client} eq 'track') {
			@pargs = ('playlistcontrol', 'cmd:load', "track_id:$context{$client}");
			$client->showBriefly(string('PLUGIN_DIRECTPLAY_TRACK_PLAY', ''));
		} elsif ($idType{$client} eq 'artist') {
			@pargs = ('playlistcontrol', 'cmd:load', "artist_id:$context{$client}");
			$client->showBriefly(string('PLUGIN_DIRECTPLAY_ARTIST_PLAY', ''));
		}
		$client->execute(\@pargs);
		$context{$client} = '';
		Slim::Buttons::Common::popModeRight($client);

	} elsif ($type eq 'add') {
		$context{$client} =~ s/$rightarrow//;
		if ($idType{$client} eq 'album') {
			@pargs = ('playlistcontrol', 'cmd:add', "album_id:$context{$client}");
			$client->showBriefly(string('PLUGIN_DIRECTPLAY_ALBUM_ADD', ''));
		} elsif ($idType{$client} eq 'track') {
			@pargs = ('playlistcontrol', 'cmd:add', "track_id:$context{$client}");
			$client->showBriefly(string('PLUGIN_DIRECTPLAY_TRACK_ADD', ''));
		} elsif ($idType{$client} eq 'artist') {
			@pargs = ('playlistcontrol', 'cmd:add', "artist_id:$context{$client}");
			$client->showBriefly(string('PLUGIN_DIRECTPLAY_ARTIST_ADD', ''));
		}
		$client->execute(\@pargs);
		$context{$client} = '';
		Slim::Buttons::Common::popModeRight($client);
	} else {
		$context{$client} =~ s/$rightarrow//;
		$client->bumpLeft();
	};
}

sub getFunctions() {
	return \%functions;
}

sub lines {
	my $client = shift;

	my ($line1, $line2);

	$line1 = string('PLUGIN_DIRECTPLAY');
	$line2 = $browseMenuChoices[$menuSelection{$client}];
	return ($line1, $line2, undef, Slim::Hardware::VFD::symbol('rightarrow'));
}

sub strings
{
    local $/ = undef;
    <DATA>;
}

1;

__DATA__
PLUGIN_DIRECTPLAY
	EN	DirectPlay

PLUGIN_DIRECTPLAY_ALBUM
	EN	Play Album

PLUGIN_DIRECTPLAY_TRACK
	EN	Play Track

PLUGIN_DIRECTPLAY_ARTIST
	EN	Play Artist

PLUGIN_DIRECTPLAY_ALBUM_PLAY
	EN	Playing Album ...

PLUGIN_DIRECTPLAY_ALBUM_ADD
	EN	Adding Album ...

PLUGIN_DIRECTPLAY_TRACK_PLAY
	EN	Playing Track ...

PLUGIN_DIRECTPLAY_TRACK_ADD
	EN	Adding Track ...

PLUGIN_DIRECTPLAY_ARTIST_PLAY
	EN	Playing Artist ...

PLUGIN_DIRECTPLAY_ARTIST_ADD
	EN	Adding Artist ...
	
PLUGIN_DIRECTPLAY_DESC
	EN	Enables playback of albums, tracks and artists directly by database ID number
