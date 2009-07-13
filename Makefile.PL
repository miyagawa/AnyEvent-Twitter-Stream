use inc::Module::Install;
name 'AnyEvent-Twitter-Stream';
all_from 'lib/AnyEvent/Twitter/Stream.pm';

requires 'AnyEvent';
requires 'AnyEvent::HTTP';
requires 'JSON', '2.0';
requires 'URI';

build_requires 'Test::More';
use_test_base;
auto_include_deps;
author_tests('xt');
auto_set_repository;
WriteAll;
