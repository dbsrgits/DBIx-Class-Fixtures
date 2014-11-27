#!perl

use DBIx::Class::Fixtures;
use Test::More tests => 7;
use lib qw(t/lib);
use DBICTest;
use Path::Class;
use Data::Dumper; 

# set up and populate schema
ok(my $schema = DBICTest->init_schema(), 'got schema');

my $config_dir = 't/var/configs';

# do dump
ok(my $fixtures = DBIx::Class::Fixtures->new({ config_dir => $config_dir, debug => 0 }), 'object created with correct config dir');

ok($fixtures->dump({ config => 'scalar_ref.json', schema => $schema, directory => 't/var/fixtures' }), 'simple dump executed okay');

{
  # check dump is okay
  my $dir = dir('t/var/fixtures/artist');
  my @children = $dir->children;
  is(scalar(@children), 1, 'right number of fixtures created');
  
  my $fix_file = $children[0];
  my $HASH1; eval($fix_file->slurp());

  is($HASH1->{name}, 'We Are Goth', 'correct artist dumped');
}

{
  # check dump is okay
  my $dir = dir('t/var/fixtures/CD');
  my @children = $dir->children;
  is(scalar(@children), 1, 'right number of fixtures created');
  
  my $fix_file = $children[0];
  my $HASH1; eval($fix_file->slurp());

  is($HASH1->{title}, 'Come Be Depressed With Us', 'correct cd dumped');
}


