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

# do dump
ok(my $fixtures = DBIx::Class::Fixtures->new({ config_dir => $config_dir }), 'object created with correct config dir');

my $output_dir = dir('t/var/fixtures');
$output_dir->mkpath;
my $file = file($output_dir, 'test_file');
my $fh = $file->open('w');
print $fh 'test file';
$fh->close;

ok($fixtures->dump({ config => 'simple.json', schema => $schema, directory => 't/var/fixtures' }), 'simple dump executed okay');

ok(-e $file, 'file still exists');
