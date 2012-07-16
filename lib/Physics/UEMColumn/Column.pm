use MooseX::Declare;
use Method::Signatures::Modifiers;

class Physics::UEMColumn::Column {

  use MooseX::Types::NumUnit qw/num_of_unit/;

  has laser => ( isa => 'Physics::UEMColumn::Laser', is => 'ro', predicate => 'has_laser' );
  has accelerator => ( isa => 'Physics::UEMColumn::Accelerator', is => 'ro', predicate => 'has_accelerator' );
  has photocathode => ( isa => 'Physics::UEMColumn::Photocathode', is => 'ro', predicate => 'has_photocathode' );

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

  method can_make_pulse () {
    return $self->has_laser && $self->has_accelerator && $self->has_photocathode;
  }

}

