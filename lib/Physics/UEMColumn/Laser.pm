use MooseX::Declare;
use Method::Signatures::Modifiers;

class Physics::UEMColumn::Laser {

  use MooseX::Types::NumUnit qw/num_of_unit/;

  has 'energy'   => ( isa => num_of_unit('J'), is => 'ro', required => 1 );
  has 'width'    => ( isa => 'Num', is => 'rw', required => 1 );
  has 'duration' => ( isa => 'Num', is => 'rw', required => 1 );

}
