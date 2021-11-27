# PowerSave.pm by Jason Holtzapple (jasonholtzapple@yahoo.com)
# with contributions by Daniel Born
#
# PowerSave will turn off a player after a specified amount of idle
# time has elapsed. By default, idle time is defined as when a player
# is not playing and no button presses have been received within the
# specified time. The default idle time is 15 minutes.
#
# All settings are accessed in the Player Plugin menu.
#
# Some code and concepts were copied from these plugins:
#
# Rescan.pm by Andrew Hedges (andrew@hedges.me.uk)
# Timer functions added by Kevin Deane-Freeman (kevindf@shaw.ca)
#
# QuickAccess.pm by Felix Mueller <felix.mueller(at)gwendesign.com>
#
# And from the AlarmClock module by Kevin Deane-Freeman (kevindf@shaw.ca)
# Lukas Hinsch and Dean Blackketter
#
# This code is derived from code with the following copyright message:
#
# SliMP3 Server Copyright (C) 2001 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
#
#-> Changelog
#
# 6.5r2 - 30/10/2006
#    RFE: Reset idle timer on stop/non-stop transition (contributed by
#    Daniel Born)
# 6.5 - 12/9/2006
#    RFE: SlimServer v6.5 ready
# 1.0.3 - 9/3/2005
#    RFE: SlimServer v6 ready
# 1.0.2 - 9/9/2004
#    RFE: New setting to choose which playmodes will allow powersave
#    BUG: Fix 'uninitialized value' warnings
# 1.0.1 - 28/8/2004
#    BUG: Fix crashers in pre-5.3beta servers
# 1.0 - 27/8/2004 - Initial Release
#
#-> Preference Reference
#
# powersave-enabled
# 0 = disabled (default)
# 1 = enabled
#
# powersave-time
# n = number of idle seconds to PowerSave (default 900 seconds)
#
# powersave-playmode
# 0 = PowerSave on Pause or Stop (default)
# 1 = PowerSave on Stop
# 2 = PowerSave always

use strict;

package Plugins::PowerSave;

use Slim::Utils::Strings qw (string);

use vars qw($VERSION);
$VERSION = '6.5r2';

# plugin timer interval in seconds
my $interval             = 60; 
# default powersave time
my $timeDefault          = 900;
# default powersave playmode
my $playmodeDefault      = 0;

# regex to match playmode
my @powersavePlaymode = (
	'pause|stop',
	'stop',
	'.*',
);

my @browseMenuChoices = ();
my %menuSelection     = ();
my %powerSaveTimers   = ();

sub setMode {
	my $client = shift;

	@browseMenuChoices = (
		string('PLUGIN_POWERSAVE_OFF'),
		string('PLUGIN_POWERSAVE_TIMER_SET_MENU'),
		string('PLUGIN_POWERSAVE_PLAYMODE_MENU'),
	);

	unless (defined($menuSelection{$client})) {
		$menuSelection{$client} = 0;
	};

	$client->lines(\&lines);
}

sub getDisplayName() {
	return substr ($::VERSION, 0, 1) >= 6 ? 'PLUGIN_POWERSAVE' : string('PLUGIN_POWERSAVE');
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

		my @menuTimerChoices = (
			string('PLUGIN_POWERSAVE_INTERVAL_1'),
			string('PLUGIN_POWERSAVE_INTERVAL_2'),
			string('PLUGIN_POWERSAVE_INTERVAL_3'),
			string('PLUGIN_POWERSAVE_INTERVAL_4'),
			string('PLUGIN_POWERSAVE_INTERVAL_5'),
			string('PLUGIN_POWERSAVE_INTERVAL_6'),
		);

		my @menuTimerIntervals =
			map { 60 * ($_ =~ /(\d+)/)[0] } @menuTimerChoices;

		my @menuPlaymode = (
			string('PLUGIN_POWERSAVE_PLAYMODE_1'),
			string('PLUGIN_POWERSAVE_PLAYMODE_2'),
			string('PLUGIN_POWERSAVE_PLAYMODE_3'),
		);

		if ($browseMenuChoices[$menuSelection{$client}] eq string('PLUGIN_POWERSAVE_OFF')) {
			Slim::Utils::Prefs::clientSet ($client, 'powersave-enabled', 1);
			$browseMenuChoices[$menuSelection{$client}] =
				string('PLUGIN_POWERSAVE_ON');
			$client->showBriefly(string('PLUGIN_POWERSAVE_TURNING_ON'), '');
		} elsif ($browseMenuChoices[$menuSelection{$client}] eq string('PLUGIN_POWERSAVE_ON')) {
			Slim::Utils::Prefs::clientSet($client, 'powersave-enabled', 0);
			$browseMenuChoices[$menuSelection{$client}] =
				string('PLUGIN_POWERSAVE_OFF');
			$client->showBriefly(string('PLUGIN_POWERSAVE_TURNING_OFF'), '');
		} elsif ($browseMenuChoices[$menuSelection{$client}] eq string('PLUGIN_POWERSAVE_TIMER_SET_MENU')) {
			my %params = (
				'listRef' => [ @menuTimerIntervals ],
				'externRef' => [ @menuTimerChoices ],
				'header' => string('PLUGIN_POWERSAVE_TIMER_SET_MENU'),
				'valueRef' => \ (Slim::Utils::Prefs::clientGet ($client, 'powersave-time') || $timeDefault),
				'onChange' => sub { Slim::Utils::Prefs::clientSet ($_[0], 'powersave-time', $_[1])},
				'onChangeArgs' => 'CV',
			);
			Slim::Buttons::Common::pushModeLeft($client, 'INPUT.List', \%params);
		} elsif ($browseMenuChoices[$menuSelection{$client}] eq string('PLUGIN_POWERSAVE_PLAYMODE_MENU')) {
			my %params = (
				'listRef' => [ 0, 1, 2 ],
				'externRef' => [ @menuPlaymode ],
				'header' => string('PLUGIN_POWERSAVE_PLAYMODE_MENU'),
				'valueRef' => \ (Slim::Utils::Prefs::clientGet ($client, 'powersave-playmode') || $playmodeDefault),
				'onChange' => sub { Slim::Utils::Prefs::clientSet ($_[0], 'powersave-playmode', $_[1])},
				'onChangeArgs' => 'CV',
			);
			Slim::Buttons::Common::pushModeLeft($client, 'INPUT.List', \%params);
		}
	}
);

sub getFunctions() {
	return \%functions;
}

sub lines {
	my $client = shift;

	my ($line1, $line2);

	$line1 = string('PLUGIN_POWERSAVE');

	if (Slim::Utils::Prefs::clientGet($client, 'powersave-enabled') &&
		$browseMenuChoices[$menuSelection{$client}] eq string('PLUGIN_POWERSAVE_OFF')) {
		$browseMenuChoices[$menuSelection{$client}] =
			string('PLUGIN_POWERSAVE_ON');
	}
	$line2 = '';

	$line2 = $browseMenuChoices[$menuSelection{$client}];
	return ($line1, $line2, undef, Slim::Display::Display::symbol('rightarrow'));
}

sub checkPlaymode {
	my $client = shift;

	my $setting = Slim::Utils::Prefs::clientGet ($client, 'powersave-playmode') || $playmodeDefault;
	if ($setting < 0 or $setting > 2) { $setting = $playmodeDefault }
	my $mode    = Slim::Player::Source::playmode ($client);

	if ($mode =~ /^$powersavePlaymode[$setting]$/) {
		return 1;
	} else {
		return 0;
	}
}

sub checkPowerSaveTimer {

	foreach my $client (Slim::Player::Client::clients()) {

		unless (exists $powerSaveTimers{$client}) {
			$powerSaveTimers{$client}{time} = time;
			$powerSaveTimers{$client}{modechgtime} = 0;
			$powerSaveTimers{$client}{lastirtime} = int ($client->lastirtime);
			$powerSaveTimers{$client}{psactivated} = 0;
		}

		if ((Slim::Buttons::Common::mode ($client) ne 'off')
			and (Slim::Utils::Prefs::clientGet ($client, 'powersave-enabled'))) {
			if (checkPlaymode ($client)) {
				my $time = Slim::Utils::Prefs::clientGet ($client, 'powersave-time') || $timeDefault;
				# reset timer after wakeup
				if ($powerSaveTimers{$client}{psactivated} == 1) {
					$powerSaveTimers{$client}{time} = time;
					$powerSaveTimers{$client}{psactivated} = 0;
				} elsif ($powerSaveTimers{$client}{lastirtime} != int ($client->lastirtime)) {
					$powerSaveTimers{$client}{lastirtime} = int ($client->lastirtime);
					$powerSaveTimers{$client}{time} = time;
				} elsif ($powerSaveTimers{$client}{modechgtime} == 0) {
					$powerSaveTimers{$client}{modechgtime} = time;
				} elsif ((int(time - $powerSaveTimers{$client}{time}) >= $time)
					and (int(time - $powerSaveTimers{$client}{modechgtime}) >= $time)) {
					$powerSaveTimers{$client}{psactivated} = 1;
					Slim::Control::Command::execute ($client, ['power', 0]);
				}
			}
		}
	}
	setTimer ();
}

sub setTimer {
	Slim::Utils::Timers::setTimer (0, time + $interval, \&checkPowerSaveTimer);
}

sub strings
{
    local $/ = undef;
    <DATA>;
}

setTimer ();

1;

__DATA__

PLUGIN_POWERSAVE
	EN	PowerSave
	
PLUGIN_POWERSAVE_TIMER_SET_MENU
	EN	Set PowerSave Idle Time

PLUGIN_POWERSAVE_TURNING_OFF
	EN	Turning PowerSave OFF

PLUGIN_POWERSAVE_TURNING_ON
	EN	Turning PowerSave ON

PLUGIN_POWERSAVE_OFF
	EN	PowerSave OFF

PLUGIN_POWERSAVE_ON
	EN	PowerSave ON

PLUGIN_POWERSAVE_PLAYMODE_MENU
	EN	Set PowerSave Activation

PLUGIN_POWERSAVE_PLAYMODE_1
	EN	PowerSave on Pause or Stop

PLUGIN_POWERSAVE_PLAYMODE_2
	EN	PowerSave on Stop

PLUGIN_POWERSAVE_PLAYMODE_3
	EN	PowerSave Always

PLUGIN_POWERSAVE_DESC
	EN	Turns your player off after a set period of inactivity. Turn PowerSave ON and set the idle time to enable this feature.

PLUGIN_POWERSAVE_INTERVAL_1
	EN	15 minutes

PLUGIN_POWERSAVE_INTERVAL_2
	EN	30 minutes

PLUGIN_POWERSAVE_INTERVAL_3
	EN	45 minutes

PLUGIN_POWERSAVE_INTERVAL_4
	EN	60 minutes

PLUGIN_POWERSAVE_INTERVAL_5
	EN	90 minutes

PLUGIN_POWERSAVE_INTERVAL_6
	EN	120 minutes
