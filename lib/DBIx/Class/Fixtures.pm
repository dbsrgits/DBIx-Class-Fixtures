package DBIx::Class::Fixtures;

use strict;
use warnings;

use DBIx::Class::Exception;
use Class::Accessor;
use Path::Class qw(dir file);
use FindBin;
use JSON::Syck qw(LoadFile);
use Data::Dumper;

use base qw(Class::Accessor);

__PACKAGE__->mk_accessors(qw(config_dir));

=head1 VERSION

Version 1.000

=cut

our $VERSION = '1.000';

=head1 NAME

=head1 SYNOPSIS

  use DBIx::Class::Fixtures;

  ...

  my $fixtures = DBIx::Class::Fixtures->new({ config_dir => '/home/me/app/fixture_configs' });

  $fixtures->dump({
    config => 'set_config.json',
    schema => $source_dbic_schema,
    directory => '/home/me/app/fixtures'
  });

  $fixtures->populate({
    directory => '/home/me/app/fixtures',
    ddl => '/home/me/app/sql/ddl.sql',
    connection_details => ['dbi:mysql:dbname=app_dev', 'me', 'password']
  });

=head1 DESCRIPTION

=head1 AUTHOR

=head1 CONTRIBUTORS

=cut


sub new {
  my $class = shift;

  my ($params) = @_;
  unless (ref $params eq 'HASH') {
    return DBIx::Class::Exception->throw('first arg to DBIx::Class::Fixtures->new() must be hash ref');
  }

  unless ($params->{config_dir}) {
    return DBIx::Class::Exception->throw('config_dir param not specified');
  }

  my $config_dir = dir($params->{config_dir});
  unless (-e $params->{config_dir}) {
    return DBIx::Class::Exception->throw('config_dir directory doesn\'t exist');
  }

  my $self = {
    config_dir => $config_dir
  };

  bless $self, $class;

  return $self;
}

1;
