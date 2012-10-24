package Physics::UEMColumn::DCAccelerator;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Physics::UEMColumn::Accelerator'; }

use Method::Signatures;

use Physics::UEMColumn::Auxiliary ':constants';
use Math::Trig qw/tanh sech/;
use MooseX::Types::NumUnit qw/num_of_unit/;

has '+location' => ( required => 0, default => 0 );
has 'voltage' => ( isa => num_of_unit('V'), is => 'ro', required => 1 );
has 'sharpness' => ( isa => 'Num', is => 'ro', default => 10 );

method field () {
  $self->voltage / $self->length;
}

method effect () {
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

__PACKAGE__->meta->make_immutable;

1;

