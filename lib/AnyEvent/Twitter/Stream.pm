package AnyEvent::Twitter::Stream;

use strict;
use 5.008_001;
our $VERSION = '0.16';

use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Util;
use MIME::Base64;
use URI;
use URI::Escape;
use Carp;

our $STREAMING_SERVER  = 'stream.twitter.com';
our $USERSTREAM_SERVER = 'chirpstream.twitter.com';
our $PROTOCOL          = $ENV{'ANYEVENT_TWITTER_STREAM_SSL'} ? 'https' : 'http';

my %methods = (
    firehose   => [],
    links      => [],
    retweet    => [],
    sample     => [],
    userstream => [ qw(replies) ],
    filter     => [ qw(track follow locations) ],
);

sub new {
    my $class = shift;
    my %args  = @_;

    my $username        = delete $args{username};
    my $password        = delete $args{password};
    my $consumer_key    = delete $args{consumer_key};
    my $consumer_secret = delete $args{consumer_secret};
    my $token           = delete $args{token};
    my $token_secret    = delete $args{token_secret};
    my $method          = delete $args{method};
    my $on_tweet        = delete $args{on_tweet};
    my $on_error        = delete $args{on_error} || sub { die @_ };
    my $on_eof          = delete $args{on_eof} || sub { };
    my $on_keepalive    = delete $args{on_keepalive} || sub { };
    my $on_delete       = delete $args{on_delete};
    my $on_friends      = delete $args{on_friends};
    my $on_event        = delete $args{on_event};
    my $timeout         = delete $args{timeout};

    my $decode_json;
    unless (delete $args{no_decode_json}) {
        require JSON;
        $decode_json = 1;
    }

    unless ($methods{$method}) {
        $on_error->("Method $method not available.");
        return;
    }

    my %post_args;
    for my $param ( @{ $methods{$method} } ) {
        next if $method eq 'userstream' && $param eq 'replies';
        if ( exists $args{$param} ) {
            $post_args{$param} = delete $args{$param};
        }
    }

    my $uri;
    if ($method eq 'userstream') {
        $uri = URI->new("$PROTOCOL://$USERSTREAM_SERVER/2b/user.json");
    }else{
        $uri = URI->new("$PROTOCOL://$STREAMING_SERVER/1/statuses/$method.json");
    }

    $uri->query_form(%args);

    my $request_method = 'GET';
    my $request_body;
    if ($method eq 'filter' || $method eq 'userstream') {
        $request_method = 'POST';
        $request_body = join '&', map "$_=" . URI::Escape::uri_escape($post_args{$_}), keys %post_args;
    }

    my $auth;
    if ($consumer_key) {
        eval {require Net::OAuth;};
        die $@ if $@;

        my $request = Net::OAuth->request('protected resource')->new(
            version          => '1.0',
            consumer_key     => $consumer_key,
            consumer_secret  => $consumer_secret,
            token            => $token,
            token_secret     => $token_secret,
            request_method   => $request_method,
            signature_method => 'HMAC-SHA1',
            timestamp        => time,
            nonce            => MIME::Base64::encode( time . $$ . rand ),
            request_url      => $uri,
            extra_params     => \%post_args,
        );
        $request->sign;
        $auth = $request->to_authorization_header;
    }else{
        $auth = "Basic ".MIME::Base64::encode("$username:$password", '');
    }

    my $self = bless {}, $class;

    {
        Scalar::Util::weaken(my $self = $self);

        my $set_timeout = $timeout
            ? sub { $self->{timeout} = AE::timer($timeout, 0, sub { $on_error->('timeout') }) }
            : sub {};

        $set_timeout->();

        $self->{connection_guard} = http_request($request_method, $uri,
            headers => {
                Accept => '*/*',
                Authorization => $auth,
                ($request_method eq 'POST'
                    ? ('Content-Type' => 'application/x-www-form-urlencoded')
                    : ()
                ),
            },
            body => $request_body,
            on_header => sub {
                my($headers) = @_;
                if ($headers->{Status} ne '200') {
                    $on_error->("$headers->{Status}: $headers->{Reason}");
                    return;
                }
                return 1;
            },
            want_body_handle => 1, # for some reason on_body => sub {} doesn't work :/
            sub {
                my ($handle, $headers) = @_;

                if ($handle) {
                    $handle->on_error(sub {
                        undef $handle;
                        $on_error->($_[2]);
                    });
                    $handle->on_eof(sub {
                        undef $handle;
                        $on_eof->(@_);
                    });
                    my $reader; $reader = sub {
                        my($handle, $json) = @_;
                        # Twitter stream returns "\x0a\x0d\x0a" if there's no matched tweets in ~30s.
                        $set_timeout->();
                        if ($json) {
                            my $tweet = $decode_json ? JSON::decode_json($json) : $json;
                            if ($on_delete && $tweet->{delete} && $tweet->{delete}->{status}) {
                                $on_delete->($tweet->{delete}->{status}->{id}, $tweet->{delete}->{status}->{user_id});
                            }elsif($on_friends && $tweet->{friends}) {
                                $on_friends->($tweet->{friends});
                            }elsif($on_event && $tweet->{event}) {
                                $on_event->($tweet);
                            }else{
                                $on_tweet->($tweet);
                            }
                        }
                        else {
                            $on_keepalive->();
                        }
                        $handle->push_read(line => $reader);
                    };
                    $handle->push_read(line => $reader);
                    $self->{guard} = AnyEvent::Util::guard { $on_eof->(); $handle->destroy if $handle; undef $reader };
                }
            }
        );
    }

    return $self;
}

1;
__END__

=encoding utf-8

=for stopwords
API AnyEvent

=for test_synopsis
my($user, $password, @following_ids, $consumer_key, $consumer_secret, $token, $token_secret);

=head1 NAME

AnyEvent::Twitter::Stream - Receive Twitter streaming API in an event loop

=head1 SYNOPSIS

  use AnyEvent::Twitter::Stream;

  # receive updates from @following_ids
  my $listener = AnyEvent::Twitter::Stream->new(
      username => $user,
      password => $password,
      method   => "filter",  # "firehose" for everything, "sample" for sample timeline
      follow   => join(",", @following_ids),
      on_tweet => sub {
          my $tweet = shift;
          warn "$tweet->{user}{screen_name}: $tweet->{text}\n";
      },
      on_keepalive => sub {
          warn "ping\n";
      },
      on_delete => sub {
          my ($tweet_id, $user_id) = @_; # callback executed when twitter send a delete notification
          ...
      },
      timeout => 45,
  );

  # track keywords
  my $guard = AnyEvent::Twitter::Stream->new(
      username => $user,
      password => $password,
      method   => "filter",
      track    => "Perl,Test,Music",
      on_tweet => sub { },
  );

  # to use OAuth authentication
  my $listener = AnyEvent::Twitter::Stream->new(
      consumer_key    => $consumer_key,
      consumer_secret => $consumer_secret,
      token           => $token,
      token_secret    => $token_secret,
      method          => "filter",
      track           => "...",
      on_tweet        => sub { ... },
  );

=head1 DESCRIPTION

AnyEvent::Twitter::Stream is an AnyEvent user to receive Twitter streaming
API, available at L<http://dev.twitter.com/pages/streaming_api> and
L<http://dev.twitter.com/pages/user_streams>.

See L<eg/track.pl> for more client code example.

=head1 METHODS

=head2 my $streamer = AnyEvent::Twitter::Stream->new(%args);

=over 4

=item B<username> B<password>

These arguments are used for basic authentication.

=item B<consumer_key> B<consumer_secret> B<token> B<token_secret>

If you want to use the OAuth authentication mechanism, you need to set use arguments

=item B<method>

The name of the method you want to use on the stream. Currently, anyone of :

=item B<consumer_key> B<consumer_secret> B<token> B<token_secret>

If you want to use the OAuth authentication mechanism, you need to set these arguments

=item B<method>

The name of the method you want to use on the stream. Currently, anyone of :

=over 2

=item B<firehose>

=item B<links>

=item B<retweet>

=item B<sample>

=item B<userstream>

To use this method, you need to use the OAuth mechanism.

=item B<filter>

With this method you can specify what you want to filter amongst B<track>, B<follow> and B<locations>.

=back

=item B<timeout>

Set the timeout value.

=item B<on_tweet>

Callback to execute when a new tweet is received.

=item B<on_error>

=item B<on_eof>

=item B<on_keepalive>

=item B<on_delete>

Callback to execute when the stream send a delete notification.

=item B<on_friends>

B<Only with the usertream method>. Callback to execute when the stream send a list of friends.

=item B<on_event>

B<Only with the userstream method>. Callback to execute when the stream send an event notification (follow, ...).

=head1 NOTES

To use the B<userstream> method, Twitter recommend using the HTTPS protocol. For this, you need to set the B<ANYEVENT_TWITTER_STREAM_SSL> environment variable, and install the L<Net::SSLeay> module.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<AnyEvent::Twitter>, L<Net::Twitter::Stream>

=cut
