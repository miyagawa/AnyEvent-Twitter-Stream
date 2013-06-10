requires 'AnyEvent';
requires 'AnyEvent::HTTP', '2.0';
requires 'JSON', '2.0';
requires 'URI';
requires 'perl', '5.008001';

on test => sub {
    requires 'Test::More';
    requires 'Test::Requires';
    requires 'Test::TCP';
};
