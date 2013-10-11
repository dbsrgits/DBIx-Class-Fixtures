package # hide from PAUSE 
    DBICTest::Schema::Artist_UC_RS;

use base 'DBIx::Class::Core';

__PACKAGE__->table('Artist_UC');
__PACKAGE__->add_columns(
  'artistid' => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  'name' => {
    data_type => 'varchar',
    size      => 100,
    is_nullable => 1,
  },
);
__PACKAGE__->set_primary_key('artistid');

sub new {
	my ( $class, $args ) = @_;

	$args->{name} = "Test Name" unless $args->{name};

	return $class->next::method( $args );
}

1;
