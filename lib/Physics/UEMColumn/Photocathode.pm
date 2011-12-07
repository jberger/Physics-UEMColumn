use MooseX::Declare;
use Method::Signatures::Modifiers;

class Physics::UEMColumn::Photocathode {

  use Physics::UEMColumn::Types qw/Energy/;
  use Physics::UEMColumn::Pulse;
  use Physics::UEMColumn::Auxiliary qw/:constants/;

  has 'energy_fermi' => ( isa => Energy, is => 'ro', required => 1, coerce => 1); 
  has 'work_function' => ( isa => Energy, is => 'ro', required => 1, coerce => 1);
  has 'location' => ( isa => 'Num', is => 'ro', default => 0 );

  method generate_pulse (Physics::UEMColumn::Column $column, Num $num) {
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

}
