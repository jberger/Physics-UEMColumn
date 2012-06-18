use MooseX::Declare;
use Method::Signatures::Modifiers;

class Physics::UEMColumn::Pulse {

  use Physics::UEMColumn::Auxiliary ':constants';
  use MooseX::Types::NumUnit qw/num_of_unit/;

  # user specified attributes
  has 'velocity' => ( isa => num_of_unit('m/s'), is => 'rw', required => 1 );

  has 'location' => ( isa => num_of_unit('m'), is => 'rw', default => 0 );
  has 'number'   => ( isa => 'Num', is => 'rw', default => 1 );

  # variance attributes
  has 'sigma_t'  => ( isa => num_of_unit('m^2'), is => 'rw', lazy => 1, builder => '_make_sigma_t' );
  has 'sigma_z'  => ( isa => num_of_unit('m^2'), is => 'rw', lazy => 1, builder => '_make_sigma_z' );
  has 'eta_t'    => ( isa => num_of_unit('(kg m / s)^2'), is => 'rw', lazy => 1, builder => '_make_eta_t' );
  has 'eta_z'    => ( isa => num_of_unit('(kg m / s)^2'), is => 'rw', lazy => 1, builder => '_make_eta_z' );
  has 'gamma_t'  => ( isa => num_of_unit('kg m^2 / s'), is => 'rw', lazy => 1, builder => '_make_gamma_t' );
  has 'gamma_z'  => ( isa => num_of_unit('kg m^2 / s'), is => 'rw', lazy => 1, builder => '_make_gamma_z' );

  # derived quantities (units of gamma^2)
  has 'liouville_gamma2_t' => ( isa => 'Num', is => 'rw', lazy => 1, builder => '_make_lg2_t' );
  has 'liouville_gamma2_z' => ( isa => 'Num', is => 'rw', lazy => 1, builder => '_make_lg2_z' );

  # propagation history
  has 'data' => ( isa => 'ArrayRef', is => 'rw', default => sub { [] } );


  # variance attribute initializers
  method _make_sigma_t () {
    return (($self->width)**2) / 2;
  }
  method _make_sigma_z () {
    return (($self->velocity * $self->duration)**2) / 2;
  }

  method _make_eta_t () {
    #me * $energy_fermi / 3 * ( $energy_laser - $work_function ) / ( $energy_laser + $energy_fermi );
    return 0;
  }
  method _make_eta_z () {
    return $self->eta_t() / 4;
  }

  method _make_gamma_t () {
    return 0;
  }
  method _make_gamma_z () {
    return 0;
  }

  method _make_lg2_t () {
    return $self->sigma_t * $self->eta_t;
  }
  method _make_lg2_z () {
    return $self->sigma_z * $self->eta_z;
  }

}
