package AnyEvent::Twitter::Stream;

use strict;
use 5.008_001;
our $VERSION = '0.07';

use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Util;
use JSON;
use MIME::Base64;
use URI;
use List::Util qw(first);
use URI::Escape;
use Carp;

my %methods = (
    firehose => [],
    sample   => [],
    filter   => [ qw(track follow) ]
);

sub new {
    my $class = shift;
    my %args  = @_;

    my $username = delete $args{username};
    my $password = delete $args{password};
    my $method   = delete $args{method};
    my $on_tweet = delete $args{on_tweet};
    my $on_error = delete $args{on_error} || sub { die @_ };
    my $on_eof   = delete $args{on_eof}   || sub {};

    unless ($methods{$method}) {
        return $on_error->("Method $method not available.");
    }

    my($param_name, $param_value);
    for my $param ( @{$methods{$method}}) {
        if (defined $args{$param}) {
            $param_name = $param;
            $param_value = delete $args{$param};
            last;
        }
    }

    my $auth = MIME::Base64::encode("$username:$password", '');

    my $uri = URI->new("http://stream.twitter.com/1/statuses/$method.json");
    $uri->query_form(%args);

    my $self = bless {}, $class;

    my @initial_args = ($uri);
    my $sender = \&http_get;
    if ($method eq 'filter') {
        $sender = \&http_post;
        push @initial_args, "$param_name=" . URI::Escape::uri_escape($param_value);
    }

    $self->{connection_guard} = $sender->(@initial_args,
        headers => {
            Authorization => "Basic $auth",
            'Content-Type' =>  'application/x-www-form-urlencoded',
            Accept => '*/*'
        },
        on_header => sub {
            my($headers) = @_;
            if ($headers->{Status} ne '200') {
                return $on_error->("$headers->{Status}: $headers->{Reason}");
            }
            return 1;
        },
        want_body_handle => 1, # for some reason on_body => sub {} doesn't work :/
        sub {
            my ($handle, $headers) = @_;
            Scalar::Util::weaken($self);

            if ($handle) {
                $handle->on_eof(sub {
                    undef $handle;
                    $on_eof->(@_);
                });
                my $reader; $reader = sub {
                    my($handle, $json) = @_;
                    # Twitter stream returns "\x0a\x0d\x0a" if there's no matched tweets in ~30s.
                    if ($json) {
                        my $tweet = JSON::decode_json($json);
                        $on_tweet->($tweet);
                    }
                    $handle->push_read(line => $reader);
                };
                $handle->push_read(line => $reader);
                $self->{guard} = AnyEvent::Util::guard { $on_eof->(); $handle->destroy; undef $reader  };
            }
        });

    return $self;
}

1;
__END__

=encoding utf-8

=for stopwords
API AnyEvent

=for test_synopsis
my($user, $password, @following_ids);

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
  );

  # track keywords
  my $guard = AnyEvent::Twitter::Stream->new(
      username => $user,
      password => $password,
      method   => "filter",
      track    => "Perl,Test,Music",
      on_tweet => sub { },
  );

=head1 DESCRIPTION

AnyEvent::Twitter::Stream is an AnyEvent user to receive Twitter streaming
API, available at L<http://apiwiki.twitter.com/Streaming-API-Documentation>

See L<eg/track.pl> for more client code example.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<AnyEvent::Twitter>, L<Net::Twitter::Stream>

=cut
