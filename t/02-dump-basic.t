#!perl

use DBIx::Class::Fixtures;
use Test::More tests => 17;
use lib qw(t/lib);
use DBICTest;
use Path::Class;
use Data::Dumper; 

# set up and populate schema
ok(my $schema = DBICTest->init_schema(), 'got schema');

my $config_dir = 't/var/configs';

{
    # do dump
    ok(my $fixtures = DBIx::Class::Fixtures->new({ config_dir => $config_dir, debug => 0 }), 'object created with correct config dir');
    ok($fixtures->dump({ config => 'simple.json', schema => $schema, directory => 't/var/fixtures' }), 'simple dump executed okay');

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

{
    # do dump with hashref config
    ok(my $fixtures = DBIx::Class::Fixtures->new({ config_dir => $config_dir, debug => 0 }), 'object created with correct config dir');
    ok($fixtures->dump({
        config => {
            "might_have" => {
                "fetch" => 0
            },
            "has_many" => {
                "fetch" => 0
            },
            "sets" => [{
                "class" => "Artist",
                "quantity" => 1
            }]
        },
        schema => $schema, 
        directory => 't/var/fixtures',
    }), 'simple dump executed okay');

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
