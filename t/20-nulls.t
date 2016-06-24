#!perl

use DBIx::Class::Fixtures;
use Test::More tests => 6;
use lib qw(t/lib);
use DBICTest;
use Path::Class;
use Data::Dumper; 
use Test::TempDir::Tiny;
use IO::All;
use Test::Warnings;

my $tempdir = tempdir;

# set up and populate schema
ok(my $schema = DBICTest->init_schema(db_dir => $tempdir), 'got schema');

my $config_dir = io->catfile(qw't var configs')->name;

# do dump
ok(my $fixtures = DBIx::Class::Fixtures->new({ config_dir => $config_dir, debug => 0 }), 'object created with correct config dir');

ok($fixtures->dump({ config => 'nulls.json', schema => $schema, directory => $tempdir }), 'simple dump executed okay');

{
  # check dump is okay
  my $dir = dir(io->catfile($tempdir, qw'artist')->name);
  my @children = $dir->children;
  is(scalar(@children), 5, 'right number of fixtures created');
}

{
  # check dump is okay
  my $dir = dir(io->catfile($tempdir, qw'CD')->name);
  my @children = $dir->children;
  is(scalar(@children), 6, 'right number of fixtures created');
}

