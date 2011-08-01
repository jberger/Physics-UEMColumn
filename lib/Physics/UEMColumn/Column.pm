use MooseX::Declare;

class Physics::UEMColumn::Column {

  use Physics::UEMColumn::Laser;

  has laser => ( isa => 'Physics::UEMColumn::Laser', is => 'ro', required => 1);

  has elements => ( 
    traits => ['Array'],
    isa => 'ArrayRef[Physics::UEMColumn::Element]',
    is => 'rw',
    handles => {
      add_element  => 'push',
    },
    default => sub{ [] },
  );

  has 'length' => ( isa => 'Num', is => 'rw', default => 0.1 ); #10cm

}

