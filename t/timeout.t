use strict;
use warnings;
use AnyEvent::Twitter::Stream;
use AnyEvent::Util qw(guard);
use Data::Dumper;
use JSON;
use Test::More skip_all => 'broken';
use Test::TCP;
use Test::Requires qw(Plack::Builder Plack::Handler::Twiggy Try::Tiny);
use Test::Requires { 'Plack::Request' => '0.99' };

my %pattern = (
    wait_0_0_0 => 3,
    wait_5_0_0 => 0,
    wait_0_5_0 => 0,
    wait_0_0_5 => 1,
);

test_tcp(
    client => sub {
        my $port = shift;

        $AnyEvent::Twitter::Stream::STREAMING_SERVER = "localhost:$port";
        $AnyEvent::Twitter::Stream::PROTOCOL = 'http'; # real world API uses https

        foreach my $w (keys %pattern) {
            my $destroyed;
            my $received = 0;

            {
                my $done = AE::cv;
                my $streamer = AnyEvent::Twitter::Stream->new(
                    username => 'test',
                    password => 's3cr3t',
                    method => 'filter',
                    track => $w,
                    timeout => 2,
                    on_tweet => sub {
                        my $tweet = shift;
                        $done->send, return if $tweet->{count} > 2;

                        note(Dumper $tweet);
                        $received++;
                    },
                    on_error => sub {
                        my $msg = $_[2] || $_[0];
                        note("on_error: $msg");
                        $done->send;
                    }
                );
                $streamer->{_guard_for_testing} = guard { $destroyed = 1 };

                $done->recv;
            }

            is($destroyed, 1, "$w: destroyed");
            is($received, $pattern{$w}, "received");
        }
    },
    server => sub {
        my $port = shift;

        run_streaming_server($port);
    },
);

done_testing();


sub run_streaming_server {
    my $port = shift;

    my $streaming = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);

        my $track = $req->param('track');
        my (undef, $wait_a, $wait_b, $wait_c) = split(/_/, $track);

        return sub {
            my $respond = shift;

            my $count = 0;
            my $writer;

            my $send_tweet = sub {
                my ($tweet) = @_;

                try {
                    $writer->write(encode_json({count => $count++, rand => rand}) . "\x0D\x0A");
                } catch {
                    note($_);
                };
            };

            my $t1; $t1 = AE::timer $wait_a, 0, sub {
                $writer = $respond->([200, [
                    'Content-Type' => 'application/json'
                ]]);

                undef $t1;
            };

            my $t2; $t2 = AE::timer $wait_a + $wait_b, 0, sub {
                $send_tweet->();

                undef $t2;
            };

            my $t3; $t3 = AE::timer $wait_a + $wait_b + $wait_c, 0.5, sub {
                $send_tweet->();

                $t3;
            };
        };
    };


    my $app = builder {
        enable 'Auth::Basic', realm => 'Firehose', authenticator => sub {
            my ($user, $pass) = @_;

            return $user eq 'test' && $pass eq 's3cr3t';
        };
        mount '/1/' => $streaming;
    };

    my $server = Plack::Handler::Twiggy->new(
        host => '127.0.0.1',
        port => $port,
    )->run($app);
}
