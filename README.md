# DESCRIPTION

AnyEvent::Twitter::Stream allows an AnyEvent user to receive Twitter streaming through the API, available at [http://dev.twitter.com/pages/streaming\_api](http://dev.twitter.com/pages/streaming_api) and
[http://dev.twitter.com/pages/user\_streams](http://dev.twitter.com/pages/user_streams).

See ["track.pl" in eg](https://metacpan.org/pod/eg#track.pl) for more client code examples.


# SYNOPSIS

    use AnyEvent::Twitter::Stream;
    
    my $done = AE::cv;

    # receive updates from @following_ids
    my $listener = AnyEvent::Twitter::Stream->new(
        username => $user,
        password => $password,
        method   => "filter",  # "firehose" for everything, "sample" for sample timeline
        follow   => join(",", @following_ids), # numeric IDs
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
    
    $done->recv;
    
# METHODS

## my $streamer = AnyEvent::Twitter::Stream->new(%args);

- **username** **password**

    These arguments are used for basic authentication.

- **consumer\_key** **consumer\_secret** **token** **token\_secret**

    If you want to use the OAuth authentication mechanism, you need to set these arguments

- **method**

    The name of the method you want to use on the stream. Currently, any one of :

    - **firehose**
    - **sample**
    - **userstream**

        To use this method, you need to use the OAuth mechanism.

    - **filter**

        With this method you can specify what you want to filter amongst **track**, **follow** and **locations**.

        See [https://dev.twitter.com/docs/api/1.1/post/statuses/filter](https://dev.twitter.com/docs/api/1.1/post/statuses/filter) for the details of the parameters.

- **api\_url**

    Pass this to override the default URL for the API endpoint.

- **request\_method**

    Pass this to override the default HTTP request method.

- **timeout**

    Set the timeout value.

- **on\_connect**

    Callback to execute when a stream is connected.

- **on\_tweet**

    Callback to execute when a new tweet is received. The argument is the tweet, a hashref documented at
    [https://dev.twitter.com/docs/api/1/get/statuses/show/%3Aid](https://dev.twitter.com/docs/api/1/get/statuses/show/%3Aid).

- **on\_error**
- **on\_eof**
- **on\_keepalive**
- **on\_delete**

    Callback to execute when the stream sends a delete notification.

- **on\_friends**

    **Only with the userstream method**. Callback to execute when the stream send a list of friends.

- **on\_direct\_message**

    **Only with the userstream method**. Callback to execute when a direct message is received in the stream.

- **on\_event**

    **Only with the userstream method**. Callback to execute when the stream send an event notification (follow, ...).

- **additional agruments**

    Any additional arguments are assumed to be parameters to the underlying API method and are passed to Twitter.

# NOTES

To use the **userstream** method, Twitter recommends using the HTTPS protocol. For this, you need to set the **ANYEVENT\_TWITTER\_STREAM\_SSL** environment variable, and install the [Net::SSLeay](https://metacpan.org/pod/Net::SSLeay) module.

# AUTHOR

Tatsuhiko Miyagawa <miyagawa@bulknews.net>

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[AnyEvent::Twitter](https://metacpan.org/pod/AnyEvent::Twitter), [Net::Twitter::Stream](https://metacpan.org/pod/Net::Twitter::Stream)
