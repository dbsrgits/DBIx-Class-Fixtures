use DBIx::Class::Fixtures;
use Test::More;
use File::Path 'rmtree';

use lib qw(t/lib);
use ExtraTest::Schema;

(my $schema = ExtraTest::Schema->connect(
  'DBI:SQLite::memory:','',''))->init_schema;

open(my $fh, '<', 't/18-extra.t') ||
  die "Can't open the filehandle, test is trash!";

ok my $row = $schema
  ->resultset('Photo')
  ->create({
    photographer=>'john',
    file=>$fh,
  });

close($fh);

my $fixtures = DBIx::Class::Fixtures
  ->new({
    config_dir => 't/var/configs',
    debug => 0 });

ok(
  $fixtures->dump({
    config => 'extra.json',
    schema => $schema,
    directory => "t/var/fixtures/photos" }),
  'fetch dump executed okay');

ok my $key = $schema->resultset('Photo')->first->file;

ok -e $key, 'File Created';

ok $schema->resultset('Photo')->delete;

ok ! -e $key, 'File Deleted';

ok(
  $fixtures->populate({
    no_deploy => 1,
    schema => $schema,
    directory => "t/var/fixtures/photos"}),
  'populated');

is $key, $schema->resultset('Photo')->first->file,
  'key is key';

ok -e $key, 'File Restored';

done_testing;

END {
  rmtree 't/var/files';
  rmtree 't/var/fixtures/photos';
}
