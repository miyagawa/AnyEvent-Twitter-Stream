use Test::Base;
use Test::TCP;

plan 'no_plan';

use AnyEvent::Socket;
use AnyEvent::Handle;

use AnyEvent::Twitter::Stream;

my $port = empty_port;

# mock server
my $connect_state = 'initial';
my $server = tcp_server undef, $port, sub {
    my ($fh) = @_ or die $!;

    $connect_state = 'connected';

    my $handle; $handle = AnyEvent::Handle->new(
        fh     => $fh,
        on_eof => sub {
            $connect_state = 'disconnected';
        },
        on_error => sub {
            die $_[2];
            undef $handle;
        },
        on_read => sub {
            $_[0]->push_read( line => sub {} ); # ignore input
        },
    );
};

# mock URI::query_form;
{
    require URI::_query;;
    no warnings 'redefine', 'once';
    *URI::_query::query_form = sub {
        $_[0] = URI->new("http://127.0.0.1:$port/")
    };
}

my $cv = AnyEvent->condvar;

{
    my $stream = AnyEvent::Twitter::Stream->new( method => 'firehose' );
}
# $stream destroyed here

{
    my $t; $t = AnyEvent->timer(
        after => 0.5,
        cb    => sub {
            undef $t;
            is $connect_state, 'disconnected', 'disconnected ok';
            $cv->send;
        },
    );
}

$cv->recv;
