package DBIx::Class::Fixtures;

use strict;
use warnings;

use DBIx::Class::Exception;
use Class::Accessor;
use Path::Class qw(dir file);
use Config::Any::JSON;
use Data::Dump::Streamer;
use Data::Visitor::Callback;
use File::Slurp;
use File::Path;
use File::Copy::Recursive qw/dircopy/;
use Hash::Merge qw( merge );
use Data::Dumper;

use base qw(Class::Accessor);

__PACKAGE__->mk_accessors(qw(config_dir _inherited_attributes debug schema_class ));

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

=head1 METHODS

=head2 new

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
              config_dir => $config_dir,
              _inherited_attributes => [qw/datetime_relative might_have rules/],
              debug => $params->{debug}
  };

  bless $self, $class;

  return $self;
}

=head2 dump

=cut

sub dump {
  my $self = shift;

  my ($params) = @_;
  unless (ref $params eq 'HASH') {
    return DBIx::Class::Exception->throw('first arg to dump must be hash ref');
  }

  foreach my $param (qw/config schema directory/) {
    unless ($params->{$param}) {
      return DBIx::Class::Exception->throw($param . ' param not specified');
    }
  }

  my $config_file = file($self->config_dir, $params->{config});
  unless (-e $config_file) {
    return DBIx::Class::Exception->throw('config does not exist at ' . $config_file);
  }

  my $config = Config::Any::JSON->load($config_file);
  unless ($config && $config->{sets} && ref $config->{sets} eq 'ARRAY' && scalar(@{$config->{sets}})) {
    return DBIx::Class::Exception->throw('config has no sets');
  }

  my $output_dir = dir($params->{directory});
  unless (-e $output_dir) {
    return DBIx::Class::Exception->throw('output directory does not exist at ' . $output_dir);
  }

  my $schema = $params->{schema};

  $self->msg("generating  fixtures\n");
  my $tmp_output_dir = dir($output_dir, '-~dump~-');

  unless (-e $tmp_output_dir) {
    $self->msg("- creating $tmp_output_dir");
    mkdir($tmp_output_dir, 0777);
  }else {
    $self->msg("- clearing existing $tmp_output_dir");
    # delete existing fixture set
    system("rm -rf $tmp_output_dir/*");
  }

  # write version file (for the potential benefit of populate)
  my $version_file = file($tmp_output_dir, '_dumper_version');
  write_file($version_file->stringify, $VERSION);

  $config->{rules} ||= {};
  my @sources = sort { $a->{class} cmp $b->{class} } @{delete $config->{sets}};
  my %options = ( is_root => 1 );
  foreach my $source (@sources) {
    # apply rule to set if specified
    my $rule = $config->{rules}->{$source->{class}};
    $source = merge( $source, $rule ) if ($rule);

    # fetch objects
    my $rs = $schema->resultset($source->{class});	
	$rs = $rs->search($source->{cond}, { join => $source->{join} }) if ($source->{cond});
    $self->msg("- dumping $source->{class}");
    my @objects;
    my %source_options = ( set => { %{$config}, %{$source} } );
    if ($source->{quantity}) {
      $rs = $rs->search({}, { order_by => $source->{order_by} }) if ($source->{order_by});
      if ($source->{quantity} eq 'all') {
        push (@objects, $rs->all);
      } elsif ($source->{quantity} =~ /^\d+$/) {
        push (@objects, $rs->search({}, { rows => $source->{quantity} }));
      } else {
        DBIx::Class::Exception->throw('invalid value for quantity - ' . $source->{quantity});
      }
    }
    if ($source->{ids}) {
      my @ids = @{$source->{ids}};
      my @id_objects = grep { $_ } map { $rs->find($_) } @ids;
      push (@objects, @id_objects);
    }
    unless ($source->{quantity} || $source->{ids}) {
      DBIx::Class::Exception->throw('must specify either quantity or ids');
    }

    # dump objects
    foreach my $object (@objects) {
      $source_options{set_dir} = $tmp_output_dir;
      $self->dump_object($object, { %options, %source_options } );
      next;
    }
  }

  foreach my $dir ($output_dir->children) {
    next if ($dir eq $tmp_output_dir);
    $dir->remove || $dir->rmtree;
  }

  $self->msg("- moving temp dir to $output_dir");
  system("mv $tmp_output_dir/* $output_dir/");
  if (-e $output_dir) {
    $self->msg("- clearing tmp dir $tmp_output_dir");
    # delete existing fixture set
    $tmp_output_dir->remove;
  }

  $self->msg("done");

  return 1;
}

sub dump_object {
  my ($self, $object, $params, $rr_info) = @_;  
  my $set = $params->{set};
  die 'no dir passed to dump_object' unless $params->{set_dir};
  die 'no object passed to dump_object' unless $object;

  my @inherited_attrs = @{$self->_inherited_attributes};

  # write dir and gen filename
  my $source_dir = dir($params->{set_dir}, lc($object->result_source->from));
  mkdir($source_dir->stringify, 0777);
  my $file = file($source_dir, join('-', map { $object->get_column($_) } sort $object->primary_columns) . '.fix');

  # write file
  my $exists = (-e $file->stringify) ? 1 : 0;
  unless ($exists) {
    $self->msg('-- dumping ' . $file->stringify, 2);
    my %ds = $object->get_columns;

    # mess with dates if specified
    if ($set->{datetime_relative}) {     
      my $dt;
      if ($set->{datetime_relative} eq 'today') {
        $dt = DateTime->today;
      } else {
        require DateTime::Format::MySQL;
        $dt = DateTime::Format::MySQL->parse_datetime($set->{datetime_relative});
      }

      while (my ($col, $value) = each %ds) {
        my $col_info = $object->result_source->column_info($col);

        next unless $value
          && $col_info->{_inflate_info}
            && uc($col_info->{data_type}) eq 'DATETIME';

        $ds{$col} = $object->get_inflated_column($col)->subtract_datetime($dt);
      }
    }

    # do the actual dumping
    my $serialized = Dump(\%ds)->Out();
    write_file($file->stringify, $serialized);
    my $mode = 0777; chmod $mode, $file->stringify;  
  }

  # dump rels of object
  my $s = $object->result_source;
  unless ($exists) {
    foreach my $name (sort $s->relationships) {
      my $info = $s->relationship_info($name);
      my $r_source = $s->related_source($name);
      # if belongs_to or might_have with might_have param set or has_many with has_many param set then
      if (($info->{attrs}{accessor} eq 'single' && (!$info->{attrs}{join_type} || ($set->{might_have} && $set->{might_have}->{fetch}))) || $info->{attrs}{accessor} eq 'filter' || ($info->{attrs}{accessor} eq 'multi' && ($set->{has_many} && $set->{has_many}->{fetch}))) {
        my $related_rs = $object->related_resultset($name);	  
        my $rule = $set->{rules}->{$related_rs->result_source->source_name};
        # these parts of the rule only apply to has_many rels
        if ($rule && $info->{attrs}{accessor} eq 'multi') {		  
          $related_rs = $related_rs->search($rule->{cond}, { join => $rule->{join} }) if ($rule->{cond});
          $related_rs = $related_rs->search({}, { rows => $rule->{quantity} }) if ($rule->{quantity} && $rule->{quantity} ne 'all');
          $related_rs = $related_rs->search({}, { order_by => $rule->{order_by} }) if ($rule->{order_by});		  
        }
        if ($set->{has_many}->{quantity} && $set->{has_many}->{quantity} =~ /^\d+$/) {
          $related_rs = $related_rs->search({}, { rows => $set->{has_many}->{quantity} });
        }
        my %c_params = %{$params};
        # inherit date param
        my %mock_set = map { $_ => $set->{$_} } grep { $set->{$_} } @inherited_attrs;
        $c_params{set} = \%mock_set;
        #		use Data::Dumper; print ' -- ' . Dumper($c_params{set}, $rule->{fetch}) if ($rule && $rule->{fetch});
        $c_params{set} = merge( $c_params{set}, $rule) if ($rule && $rule->{fetch});
        #		use Data::Dumper; print ' -- ' . Dumper(\%c_params) if ($rule && $rule->{fetch});
        $self->dump_object($_, \%c_params) foreach $related_rs->all;	  
      }	
    }
  }
  
  return unless $set && $set->{fetch};
  foreach my $fetch (@{$set->{fetch}}) {
    # inherit date param
    $fetch->{$_} = $set->{$_} foreach grep { !$fetch->{$_} && $set->{$_} } @inherited_attrs;
    my $related_rs = $object->related_resultset($fetch->{rel});
    my $rule = $set->{rules}->{$related_rs->result_source->source_name};
    if ($rule) {
      my $info = $object->result_source->relationship_info($fetch->{rel});
      if ($info->{attrs}{accessor} eq 'multi') {
        $fetch = merge( $fetch, $rule );
      } elsif ($rule->{fetch}) {
        $fetch = merge( $fetch, { fetch => $rule->{fetch} } );
      }
    } 
    die "relationship " . $fetch->{rel} . " does not exist for " . $s->source_name unless ($related_rs);
    if ($fetch->{cond} and ref $fetch->{cond} eq 'HASH') {
      # if value starts with / assume it's meant to be passed as a scalar ref to dbic
      # ideally this would substitute deeply
      $fetch->{cond} = { map { $_ => ($fetch->{cond}->{$_} =~ s/^\\//) ? \$fetch->{cond}->{$_} : $fetch->{cond}->{$_} } keys %{$fetch->{cond}} };
    }
    $related_rs = $related_rs->search($fetch->{cond}, { join => $fetch->{join} }) if ($fetch->{cond});
    $related_rs = $related_rs->search({}, { rows => $fetch->{quantity} }) if ($fetch->{quantity} && $fetch->{quantity} ne 'all');
    $related_rs = $related_rs->search({}, { order_by => $fetch->{order_by} }) if ($fetch->{order_by});
    $self->dump_object($_, { %{$params}, set => $fetch }) foreach $related_rs->all;
  }
}

sub _generate_schema {
  my $self = shift;
  my $params = shift || {};
  require DBI;
  $self->msg("\ncreating schema");
  #   die 'must pass version param to generate_schema_from_ddl' unless $params->{version};

  my $schema_class = $self->schema_class || "DBIx::Class::Fixtures::Schema";
  eval "require $schema_class";
  die $@ if $@;

  my $pre_schema;
  my $connection_details = $params->{connection_details};
  unless( $pre_schema = $schema_class->connect(@{$connection_details}) ) {
    return DBIx::Class::Exception->throw('connection details not valid');
  }
  my @tables = map { $pre_schema->source($_)->from }$pre_schema->sources;
  my $dbh = $pre_schema->storage->dbh;

  # clear existing db
  $self->msg("- clearing DB of existing tables");
  eval { $dbh->do('SET foreign_key_checks=0') };
  $dbh->do('drop table ' . $_) for (@tables);

  # import new ddl file to db
  my $ddl_file = $params->{ddl};
  $self->msg("- deploying schema using $ddl_file");
  my $fh;
  open $fh, "<$ddl_file" or die ("Can't open DDL file, $ddl_file ($!)");
  my @data = split(/\n/, join('', <$fh>));
  @data = grep(!/^--/, @data);
  @data = split(/;/, join('', @data));
  close($fh);
  @data = grep { $_ && $_ !~ /^-- / } @data;
  for (@data) {
      eval { $dbh->do($_) or warn "SQL was:\n $_"};
	  if ($@) { die "SQL was:\n $_\n$@"; }
  }
  $self->msg("- finished importing DDL into DB");

  # load schema object from our new DB
  $self->msg("- loading fresh DBIC object from DB");
  my $schema = $schema_class->connect(@{$connection_details});
  return $schema;
}

sub populate {
  my $self = shift;
  my ($params) = @_;
  unless (ref $params eq 'HASH') {
    return DBIx::Class::Exception->throw('first arg to populate must be hash ref');
  }

  foreach my $param (qw/directory/) {
    unless ($params->{$param}) {
      return DBIx::Class::Exception->throw($param . ' param not specified');
    }
  }
  my $fixture_dir = dir(delete $params->{directory});
  unless (-e $fixture_dir) {
    return DBIx::Class::Exception->throw('fixture directory does not exist at ' . $fixture_dir);
  }

  my $ddl_file;
  my $dbh;  
  if ($params->{ddl} && $params->{connection_details}) {
    $ddl_file = file(delete $params->{ddl});
    unless (-e $ddl_file) {
      return DBIx::Class::Exception->throw('DDL does not exist at ' . $ddl_file);
    }
    unless (ref $params->{connection_details} eq 'ARRAY') {
      return DBIx::Class::Exception->throw('connection details must be an arrayref');
    }
  } elsif ($params->{schema}) {
    return DBIx::Class::Exception->throw('passing a schema is not supported at the moment');
  } else {
    return DBIx::Class::Exception->throw('you must set the ddl and connection_details params');
  }

  my $schema = $self->_generate_schema({ ddl => $ddl_file, connection_details => delete $params->{connection_details}, %{$params} });
  $self->msg("\nimporting fixtures");
  my $tmp_fixture_dir = dir($fixture_dir, "-~populate~-" . $<);

  my $version_file = file($fixture_dir, '_dumper_version');
  unless (-e $version_file) {
#     return DBIx::Class::Exception->throw('no version file found');
  }

  if (-e $tmp_fixture_dir) {
    $self->msg("- deleting existing temp directory $tmp_fixture_dir");
    $tmp_fixture_dir->rmtree;
  }
  $self->msg("- creating temp dir");
  dircopy(dir($fixture_dir, $schema->source($_)->from), dir($tmp_fixture_dir, $schema->source($_)->from)) for $schema->sources;

  eval { $schema->storage->dbh->do('SET foreign_key_checks=0') };
  my $fixup_visitor;
  my %callbacks;
  if ($params->{datetime_relative_to}) {
    $callbacks{'DateTime::Duration'} = sub {
      $params->{datetime_relative_to}->clone->add_duration($_);
    };
  } else {
    $callbacks{'DateTime::Duration'} = sub {
      DateTime->today->add_duration($_)
    };
  }
  $callbacks{object} ||= "visit_ref";	
  $fixup_visitor = new Data::Visitor::Callback(%callbacks);

  foreach my $source (sort $schema->sources) {
    $self->msg("- adding " . $source);
    my $rs = $schema->resultset($source);
    my $source_dir = dir($tmp_fixture_dir, lc($rs->result_source->from));
    next unless (-e $source_dir);
    while (my $file = $source_dir->next) {
      next unless ($file =~ /\.fix$/);
      next if $file->is_dir;
      my $contents = $file->slurp;
      my $HASH1;
      eval($contents);
      $HASH1 = $fixup_visitor->visit($HASH1) if $fixup_visitor;
      $rs->find_or_create($HASH1);
    }
  }

  $self->msg("- fixtures imported");
  $self->msg("- cleaning up");
  $tmp_fixture_dir->rmtree;
  eval { $schema->storage->dbh->do('SET foreign_key_checks=1') };
}

sub msg {
  my $self = shift;
  my $subject = shift || return;
  my $level = shift || 1;

  return unless $self->debug >= $level;
  if (ref $subject) {
	print Dumper($subject);
  } else {
	print $subject . "\n";
  }
}
1;
