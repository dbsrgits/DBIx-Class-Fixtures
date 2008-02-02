package DBIx::Class::Fixtures::Versioned;

use strict;
use warnings;

use base qw/DBIx::Class::Fixtures/;
use DBIx::Class::Fixtures::SchemaVersioned;
use Class::C3;

=head1 VERSION

Version 1.000

=cut

our $VERSION = '1.000';

=head1 NAME

DBIx::Class::Fixtures::Versioned

=head1 DESCRIPTION

Just ignore it for now, but it will vaguely tie in to DBIx::Class::Schema::Versioned's functionality eventually.

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

  # manually set the schema version
  $DBIx::Class::Fixtures::SchemaVersioned::VERSION = $params->{version};

  my $schema = $self->next::method(@_);
  $schema->schema_version($params->{version});

  # set the db version to the schema version
  $schema->upgrade(); # set version number

  return $schema;
}

1;
