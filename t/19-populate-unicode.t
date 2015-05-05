#!perl

use DBIx::Class::Fixtures;
use Test::More no_plan;
use lib qw(t/lib);
use DBICTest;
use Path::Class;
use Data::Dumper;
use IO::All;
use Test::mysqld;
use utf8;

# set up and populate schema

plan skip_all => 'Set $ENV{FIXTURETEST_DSN}, _USER and _PASS to point at MySQL DB to run this test'
  unless ($ENV{FIXTURETEST_DSN});

ok( my $schema = DBICTest->init_schema( dsn => $ENV{FIXTURETEST_DSN}, user => $ENV{FIXTURETEST_USER}, pass => $ENV{FIXTURETEST_PASS} ) );



#ok( my $schema = DBICTest->init_schema(), 'got schema' );

my $config_dir = io->catfile(qw't var configs')->name;

# do dump
ok(
    my $fixtures = DBIx::Class::Fixtures->new(
        {
            config_dir => $config_dir,
            debug      => 0
        }
    ),
    'object created with correct config dir'
);

# DBI::mysql:database=test;host=localhost;port=5624



DBICTest->clear_schema($schema);
DBICTest->populate_schema($schema);

ok(
    $fixtures->dump(
        {
            schema    => $schema,
            directory => io->catfile(qw't var fixtures')->name,
            config    => "unicode.json",
        }
    ),
    "unicode dump executed okay"
);

$fixtures->populate(
    {
        connection_details => [  $ENV{FIXTURETEST_DSN}, $ENV{FIXTURETEST_USER}, $ENV{FIXTURETEST_PASS} ],
    	directory          => io->catfile(qw't var fixtures')->name,
        schema             => $schema,
        no_deploy          => 1,
        use_find_or_create => 1,
    }
);

my $cd = $schema->resultset('CD')->find( { cdid => 5 });

is($cd->title, "Unicode Chars ™ © • † ∑ α β « » → …", "Unicode chars found");

my $umlaute_cd = $schema->resultset('CD')->find( { cdid => 6 } );

is($umlaute_cd->title, "Übertreibung älterer Umlaute", "German special chars are correctly imported");
