package Physics::UEMColumn::Photocathode;

use Moose;
use namespace::autoclean;

use Method::Signatures;

use MooseX::Types::NumUnit qw/num_of_unit/;
use Physics::UEMColumn::Pulse;
use Physics::UEMColumn::Auxiliary qw/:constants/;

my $type_energy = num_of_unit( 'J' );

has 'energy_fermi' => ( isa => $type_energy, is => 'ro', required => 1 ); 
has 'work_function' => ( isa => $type_energy, is => 'ro', required => 1 );
has 'location' => ( isa => num_of_unit('m'), is => 'ro', default => 0 );
has 'column' => ( isa => 'Physics::UEMColumn::Column', is => 'rw', predicate => 'has_column' );

method generate_pulse ( Num $num ) {
  die 'Photocathode requires access to column object' unless $self->has_column;
  my $column = $self->column;

  my $laser = $column->laser;
  my $acc = $column->accelerator;

  my $tau = $laser->duration;
  my $e_laser = $laser->energy;
  my $work_function = $self->work_function;
  my $e_fermi = $self->energy_fermi;

  my $field = $acc->field;

  my $delta_E = $e_laser - $work_function;
  my $velfront = sqrt( 2 * $delta_E / me );

  my $eta_t = me * $e_fermi / 3 * ( $e_laser - $work_function ) / ( $e_laser + $e_fermi );
  my $sigma_z = (($velfront*$tau)**2) / 2 + ( qe / ( 4 * me ) * $field * ($tau**2))**2;

  my $pulse = Physics::UEMColumn::Pulse->new(
    velocity => 0,
    location => $self->location(),
    number   => $num,
    sigma_t  => (($laser->width)**2) / 2,
    sigma_z  => $sigma_z,
    eta_t    => $eta_t,
    eta_z    => $eta_t / 4,
    gamma_t  => 0,
    gamma_z  => sqrt($sigma_z) * ( 0.06 * me * $velfront + qe / sqrt(2) * $field * $tau),
  );

  return $pulse;
}

__PACKAGE__->meta->make_immutable;

1;

