use inc::Module::Install 0.79;

perl_version '5.006001';
name     'DBIx-Class-Fixtures';
all_from 'lib/DBIx/Class/Fixtures.pm';

requires 'DBIx::Class' => 0.08102;
requires 'Data::Visitor' => 0.30;
requires 'File::Copy::Recursive' => 0.38;
requires 'DateTime' => 1.03;
requires 'DBIx::Class::Schema::Loader' => 0.07035;
requires 'Class::Accessor::Grouped' => 0.10010;
requires 'Path::Class' => 0.32;
requires 'Config::Any' => 0.23;
requires 'JSON::Syck' => 1.27;
requires 'Data::Dump::Streamer' => 2.05;
requires 'Hash::Merge' => 0.10;
requires 'Scalar::Util' => 1.27;
requires 'MIME::Base64';
requires 'File::Spec::Functions' => 3.40;
requires 'File::Path' => 2.09;

requires 'DateTime::Format::SQLite' => 0.10;
requires 'DateTime::Format::MySQL' => 0;
requires 'DateTime::Format::Pg' => 0;

test_requires 'Test::More' => 0.98;
test_requires 'DBIx::Class::InflateColumn::FS' => 0.01007;

tests_recursive();

auto_install;

WriteAll;

