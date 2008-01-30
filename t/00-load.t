#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'DBIx::Class::Fixtures' );
}

diag( "Testing DBIx::Class::Fixtures $DBIx::Class::Fixtures::VERSION, Perl $], $^X" );
