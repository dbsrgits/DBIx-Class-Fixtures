package DBIx::Class::Fixtures;

use strict;
use warnings;

use DBIx::Class::Exception;
use Class::Accessor::Grouped;
use Path::Class qw(dir file);
use File::Slurp;
use Config::Any::JSON;
use Data::Dump::Streamer;
use Data::Visitor::Callback;
use File::Path;
use File::Copy::Recursive qw/dircopy/;
use File::Copy qw/move/;
use Hash::Merge qw( merge );
use Data::Dumper;
use Class::C3::Componentised;

use base qw(Class::Accessor::Grouped);

our $namespace_counter = 0;

__PACKAGE__->mk_group_accessors( 'simple' => qw/config_dir _inherited_attributes debug schema_class/);

=head1 VERSION

Version 1.000

=cut

our $VERSION = '1.000';

=head1 NAME

DBIx::Class::Fixtures

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

Dump fixtures from source database to filesystem then import to another database (with same schema)
at any time. Use as a constant dataset for running tests against or for populating development databases
when impractical to use production clones. Describe fixture set using relations and conditions based 
on your DBIx::Class schema.

=head1 DEFINE YOUR FIXTURE SET

Fixture sets are currently defined in .json files which must reside in your config_dir 
(e.g. /home/me/app/fixture_configs/a_fixture_set.json). They describe which data to pull and dump 
from the source database.

For example:

    {
        sets: [{
            class: 'Artist',
            ids: ['1', '3']
        }, {
            class: 'Producer',
            ids: ['5'],
            fetch: [{
                rel: 'artists',
                quantity: '2'
            }]
        }] 
    }

This will fetch artists with primary keys 1 and 3, the producer with primary key 5 and two of producer 5's 
artists where 'artists' is a has_many DBIx::Class rel from Producer to Artist.

The top level attributes are as follows:

=head2 sets

Sets must be an array of hashes, as in the example given above. Each set defines a set of objects to be
included in the fixtures. For details on valid set attributes see L</SET ATTRIBUTES> below.

=head2 rules

Rules place general conditions on classes. For example if whenever an artist was dumped you also wanted all
of their cds dumped too, then you could use a rule to specify this. For example:

    {
        sets: [{
            class: 'Artist',
            ids: ['1', '3']
        }, {
            class: 'Producer',
            ids: ['5'],
            fetch: [{ 
                rel: 'artists',
                quantity: '2'
            }]
        }],
        rules: {
            Artist: {
                fetch: [{
                    rel: 'cds',
                    quantity: 'all'
                }]
            }
        }
    }

In this case all the cds of artists 1, 3 and all producer 5's artists will be dumped as well. Note that 'cds' is a
has_many DBIx::Class relation from Artist to CD. This is eqivalent to:

    {
        sets: [{
            class: 'Artist',
            ids: ['1', '3'],
            fetch: [{
                rel: 'cds',
                quantity: 'all'
            }]
        }, {
            class: 'Producer',
            ids: ['5'],
            fetch: [{ 
                rel: 'artists',
                quantity: '2',
                fetch: [{
                    rel: 'cds',
                    quantity: 'all'
                }]
            }]
        }]
    }

rules must be a hash keyed by class name.

L</RULE ATTRIBUTES>

=head2 datetime_relative

Only available for MySQL and PostgreSQL at the moment, must be a value that DateTime::Format::*
can parse. For example:

    {
        sets: [{
            class: 'RecentItems',
            ids: ['9']
        }],
        datetime_relative : "2007-10-30 00:00:00"
    }

This will work when dumping from a MySQL database and will cause any datetime fields (where datatype => 'datetime' 
in the column def of the schema class) to be dumped as a DateTime::Duration object relative to the date specified in
the datetime_relative value. For example if the RecentItem object had a date field set to 2007-10-25, then when the
fixture is imported the field will be set to 5 days in the past relative to the current time.

=head2 might_have

Specifies whether to automatically dump might_have relationships. Should be a hash with one attribute - fetch. Set fetch to 1 or 0.

    {
        might_have: [{
            fetch: 1
        },
        sets: [{
            class: 'Artist',
            ids: ['1', '3']
        }, {
            class: 'Producer',
            ids: ['5']
        }]
    }

Note: belongs_to rels are automatically dumped whether you like it or not, this is to avoid FKs to nowhere when importing.
General rules on has_many rels are not accepted at this top level, but you can turn them on for individual
sets - see L</SET ATTRIBUTES>.

=head1 SET ATTRIBUTES

=head2 class

Required attribute. Specifies the DBIx::Class object class you wish to dump.

=head2 ids

Array of primary key ids to fetch, basically causing an $rs->find($_) for each. If the id is not in the source db then it
just won't get dumped, no warnings or death.

=head2 quantity

Must be either an integer or the string 'all'. Specifying an integer will effectively set the 'rows' attribute on the resultset clause,
specifying 'all' will cause the rows attribute to be left off and for all matching rows to be dumped. There's no randomising
here, it's just the first x rows.

=head2 cond

A hash specifying the conditions dumped objects must match. Essentially this is a JSON representation of a DBIx::Class search clause. For example:

    {
        sets: [{
            class: 'Artist',
            quantiy: 'all',
            cond: { name: 'Dave' }
        }]
    }

This will dump all artists whose name is 'dave'. Essentially $artist_rs->search({ name => 'Dave' })->all.

Sometimes in a search clause it's useful to use scalar refs to do things like:

$artist_rs->search({ no1_singles => \'> no1_albums' })

This could be specified in the cond hash like so:

    {
        sets: [{
            class: 'Artist',
            quantiy: 'all',
            cond: { no1_singles: '\> no1_albums' }
        }]
    }

So if the value starts with a backslash the value is made a scalar ref before being passed to search.

=head2 join

An array of relationships to be used in the cond clause.

    {
        sets: [{
            class: 'Artist',
            quantiy: 'all',
            cond: { 'cds.position': { '>': 4 } },
            join: ['cds']
        }]
    }

Fetch all artists who have cds with position greater than 4.

=head2 fetch

Must be an array of hashes. Specifies which rels to also dump. For example:

    {
        sets: [{
            class: 'Artist',
            ids: ['1', '3'],
            fetch: [{
                rel: 'cds',
                quantity: '3',
                cond: { position: '2' }
            }]
        }]
    }

Will cause the cds of artists 1 and 3 to be dumped where the cd position is 2.

Valid attributes are: 'rel', 'quantity', 'cond', 'has_many', 'might_have' and 'join'. rel is the name of the DBIx::Class
rel to follow, the rest are the same as in the set attributes. quantity is necessary for has_many relationships,
but not if using for belongs_to or might_have relationships.

=head2 has_many

Specifies whether to fetch has_many rels for this set. Must be a hash containing keys fetch and quantity. 

Set fetch to 1 if you want to fetch them, and quantity to either 'all' or an integer.

Be careful here, dumping has_many rels can lead to a lot of data being dumped.

=head2 might_have

As with has_many but for might_have relationships. Quantity doesn't do anything in this case.

This value will be inherited by all fetches in this set. This is not true for the has_many attribute.

=head1 RULE ATTRIBUTES

=head2 cond

Same as with L</SET ATTRIBUTES>

=head2 fetch

Same as with L</SET ATTRIBUTES>

=head2 join

Same as with L</SET ATTRIBUTES>

=head2 has_many

Same as with L</SET ATTRIBUTES>

=head2 might_have

Same as with L</SET ATTRIBUTES>

=head1 METHODS

=head2 new

=over 4

=item Arguments: \%$attrs

=item Return Value: $fixture_object

=back

Returns a new DBIx::Class::Fixture object. %attrs has only two valid keys at the
moment - 'debug' which determines whether to be verbose and 'config_dir' which is required and much contain a valid path to
the directory in which your .json configs reside.

  my $fixtures = DBIx::Class::Fixtures->new({ config_dir => '/home/me/app/fixture_configs' });

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

=over 4

=item Arguments: \%$attrs

=item Return Value: 1

=back

  $fixtures->dump({
    config => 'set_config.json', # config file to use. must be in the config directory specified in the constructor
    schema => $source_dbic_schema,
    directory => '/home/me/app/fixtures' # output directory
  });

In this case objects will be dumped to subdirectories in the specified directory. For example:

  /home/me/app/fixtures/artist/1.fix
  /home/me/app/fixtures/artist/3.fix
  /home/me/app/fixtures/producer/5.fix

config, schema and directory are all required attributes.

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

  $self->msg("generating  fixtures");
  my $tmp_output_dir = dir($output_dir, '-~dump~-');

  if (-e $tmp_output_dir) {
    $self->msg("- clearing existing $tmp_output_dir");
    $tmp_output_dir->rmtree;
  }
  $self->msg("- creating $tmp_output_dir");
  $tmp_output_dir->mkpath;

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
  move($_, dir($output_dir, $_->relative($_->parent)->stringify)) for $tmp_output_dir->children;
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

    my $formatter= $object->result_source->schema->storage->datetime_parser;
    # mess with dates if specified
    if ($set->{datetime_relative}) {
      unless ($@ || !$formatter) {
        my $dt;
        if ($set->{datetime_relative} eq 'today') {
          $dt = DateTime->today;
        } else {
          $dt = $formatter->parse_datetime($set->{datetime_relative}) unless ($@);
        }

        while (my ($col, $value) = each %ds) {
          my $col_info = $object->result_source->column_info($col);

          next unless $value
            && $col_info->{_inflate_info}
              && uc($col_info->{data_type}) eq 'DATETIME';

          $ds{$col} = $object->get_inflated_column($col)->subtract_datetime($dt);
        }
      } else {
        warn "datetime_relative not supported for this db driver at the moment";
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
  $namespace_counter++;
  my $namespace = "DBIx::Class::Fixtures::GeneratedSchema_" . $namespace_counter;
  Class::C3::Componentised->inject_base( $namespace => $schema_class );
  $pre_schema = $namespace->connect(@{$connection_details});
  unless( $pre_schema ) {
    return DBIx::Class::Exception->throw('connection details not valid');
  }
  my @tables = map { $pre_schema->source($_)->from } $pre_schema->sources;
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
  my $schema = $namespace->connect(@{$connection_details});
  return $schema;
}


=head2 populate

=over 4

=item Arguments: \%$attrs

=item Return Value: 1

=back

  $fixtures->populate({
    directory => '/home/me/app/fixtures', # directory to look for fixtures in, as specified to dump
    ddl => '/home/me/app/sql/ddl.sql', # DDL to deploy
    connection_details => ['dbi:mysql:dbname=app_dev', 'me', 'password'] # database to clear, deploy and then populate
  });

In this case the database app_dev will be cleared of all tables, then the specified DDL deployed to it,
then finally all fixtures found in /home/me/app/fixtures will be added to it. populate will generate
its own DBIx::Class schema from the DDL rather than being passed one to use. This is better as
custom insert methods are avoided which can to get in the way. In some cases you might not
have a DDL, and so this method will eventually allow a $schema object to be passed instead.

directory, dll and connection_details are all required attributes.

=cut

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
  my $formatter= $schema->storage->datetime_parser;
  unless ($@ || !$formatter) {
    my %callbacks;
    if ($params->{datetime_relative_to}) {
      $callbacks{'DateTime::Duration'} = sub {
        $params->{datetime_relative_to}->clone->add_duration($_);
      };
    } else {
      $callbacks{'DateTime::Duration'} = sub {
        $formatter->format_datetime(DateTime->today->add_duration($_))
      };
    }
    $callbacks{object} ||= "visit_ref";	
    $fixup_visitor = new Data::Visitor::Callback(%callbacks);
  }
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
      $rs->create($HASH1);
    }
  }

  $self->msg("- fixtures imported");
  $self->msg("- cleaning up");
  $tmp_fixture_dir->rmtree;
  eval { $schema->storage->dbh->do('SET foreign_key_checks=1') };

  return 1;
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

=head1 AUTHOR

  Luke Saunders <luke@shadowcatsystems.co.uk>

=head1 CONTRIBUTORS

  Ash Berlin <ash@shadowcatsystems.co.uk>
  Matt S. Trout <mst@shadowcatsystems.co.uk>

=cut

1;
