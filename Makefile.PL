use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'DBIx::Class::Fixtures',
    AUTHOR              => 'Luke Saunders <luke@shadowcatsystems.co.uk>',
    VERSION_FROM        => 'lib/DBIx/Class/Fixtures.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0.7,
        'DBIx::Class' => 0.08,
        'Class::Accessor::Grouped' => 0.08001,
        'Path::Class' => 0.16,
        'Config::Any' => 0.08,
        'JSON::Syck' => 0.26,
        'Data::Dump::Streamer' => 2.05,
        'Hash::Merge' => 0.10,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'DBIx-Class-Fixtures-*' },
);
