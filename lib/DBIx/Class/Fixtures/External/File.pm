package DBIx::Class::Fixtures::External::File;

use strict;
use warnings;

use File::Spec::Functions 'catfile';

sub _load {
  my ($class, $path) = @_;
  open(my $fh, '<', $path)
    || die "can't open $path: $!";
  local $/ = undef;
  my $content = <$fh>;
}

sub _save {
  my ($class, $path, $content) = @_;
  open (my $fh, '>', $path)
    || die "can't open $path: $!";
  print $fh $content;
  close($fh);
}

sub fetch {
  my ($class, $key, $args) = @_;
  my $path = catfile($args->{path}, $key);
  return my $fetched = $class->_load($path);
}

sub write {
  my ($class, $key, $content, $args) = @_;
  my $path = catfile($args->{path}, $key);
  $class->_save($path, $content);
}

1;
