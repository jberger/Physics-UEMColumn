package Physics::UEMColumn::DCAccelerator;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Physics::UEMColumn::Accelerator'; }

use Method::Signatures;

use Physics::UEMColumn::Auxiliary ':constants';
use Math::Trig qw/tanh sech/;
use MooseX::Types::NumUnit qw/num_of_unit/;

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

=head1 NAME

Physics::UEMColumn::Element - A class representing a DC acceleration region in a UEM system

=head1 SYNOPSIS

  use Physics::UEMColumn alias => ':standard';
  my $acc = DCAccelerator->new(

  );

=head1 DESCRIPTION

L<Physics::UEMColumn::Accelerator> is a class representing a DC (static electric field) acceleration region in a UEM system It is itself a subclass of L<Physics::UEMColumn::Element> and inherits its attributes and methods. Additionally it provides:

=head1 METHODS

=over

=item C<field>

Returns a field strength possibly derived from other attributes. In this base class it simply returns zero. This method is intended to be redefined on subclassing.

=back

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Physics-UEMColumn>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

