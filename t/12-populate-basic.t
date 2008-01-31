#!perl

use DBIx::Class::Fixtures;
use Test::More tests => 6;
use lib qw(t/lib);
use DBICTest;
use Path::Class;
use Data::Dumper; 

# set up and populate schema
ok(my $schema = DBICTest->init_schema(), 'got schema');

my $config_dir = 't/var/configs';

# do dump
ok(my $fixtures = DBIx::Class::Fixtures->new({ config_dir => $config_dir, debug => 0 }), 'object created with correct config dir');
ok($fixtures->dump({ config => 'simple.json', schema => $schema, directory => 't/var/fixtures' }), 'simple dump executed okay');

$fixtures->populate({ ddl => 't/lib/sqlite.sql', connection_details => ['dbi:SQLite:t/var/DBIxClass.db', '', ''], directory => 't/var/fixtures' });
is($schema->resultset('Artist')->count, 1, 'correct number of artists');
is($schema->resultset('CD')->count, 0, 'correct number of cds');
is($schema->resultset('Track')->count, 0, 'correct number of tracks');
