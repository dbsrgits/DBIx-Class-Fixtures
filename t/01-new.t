#!perl

use DBIx::Class::Fixtures;
use Test::More tests => 3;

my $config_dir = 't/var/configs';
my $imaginary_config_dir = 't/var/not_there';

eval {
  DBIx::Class::Fixtures->new({ });
};
ok($@, 'new errors without config dir');

eval {
  DBIx::Class::Fixtures->new({ config_dir => $imaginary_config_dir });
};
ok($@, 'new errors with non-existent config dir');

ok(my $fixtures = DBIx::Class::Fixtures->new({ config_dir => $config_dir }), 'object created with correct config dir');
