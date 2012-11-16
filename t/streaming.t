use strict;
use warnings;
use AnyEvent;
use AnyEvent::Twitter::Stream;
use AnyEvent::Util qw(guard);
use Data::Dumper;
use JSON;
use Test::More;
use Test::TCP;
use Test::Requires qw(Plack::Builder Plack::Handler::Twiggy Try::Tiny);
use Test::Requires { 'Plack::Request' => '0.99' };

my @pattern = (
    {
        method => 'sample',
        mount  => 'stream',
        path   => '/1.1/statuses/sample.json',
        option => {},
    },
    {
        method => 'firehose',
        mount  => 'stream',
        path   => '/1.1/statuses/firehose.json',
        option => {},
    },
    {
        method => 'filter',
        mount  => 'stream',
        path   => '/1.1/statuses/filter.json',
        option => {track => 'hogehoge'},
    },
    {
        method => 'filter',
        path   => '/1.1/statuses/filter.json',
        option => {follow => '123123'},
    },
    {
        method => 'userstream',
        path   => '/1.1/user.json',
        option => {},
    },
);

foreach my $enable_chunked (0, 1) {
    test_tcp(
        client => sub {
            my $port = shift;

            local $AnyEvent::Twitter::Stream::STREAMING_SERVER  = "127.0.0.1:$port";
            local $AnyEvent::Twitter::Stream::USERSTREAM_SERVER = "127.0.0.1:$port";
            local $AnyEvent::Twitter::Stream::US_PROTOCOL       = "http";
            local $AnyEvent::Twitter::Stream::PROTOCOL          = 'http'; # real world API uses https

            foreach my $item (@pattern) {
                my $destroyed;
                my $received = 0;
                my $count_max = 5;
                my ($deleted, $event) = (0, 0);

                note("try $item->{method}");

                {
                    my $done = AE::cv;
                    my $streamer = AnyEvent::Twitter::Stream->new(
                        username => 'test',
                        password => 's3cr3t',
                        method => $item->{method},
                        timeout => 2,
                        on_tweet => sub {
                            my $tweet = shift;

                            if ($tweet->{hello}) {
                                note(Dumper $tweet);
                                is($tweet->{user}, 'test');
                                is($tweet->{path}, $item->{path});
                                is_deeply($tweet->{param}, $item->{option});

                                if (%{$item->{option}}) {
                                    is($tweet->{request_method}, 'POST');
                                } else {
                                    is($tweet->{request_method}, 'GET');
                                }
                            } else {
                                $done->send, return if $tweet->{count} > $count_max;
                            }

                            $received++;
                        },
                        on_delete => sub {
                            my ($tweet_id, $user_id) = @_;
                            $deleted++;
                            $received++;
                        },
                        on_friends => sub {
                            my $friends = shift;
                            is_deeply($friends, [qw/1 2 3/]);
                        },
                        on_event => sub {
                            $event++;
                            $done->send;
                        },
                        on_error => sub {
                            my $msg = $_[2] || $_[0];
                            fail("on_error: $msg");
                            $done->send;
                        },
                        %{$item->{option}},
                    );
                    $streamer->{_guard_for_testing} = guard { $destroyed = 1 };

                    $done->recv;
                }

                if ($item->{method} eq 'sample') {
                    is $deleted, 1, 'deleted one tweet';
                } else {
                    is $deleted, 0, 'deleted no tweet';
                }

                if ($item->{method} =~ /userstream|sitestream/) {
                    is $event, 1, 'got one event';
                } else {
                    is $event, 0, 'got no event';
                    is($received, $count_max + 1, "received");
                }

                is $destroyed, 1, 'destroyed';
            }
        },
        server => sub {
            my $port = shift;

            run_streaming_server($port, $enable_chunked);
        },
    );
}

done_testing();

sub run_streaming_server {
    my ($port, $enable_chunked) = @_;

    my $streaming = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);

        return sub {
            my $respond = shift;

            my $writer = $respond->([200, [
                'Content-Type' => 'application/json',
                'Server' => 'Jetty(6.1.17)',
            ]]);

            $writer->write(encode_json({
                hello => 1,
                path => $req->path,
                request_method => $req->method,
                user => $env->{REMOTE_USER},
                param => $req->parameters->mixed,
            }) . "\x0D\x0A");

            my $count = 1;
            my $t; $t = AE::timer(0, 0.2, sub {
                try {
                    $writer->write(encode_json({
                        body => 'x' x 500,
                        count => $count++,
                    }) . "\x0D\x0A");
                } catch {
                    undef $t;
                };
                if ($req->path =~ /sample/ && $count == 2) {
                    try {
                        $writer->write(encode_json({
                            delete => {status => {id => 1, user_id => 1}},
                            count => $count++,
                        }) . "\x0D\x0A");
                    } catch {
                        undef $t;
                    };
                }
            });
        };
    };

    my $user_stream = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);

        return sub {
            my $respond = shift;

            my $writer = $respond->([200, [
                'Content-Type' => 'application/json',
                'Server' => 'Jetty(6.1.17)',
            ]]);
            $writer->write(encode_json({
                friends => [qw/1 2 3/],
            }) . "\x0D\x0A");

            my $t; $t = AE::timer(0, 0.2, sub {
                try {
                    $writer->write(encode_json({
                        event => {foo => 'bar'},
                    }) . "\x0D\x0A");
                }catch{
                    undef $t;
                };
            });
        };
    };

    my $app = builder {
        enable 'Auth::Basic', realm => 'Firehose', authenticator => sub {
            my ($user, $pass) = @_;

            return $user eq 'test' && $pass eq 's3cr3t';
        };
        enable 'Chunked' if $enable_chunked;

        mount '/1.1/statuses/' => $streaming;
        mount '/'              => $user_stream;
    };

    my $server = Plack::Handler::Twiggy->new(
        host => '127.0.0.1',
        port => $port,
    )->run($app);
}
