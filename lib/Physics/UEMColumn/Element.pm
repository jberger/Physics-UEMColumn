use MooseX::Declare;
use Method::Signatures::Modifiers;

class Physics::UEMColumn::Element {

  use MooseX::Types::NumUnit qw/num_of_unit/;
  my $meters = num_of_unit('m');

  has 'location' => ( isa => $meters, is => 'ro', required => 1);
  has 'length'   => ( isa => $meters, is => 'ro', required => 1);

  has 'cutoff'   => ( isa => 'Num', is => 'ro', default => 3); # relative distance to ignore effect

  method effect () { 
    # return an hashref with code for M_t, M_z and acc_z
    return {};
  }

}

class Physics::UEMColumn::Accelerator
  extends Physics::UEMColumn::Element {

  method field () {
    return 0;
  }

}

class Physics::UEMColumn::DCAccelerator
  extends Physics::UEMColumn::Accelerator {

  use Physics::UEMColumn::Auxiliary ':constants';
  use Math::Trig qw/tanh sech/;
  use MooseX::Types::NumUnit qw/num_of_unit/;

  has '+location' => ( required => 0, default => 0 );
  has 'voltage' => ( isa => num_of_unit('V'), is => 'ro', required => 1 );
  has 'sharpness' => ( isa => 'Num', is => 'ro', default => 10 );

  override field () {
    $self->voltage / $self->length;
  }

  override effect () {
    my $anode_pos = $self->length;
    my $acc_voltage = $self->voltage;
    my $force = qe * $acc_voltage / $anode_pos;
    my $sharpness = $self->sharpness;

    # cutoff is used oddly here
    my $cutoff = $self->cutoff;

    my $acc = sub {
      my ($t, $pulse_z, $pulse_v) = @_;

      if ($pulse_z / $anode_pos > $cutoff) {
        return 0;
      }

      return $force / ( 2 * me ) * ( 1 - tanh( ($pulse_z - $anode_pos) * $sharpness / $anode_pos ) );

    };

    my $acc_mt = sub {
      my ($t, $pulse_z, $pulse_v) = @_;

      if ($pulse_z / $anode_pos > $cutoff) {
        return 0;
      }

      return - $force * $sharpness / ( 4 * $anode_pos ) * sech( ($pulse_z - $anode_pos) * $sharpness / $anode_pos ) ** 2;
    };

    my $acc_mz = sub {
      my ($t, $pulse_z, $pulse_v) = @_;

      if ($pulse_z / $anode_pos > $cutoff) {
        return 0;
      }

      return $force * $sharpness / ( 2 * $anode_pos ) * sech( ($pulse_z - $anode_pos) * $sharpness / $anode_pos ) ** 2;
    };

    #TODO add anode effects
    return {acc => $acc, M_t => $acc_mt, M_z => $acc_mz};

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

  has 'strength' => ( isa => 'Num', is => 'rw', required => 0);
  has 'order' =>    ( isa => 'Int', is => 'ro', default => 1);

  override effect () {

    my $lens_z = $self->location;
    my $lens_length = $self->length;
    my $lens_str = $self->strength;
    my $lens_order = $self->order;

    my $cutoff = $self->cutoff;

    my $code = sub {
      my ($t, $pulse_z, $pulse_v) = @_;

      my $prox = ($pulse_z - $lens_z) / ( $lens_length / 2 );
      if (abs($prox) > $cutoff) {
        return 0;
      }

      return $lens_str * exp( - $prox**(2 * $lens_order) );

    };

    return {M_t => $code};

  }

}

class Physics::UEMColumn::RFCavity
  extends Physics::UEMColumn::Element {

  use Physics::UEMColumn::Auxiliary ':constants';
  use MooseX::Types::NumUnit qw/num_of_unit/;

  has 'strength'  => (isa => num_of_unit('v/m'), is => 'rw', required => 1);
  has 'frequency' => (isa => num_of_unit('Hz') , is => 'ro', required => 1);
  #has 'radius'    => (isa => 'Num', is => 'ro', required => 1);

  has 'phase'     => (isa => 'Num', is => 'ro', default => 0);
  has 'order'     => (isa => 'Int', is => 'ro', default => 2);

  override effect () {

    my $lens_z = $self->location;
    my $length = $self->length;
    my $str    = $self->strength;
    my $order  = $self->order;
    my $freq   = $self->frequency;
    my $phase  = $self->phase;

    my $cutoff = $self->cutoff;

    my $code_z = sub {
      my ($t, $pulse_z, $pulse_v) = @_;

      my $prox = ($pulse_z - $lens_z) / ( $length / 2 );
      if (abs($prox) > $cutoff) {
        return 0;
      }

      my $return = 
        qe / $pulse_v * $str * 2 * pi * $freq 
        * cos( 2 * pi * $freq * ( $pulse_z - $lens_z ) / $pulse_v + $phase)
        * exp( - $prox**(2 * $order));

      return $return;

    };

    my $code_t = sub {
      my ($t, $pulse_z, $pulse_v) = @_;

      my $prox = ($pulse_z - $lens_z) / ( $length / 2 );
      if (abs($prox) > $cutoff) {
        return 0;
      }

      my $trig_arg = 2 * pi * $freq * ( $pulse_z - $lens_z ) / $pulse_v + $phase;

      my $mag_comp = 
        $pulse_v / (vc**2) * 2 * pi * $freq 
        * cos( $trig_arg );

      my $end_comp = 
        2 * $order / $length * ($prox**(2 * $order - 1))
        * sin( $trig_arg );

      return -$str * qe * ($mag_comp + $end_comp) * exp( - $prox**(2 * $order));

    };

    my $code_acc = sub {
      my ($t, $pulse_z, $pulse_v) = @_;

      my $prox = ($pulse_z - $lens_z) / ( $length / 2 );
      if (abs($prox) > $cutoff) {
        return 0;
      }

      my $return = 
        qe * $str
        * sin( 2 * pi * $freq * ( $pulse_z - $lens_z ) / $pulse_v + $phase)
        * exp( - $prox**(2 * $order));

    };

    return {M_t => $code_t, M_z => $code_z, acc => $code_acc};

  }

}

