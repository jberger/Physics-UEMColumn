use strict;
use warnings;

use Test::More tests => 18;

{
  package Local::Test::Default;
  use Physics::UEMColumn;

  for my $alias ( qw/ Laser Column Photocathode MagneticLens DCAccelerator RFCavity / ) {
    my $func = Local::Test::Default->can($alias);
    Test::More::ok( $func, "Alias is imported ($alias)" );
    Test::More::is( $func->(), "Physics::UEMColumn::$alias", "Alias has correct target" );
  }
}

{
  package Local::Test::All;
  use Physics::UEMColumn qw/:all/;

  Test::More::can_ok( 'Local::Test::All', 'Element' );
  Test::More::is( Element, 'Physics::UEMColumn::Element', 'correct definition of Element alias' );
}

{
  package Local::Test::Single;
  use Physics::UEMColumn qw/Column/;

  Test::More::can_ok( 'Local::Test::Single', 'Column' );
  Test::More::is( Column, 'Physics::UEMColumn::Column', 'correct definition of Column alias' );
  Test::More::ok( ! Local::Test::Single->can('Laser'), 'other aliases are not imported' );
}

{
  package Local::Test::None;
  use Physics::UEMColumn ();

  Test::More::ok( ! Local::Test::None->can('Column'), 'no aliases are imported' );
}
