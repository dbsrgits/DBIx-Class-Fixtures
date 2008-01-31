package DBIx::Class::Fixtures::SchemaVersioned;

use strict;
use warnings;

use base 'DBIx::Class::Schema::Loader';

our $VERSION = 'set-when-loading';

__PACKAGE__->load_components('Schema::Versioned');
__PACKAGE__->loader_options(
                            # debug                 => 1,
                           );

1;
