#!perl

use DBIx::Class::Fixtures;
use Test::More tests => 4;
use lib qw(t/lib);
use DBICTest;
use Path::Class;
use Data::Dumper; 

# set up and populate schema
ok(my $schema = DBICTest->init_schema(), 'got schema');

my $config_dir = 't/var/configs';

{
    # do dump
    ok(my $fixtures = DBIx::Class::Fixtures->new({ config_dir => $config_dir, debug => 0 }), 'object created with correct config dir');
    ok($fixtures->dump({ config => 'mixed-case.json', schema => $schema, directory => 't/var/fixtures' }), 'simple dump executed okay');

    # check dump is okay
    my $dir = dir('t/var/fixtures/MixedCase');
    ok(-e 't/var/fixtures/MixedCase', 'MixedCase directory created');
}
