use MooseX::Declare;
use Method::Signatures::Modifiers;

class Physics::UEMColumn::Laser {

  use MooseX::Types::NumUnit qw/num_of_unit/;

  has 'energy'   => ( isa => num_of_unit('J'), is => 'ro', required => 1 );
  has 'width'    => ( isa => num_of_unit('m'), is => 'rw', required => 1 );
  has 'duration' => ( isa => num_of_unit('s'), is => 'rw', required => 1 );

}
