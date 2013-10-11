#!perl

use DBIx::Class::Fixtures;
use lib qw(t/lib);
use DBICTest;
use Path::Class;
use Data::Dumper;
use Test::More tests => 7;

# set up and populate schema
ok(my $schema = DBICTest->init_schema(), 'got schema');
my $config_dir = 't/var/configs';

# This also tests multiple calls to dump and populate using
# the same fixture object
ok(my $fixtures = DBIx::Class::Fixtures->new({ 
    config_dir => $config_dir, 
    debug => 0 
  }), 'object created with correct config dir'
);

# predump_hook tests
DBICTest->clear_schema($schema);
DBICTest->populate_schema($schema);
ok($fixtures->dump({ 
  config => "fetch.json", 
  schema => $schema, 
  directory => 't/var/fixtures',
  predump_hook => sub {
      my ($src,$row) = @_;
      $row->{name} = 'predump_modified'
        if ($src->name eq 'artist' && $row->{artistid} == 1);
  }
}), "dump with predump_hook ok");

DBICTest->clear_schema($schema);
ok($fixtures->populate({ 
    ddl => 't/lib/sqlite.sql', 
    connection_details => ['dbi:SQLite:t/var/DBIxClass.db', '', ''], 
    directory => 't/var/fixtures',
}), 'populate after predump_hook ok');

is($schema->resultset('Artist')->find(1)->name, 'predump_modified', 'predump_hook ok');

## prepopulate_hook tests
DBICTest->clear_schema($schema);
ok($fixtures->populate({ 
    ddl => 't/lib/sqlite.sql', 
    connection_details => ['dbi:SQLite:t/var/DBIxClass.db', '', ''], 
    directory => 't/var/fixtures',
    prepopulate_hook => sub { 
        my ($src,$row) = @_;
        $row->{name} = 'prepopulate_modified'
          if ($src->name eq 'artist' && $row->{artistid} == 1);
    }
}), 'populate after prepopulate_hook ok');

is($schema->resultset('Artist')->find(1)->name, 'prepopulate_modified', 'prepopulate_hook ok');
