package DBIx::Class::Fixtures::DBI;

use strict;
use warnings;

sub do_insert {
  my ($class, $schema, $sub) = @_;

  $schema->txn_do($sub);
}

1;
