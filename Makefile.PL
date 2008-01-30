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
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'DBIx-Class-Fixtures-*' },
);
