requires 'AnyEvent';
requires 'AnyEvent::HTTP', '2.0';
requires 'JSON', '2.0';
requires 'URI';
requires 'perl', '5.008001';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.59';
    requires 'Test::More';
    requires 'Test::Requires';
    requires 'Test::TCP';
};
