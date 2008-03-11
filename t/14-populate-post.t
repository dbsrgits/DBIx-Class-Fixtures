#!perl

use DBIx::Class::Fixtures;
use Test::More tests => 5;
use lib qw(t/lib);
use DBICTest;
use Path::Class;
use Data::Dumper;

# set up and populate schema
ok(my $schema = DBICTest->init_schema(), 'got schema');
my $config_dir = 't/var/configs';

# do dump
ok(my $fixtures = DBIx::Class::Fixtures->new({ config_dir => $config_dir, debug => 0 }), 'object created with correct config dir');

no warnings 'redefine';
DBICTest->clear_schema($schema);
DBICTest->populate_schema($schema);
ok($fixtures->dump({ config => "simple.json", schema => $schema, directory => 't/var/fixtures' }), "simple dump executed okay");
$fixtures->populate({ ddl => 't/lib/sqlite.sql', connection_details => ['dbi:SQLite:t/var/DBIxClass.db', '', ''], 
  directory => 't/var/fixtures', post_ddl => 't/lib/post_sqlite.sql' });
  
my ($producer) = $schema->resultset('Producer')->find(999999);
is($producer->name, "PostDDL", "Got producer name");
isa_ok($producer, "DBICTest::Producer", "Got post-ddl producer");

