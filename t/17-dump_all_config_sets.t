use DBIx::Class::Fixtures;
use Test::More tests => 17;

use lib qw(t/lib);
use DBICTest;
use Path::Class;
use Data::Dumper; 
use File::Spec;

ok my $config_dir = 't/var/configs';
ok my $schema = DBICTest->init_schema(), 'got schema';
ok my $fixtures = DBIx::Class::Fixtures->new({config_dir => $config_dir}),
  'object created with correct config dir';
  
ok(
  $fixtures->dump_config_sets({
    configs => [qw/date.json rules.json/],
    schema => $schema,
    directory_template => sub {
        my ($fixture, $params, $set) = @_;
        File::Spec->catdir('t','var','fixtures','multi', $set);
    },
  }),
  'simple dump executed okay',
);

__END__

    # check dump is okay
    my $dir = dir('t/var/fixtures/artist');
    ok(-e 't/var/fixtures/artist', 'artist directory created');

    my @children = $dir->children;
    is(scalar(@children), 1, 'right number of fixtures created');

    my $fix_file = $children[0];
    my $HASH1; eval($fix_file->slurp());
    is(ref $HASH1, 'HASH', 'fixture evals into hash');

    is_deeply([sort $schema->source('Artist')->columns], [sort keys %{$HASH1}], 'fixture has correct keys');

    my $artist = $schema->resultset('Artist')->find($HASH1->{artistid});
    is_deeply({$artist->get_columns}, $HASH1, 'dumped fixture is equivalent to artist row');

    $schema->resultset('Artist')->delete; # so we can create the row again on the next line
    ok($schema->resultset('Artist')->create($HASH1), 'new dbic row created from fixture');
}


