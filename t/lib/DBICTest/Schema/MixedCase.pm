package # hide from PAUSE 
    DBICTest::Schema::MixedCase;

use base 'DBIx::Class::Core';

__PACKAGE__->table('MixedCase');
__PACKAGE__->add_columns(
  'id' => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  'name' => {
    data_type => 'varchar',
    size      => 100,
    is_nullable => 1,
  },
);
__PACKAGE__->set_primary_key('id');

1;
