#!/usr/bin/perl

use strict;
use IO::Socket;

my $server = '127.0.0.1';
my $port = '9090';
my $player;
my @commands;

die unless defined ($player = <STDIN>);
chomp $player;
@commands = <STDIN>;
chomp @commands;

my $response;
my $socket = IO::Socket::INET->new(PeerAddr => $server,
                                   PeerPort => $port,
				   Proto    => 'tcp',
				   Type     => SOCK_STREAM)
or die "Couldn't connect to $server port $port: $@\n";
$socket->autoflush (1);

for (@commands) {
	print $socket "$player $_\n";
	$response = <$socket>;
}
print $socket "exit\n";
$response = <$socket>;
close $socket;
