use MooseX::Declare;
use Method::Signatures::Modifiers;

class Physics::UEMColumn::Column {

  use MooseX::Types::NumUnit qw/num_of_unit/;

  has laser => ( isa => 'Physics::UEMColumn::Laser', is => 'ro', required => 1);
  has accelerator => ( isa => 'Physics::UEMColumn::Accelerator', is => 'ro', required => 1);
  has photocathode => ( isa => 'Physics::UEMColumn::Photocathode', is => 'ro', required => 1);

  has elements => ( 
    traits => ['Array'],
    isa => 'ArrayRef[Physics::UEMColumn::Element]',
    is => 'rw',
    handles => {
      add_element  => 'push',
    },
    default => sub{ [] },
  );

  has 'length' => ( isa => num_of_unit('m'), is => 'rw', required => 1 );

  method BUILD (Item $params) {
    $self->add_element( $self->accelerator );
    $self->photocathode->column( $self );
  } 

}

