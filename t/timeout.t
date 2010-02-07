use strict;
use warnings;
use AnyEvent::Twitter::Stream;
use AnyEvent::Util qw(guard);
use Data::Dumper;
use JSON;
use Test::More;
use Test::TCP;
use Test::Requires qw(AnyEvent::HTTPD);

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

        foreach my $w (keys %pattern) {
            my $destroyed;
            my $received = 0;

            {
                my $done = AE::cv;
                my $streamer = AnyEvent::Twitter::Stream->new(
                    username => 'u',
                    password => 'p',
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

        my $httpd = get_mock_httpd($port);
        $httpd->run;
    },
);

done_testing();


sub get_mock_httpd {
    my $port = shift;
    my $httpd = AnyEvent::HTTPD->new(port => $port);

    $httpd->reg_cb(
        '/1/statuses/filter.json' => sub {
            my ($httpd, $req) = @_;

            my $track = $req->parm('track');
            my (undef, $wait_a, $wait_b, $wait_c) = split(/_/, $track);

            my $t; $t = AE::timer $wait_a, 0, sub {
                my $count = 0;
                $req->respond([200, 'OK', {'Content-Type' => 'application/json'}, sub {
                    my $data_cb = shift;
                    return unless $data_cb;

                    my $after;

                    if ($count == 0) {
                        $after = $wait_b;
                    } elsif ($count == 1) {
                        $after = $wait_c;
                    } else {
                        $after = 1;
                    }

                    send_delayed_tweet($data_cb, $after, {count => $count++, rand => rand});
                }]);

                undef $t;
            };

            $httpd->stop_request;
        },

        request => sub {
            my ($httpd, $req) = @_;
            my $u = $req->url->clone;
            $u->query_form($req->vars);
            note("request: $u");
        },
    );

    return $httpd;
}
sub send_delayed_tweet {
    my ($data_cb, $after, $tweet) = @_;

    my $t; $t = AE::timer $after, 0, sub {
        $data_cb->(encode_json($tweet) . "\r\n");
        undef $t;
    };
}
