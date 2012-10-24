package Physics::UEMColumn::MagneticLens;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Physics::UEMColumn::Element'; }

use Method::Signatures;

has 'strength' => ( isa => 'Num', is => 'rw', required => 0);
has 'order' =>    ( isa => 'Int', is => 'ro', default => 1);

method effect () {

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

__PACKAGE__->meta->make_immutable;

1;

