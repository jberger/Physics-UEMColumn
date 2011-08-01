use MooseX::Declare;

class Physics::UEMColumn::Laser {

  use Physics::UEMColumn::Types qw/ Energy /;

  has 'energy'   => ( isa => Energy, is => 'ro', required => 1, coerce => 1);
  has 'width'    => ( isa => 'Num', is => 'rw', required => 1 );
  has 'duration' => ( isa => 'Num', is => 'rw', required => 1 );

}
