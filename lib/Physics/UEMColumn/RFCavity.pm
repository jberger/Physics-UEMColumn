package Physics::UEMColumn::RFCavity;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Physics::UEMColumn::Element'; }

use Method::Signatures;

use Physics::UEMColumn::Auxiliary ':constants';
use MooseX::Types::NumUnit qw/num_of_unit/;

has 'strength'  => (isa => num_of_unit('v/m'), is => 'rw', required => 1);
has 'frequency' => (isa => num_of_unit('Hz') , is => 'ro', required => 1);
#has 'radius'    => (isa => 'Num', is => 'ro', required => 1);

has 'phase'     => (isa => 'Num', is => 'ro', default => 0);
has 'order'     => (isa => 'Int', is => 'ro', default => 2);

method effect () {

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

__PACKAGE__->meta->make_immutable;

1;


