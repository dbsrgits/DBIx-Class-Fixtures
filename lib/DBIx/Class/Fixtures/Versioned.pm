package DBIx::Class::Fixtures::Versioned;

use strict;
use warnings;

use base qw/DBIx::Class::Fixtures/;
use Class::C3;

=head1 VERSION

Version 1.000

=cut

our $VERSION = '1.000';

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

=head1 CONTRIBUTORS

=head1 METHODS

=head2 new

=cut

sub populate {
  my $self = shift;
  my ($params) = @_;

  $self->schema_class("DBIx::Class::Fixtures::SchemaVersioned");
  unless ($params->{version}) {
      return DBIx::Class::Exception->throw('You must pass a version to populate');
  }

  return $self->next::method(@_);
}

sub _generate_schema {
  my $self = shift;
  my ($params) = @_;

  my $v = $self->schema_class;
  # manually set the schema version
  ${$v::VERSION} = $params->{version};

  my $schema = $self->next::method(@_);

  # set the db version to the schema version
  $schema->upgrade(); # set version number  

  return $schema;
}

1;
