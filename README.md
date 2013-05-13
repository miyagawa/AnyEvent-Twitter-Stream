# NAME

AnyEvent::Twitter::Stream - Receive Twitter streaming API in an event loop

# SYNOPSIS

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

# DESCRIPTION

AnyEvent::Twitter::Stream is an AnyEvent user to receive Twitter streaming
API, available at [http://dev.twitter.com/pages/streaming\_api](http://dev.twitter.com/pages/streaming\_api) and
[http://dev.twitter.com/pages/user\_streams](http://dev.twitter.com/pages/user\_streams).

See ["track.pl" in eg](http://search.cpan.org/perldoc?eg#track.pl) for more client code example.

# METHODS

## my $streamer = AnyEvent::Twitter::Stream->new(%args);

- __username__ __password__

    These arguments are used for basic authentication.

- __consumer\_key__ __consumer\_secret__ __token__ __token\_secret__

    If you want to use the OAuth authentication mechanism, you need to set use arguments

- __consumer\_key__ __consumer\_secret__ __token__ __token\_secret__

    If you want to use the OAuth authentication mechanism, you need to set these arguments

- __method__

    The name of the method you want to use on the stream. Currently, anyone of :

    - __firehose__
    - __sample__
    - __userstream__

        To use this method, you need to use the OAuth mechanism.

    - __filter__

        With this method you can specify what you want to filter amongst __track__, __follow__ and __locations__.

- __api\_url__

    Pass this to override the default URL for the API endpoint.

- __request\_method__

    Pass this to override the default HTTP request method.

- __timeout__

    Set the timeout value.

- __on\_connect__

    Callback to execute when a stream is connected.

- __on\_tweet__

    Callback to execute when a new tweet is received.

- __on\_error__
- __on\_eof__
- __on\_keepalive__
- __on\_delete__

    Callback to execute when the stream send a delete notification.

- __on\_friends__

    __Only with the usertream method__. Callback to execute when the stream send a list of friends.

- __on\_direct\_message__

    __Only with the usertream method__. Callback to execute when a direct message is received in the stream.

- __on\_event__

    __Only with the userstream method__. Callback to execute when the stream send an event notification (follow, ...).

- __additional agruments__

    Any additional arguments are assumed to be parameters to the underlying API method and are passed to Twitter.

# NOTES

To use the __userstream__ method, Twitter recommend using the HTTPS protocol. For this, you need to set the __ANYEVENT\_TWITTER\_STREAM\_SSL__ environment variable, and install the [Net::SSLeay](http://search.cpan.org/perldoc?Net::SSLeay) module.

# AUTHOR

Tatsuhiko Miyagawa <miyagawa@bulknews.net>

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[AnyEvent::Twitter](http://search.cpan.org/perldoc?AnyEvent::Twitter), [Net::Twitter::Stream](http://search.cpan.org/perldoc?Net::Twitter::Stream)
