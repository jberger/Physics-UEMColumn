use MooseX::Declare;

class Physics::UEMColumn::Element {

  has 'location' => ( isa => 'Num', is => 'ro', required => 1); #
  has 'length'    => ( isa => 'Num', is => 'ro', required => 1); #

  method effect () { 
    # return an arrayref with code for M_t, M_z and acc_z respectively or 0
    return [0, 0, 0];
  }

}

class Physics::UEMColumn::DCAccelerator
  extends Physics::UEMColumn::Element {

  use Physics::UEMColumn::Auxiliary ':constants';

  has '+location' => ( required => 0, default => 0 );
  has 'voltage' => ( isa => 'Num', is => 'ro', required => 1 );

  override effect () {
    my $acc_length = $self->length;
    my $acc_voltage = $self->voltage;

    my $code = sub {
      my ($t, $pulse_z, $pulse_v) = @_;

      if ($pulse_z > $acc_length) {
        return 0;
      }

      return qe * $acc_voltage / ( me * $acc_length );

    };

    return [0, 0, $code];

  }

  method est_exit_vel () {
    return sqrt( 2 * qe * $self->voltage / me );
  }

  method est_exit_time () {
    # assumes pulse has initial vel zero
    return $self->length() * sqrt( 2 * me / ( qe * $self->voltage ) );
  }

}

class Physics::UEMColumn::MagneticLens 
  extends Physics::UEMColumn::Element {

  has 'strength' => ( isa => 'Num', is => 'rw', default => 0);
  has 'order' =>    ( isa => 'Int', is => 'ro', default => 1);

  override effect () {

    my $lens_z = $self->location;
    my $lens_length = $self->length;
    my $lens_str = $self->strength;
    my $lens_order = $self->order;

    my $code = sub {
      my ($t, $pulse_z, $pulse_v) = @_;

      my $prox = ($pulse_z - $lens_z) / ( $lens_length / 2 );
      if (abs($prox) > 3) {
        return 0;
      }

      return $lens_str * exp( - $prox**(2 * $lens_order) );

    };

    return [$code, 0, 0];

  }

}
