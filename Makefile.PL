use inc::Module::Install 0.67;

name     'DBIx-Class-Fixtures';
perl_version '5.006001';
all_from 'lib/DBIx/Class/Fixtures.pm';

requires 'DBIx::Class' => 0.08;
requires 'Data::Visitor' => 0.15;
requires 'File::Copy::Recursive' => 0.35;
requires 'DateTime' => 0.41;
requires 'DateTime::Format::MySQL' => 0.04;
requires 'DBIx::Class::Schema::Loader' => 0.04004;
requires 'Class::Accessor::Grouped' => 0.06;
requires 'Path::Class' => 0.16;
requires 'File::Slurp' => 999.13;
requires 'Config::Any' => 0.08;
requires 'JSON::Syck' => 0.26;
requires 'Data::Dump::Streamer' => 2.05;
requires 'Hash::Merge' => 0.10;

build_requires 'Test::More'       => 0.7;

tests_recursive();

auto_provides;

auto_install;

WriteAll;
