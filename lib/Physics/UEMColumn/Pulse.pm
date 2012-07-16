use MooseX::Declare;
use Method::Signatures::Modifiers;

class Physics::UEMColumn::Pulse {

  use MooseX::Types::NumUnit qw/num_of_unit/;
  use Physics::UEMColumn::Auxiliary ':constants';

  # user specified attributes
  has 'velocity' => ( isa => num_of_unit('m/s'), is => 'rw', required => 1 );
#  has 'width'    => ( isa => 'Num', is => 'rw', required => 1 );
#  has 'duration' => ( isa => 'Num', is => 'rw', required => 1 );

  has 'location' => ( isa => num_of_unit('m'), is => 'rw', default => 0 );
  has 'number'   => ( isa => 'Num', is => 'rw', default => 1 );

  my $unit_sigma = num_of_unit('m^2');
  my $unit_eta   = num_of_unit('(kg m / s)^2');
  my $unit_gamma = num_of_unit('kg m^2 / s');

  # variance attributes
  has 'sigma_t'  => ( isa => $unit_sigma, is => 'rw', lazy => 1, builder => '_make_sigma_t' );
  has 'sigma_z'  => ( isa => $unit_sigma, is => 'rw', lazy => 1, builder => '_make_sigma_z' );
  has 'eta_t'    => ( isa => $unit_eta, is => 'rw', lazy => 1, builder => '_make_eta_t' );
  has 'eta_z'    => ( isa => $unit_eta, is => 'rw', lazy => 1, builder => '_make_eta_z' );
  has 'gamma_t'  => ( isa => $unit_gamma, is => 'rw', lazy => 1, builder => '_make_gamma_t' );
  has 'gamma_z'  => ( isa => $unit_gamma, is => 'rw', lazy => 1, builder => '_make_gamma_z' );
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
