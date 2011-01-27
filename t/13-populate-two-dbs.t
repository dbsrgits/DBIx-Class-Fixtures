#!perl

use DBIx::Class::Fixtures;
use Test::More tests => 7;
use lib qw(t/lib);
use DBICTest;
use Path::Class;
use Data::Dumper;
use DBICTest::Schema2;

# set up and populate normal schema
ok(my $schema = DBICTest->init_schema(), 'got schema');
my $config_dir = 't/var/configs';

my @different_connection_details = (
    'dbi:SQLite:t/var/DBIxClassDifferent.db', 
    '', 
    ''
)
;
my $schema2 = DBICTest::Schema2->compose_namespace('DBICTest2')
                               ->connect(@different_connection_details);

ok $schema2;

unlink('t/var/DBIxClassDifferent.db') if (-e 't/var/DBIxClassDifferent.db');

DBICTest->deploy_schema($schema2, 't/lib/sqlite_different.sql');

# do dump
ok(my $fixtures = DBIx::Class::Fixtures->new({ 
      config_dir => $config_dir, 
      debug => 0
   }), 
   'object created with correct config dir');

ok($fixtures->dump({ 
      config => "simple.json", 
      schema => $schema, 
      directory => 't/var/fixtures' 
    }), 
    "simple dump executed okay");

ok($fixtures->populate({ 
      ddl => 't/lib/sqlite_different.sql', 
      connection_details => [@different_connection_details], 
      directory => 't/var/fixtures'
    }),
    'mysql populate okay');

ok($fixtures->populate({ 
      ddl => 't/lib/sqlite.sql', 
      connection_details => ['dbi:SQLite:t/var/DBIxClass.db', '', ''],
      directory => 't/var/fixtures'
    }), 
    'sqlite populate okay');

$schema = DBICTest->init_schema(no_deploy => 1);
is($schema->resultset('Artist')->count, 1, 'artist imported to sqlite okay');
