package Physics::UEMColumn::Pulse;

=head1 NAME

Physics::UEMColumn::Pulse - Class representing a pulse for the Physics::UEMColumn simulation

=head1 SYNOPSIS

  use strict;
  use warnings;

  use Physics::UEMColumn alias => ':standard';

  my $pulse = Pulse->new(
    velocity => '1e8 m/s',
    number => 1e6,
  );

=cut

use Moose;
use namespace::autoclean;

use Method::Signatures;

use MooseX::Types::NumUnit qw/num_of_unit/;
use Physics::UEMColumn::Auxiliary ':constants';

# user specified attributes

=head1 ATTRIBUTES

The L<Physics::UEMColumn::Pulse> class defines many attributes, however most are semi-private. From a practical perspective the user need only interact with the first three. The latter however, allow for a more physical creation of the pulse and thus are available to the user.

=over 

=item C<velocity>

The velocity of a pulse. This is required and may be zero, though note that without further acceleration the simulation may never come to completion. Unit: m/s

=cut

has 'velocity' => ( isa => num_of_unit('m/s'), is => 'rw', required => 1 );

=item C<location>

The location of the center of the pulse within the column. Default is C<0>, Unit: m

=cut

has 'location' => ( isa => num_of_unit('m'), is => 'rw', default => 0 );

=item C<number>

Number of electrons contained in the pulse. Default is C<1>

=cut

has 'number'   => ( isa => 'Num', is => 'rw', default => 1 );

my $unit_sigma = num_of_unit('m^2');
my $unit_eta   = num_of_unit('(kg m / s)^2');
my $unit_gamma = num_of_unit('kg m^2 / s');

# variance attributes

=item C<sigma_t> / C<sigma_z>

The spatial variance in the transverse and longitudinal direction respectively. Computing an initial value for C<sigma_z> is still a matter of much interest in the community. Any initialization seen in this code is rather naive. Unit: m^2

=cut

has 'sigma_t'  => ( isa => $unit_sigma, is => 'rw', lazy => 1, builder => '_make_sigma_t' );
has 'sigma_z'  => ( isa => $unit_sigma, is => 'rw', lazy => 1, builder => '_make_sigma_z' );

=item C<eta_t> / C<eta_z>

The local momentum variance in the transverse and longitudinal directions respectively. A value of 0 would imply a perfectly mono-chromated pulse (though this is unphysical). Unit: (kg m / s)^2

=cut

has 'eta_t'    => ( isa => $unit_eta, is => 'rw', lazy => 1, builder => '_make_eta_t' );
has 'eta_z'    => ( isa => $unit_eta, is => 'rw', lazy => 1, builder => '_make_eta_z' );

=item C<gamma_t> / C<gamma_z>

The momentum chirp in the transverse and longitudinal directions respectively. A value of zero would mean that the front, back and center of the pulse all have the same average momentum. Computing an initial value for C<gamma_z> is still a matter of much interest in the community. Any initialization seen in this code is rather naive. Unit: kg m^2 / s

=cut

has 'gamma_t'  => ( isa => $unit_gamma, is => 'rw', lazy => 1, builder => '_make_gamma_t' );
has 'gamma_z'  => ( isa => $unit_gamma, is => 'rw', lazy => 1, builder => '_make_gamma_z' );

=item C<liouville_gamma2_t> / C<liouville_gamma2_z>

The value of the product of C<sigma> and C<eta> in the transverse and longitudinal directions respectively. Since it can be easily shown that these pulses obey Liouville's Theorem, this product is unchanged during propagation. This value is used internally to reduce the number of equations to solve and thus increase solution speed. This value should not be changed manually but will be calculated from values given to quantities above.

=cut

has 'liouville_gamma2_t' => ( isa => 'Num', is => 'rw', lazy => 1, builder => '_make_lg2_t' );
has 'liouville_gamma2_z' => ( isa => 'Num', is => 'rw', lazy => 1, builder => '_make_lg2_z' );


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

# propagation history

=item C<data>

Holder for an array reference to the raw propagation history data. This should not be changed manually.

=cut

has 'data' => ( isa => 'ArrayRef', is => 'rw', default => sub { [] } );

=back

=cut

__PACKAGE__->meta->make_immutable;

1;

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Physics-UEMColumn>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

