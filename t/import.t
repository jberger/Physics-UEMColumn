use strict;
use warnings;

use Test::More tests => 2;

use Physics::UEMColumn;

can_ok( 'main', 'Column' );
is( Column, 'Physics::UEMColumn::Column', 'correct definition of Column shortcut' );
