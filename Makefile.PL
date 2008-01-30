use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'DBIx::Class::Fixtures',
    AUTHOR              => 'Luke Saunders <luke@shadowcatsystems.co.uk>',
    VERSION_FROM        => 'lib/DBIx/Class/Fixtures.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'DBIx::Class' => 0,
        'Class::Accessor' => 0,
        'Path::Class' => 0,
        'Config::Any' => 0,
        'Data::Dump::Streamer' => 0,
        'File::Slurp' => 0,
        'Hash::Merge' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'DBIx-Class-Fixtures-*' },
);
