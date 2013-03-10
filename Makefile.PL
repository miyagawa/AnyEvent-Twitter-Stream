use inc::Module::Install;
name 'AnyEvent-Twitter-Stream';
all_from 'lib/AnyEvent/Twitter/Stream.pm';

requires 'AnyEvent';
requires 'AnyEvent::HTTP', '2.0';
requires 'JSON', '2.0';
requires 'URI';
test_requires 'Test::TCP';
test_requires 'Test::Requires';

build_requires 'Test::More';
author_tests('xt');
auto_set_repository;
WriteAll;
