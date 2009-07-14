#!/usr/bin/perl
use strict;
use AnyEvent::Twitter::Stream;

my $done = AnyEvent->condvar;

my($user, $password, $method, $args) = @ARGV;

my %args;
if ($method eq 'follow') {
    $args{follow} = $args;
} elsif ($method eq 'track') {
    $args{track}  = $args;
}

binmode STDOUT, ":utf8";

my $streamer = AnyEvent::Twitter::Stream->new(
    username => $user,
    password => $password,
    method   => $method || "spritzer",
    %args,
    on_tweet => sub {
        my $tweet = shift;
        print "$tweet->{user}{screen_name}: $tweet->{text}\n";
    },
    on_error => sub {
        my $error = shift;
        warn "ERROR: $error";
        $done->send;
    },
    on_eof   => sub {
        $done->send;
    },
);

$done->recv;
