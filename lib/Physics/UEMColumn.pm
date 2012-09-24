package Physics::UEMColumn;

use Moose;
use namespace::autoclean;

use Method::Signatures;

use Carp;
use List::Util 'sum';

use PerlGSL::DiffEq;

use Physics::UEMColumn::Column;
use Physics::UEMColumn::Element;
use Physics::UEMColumn::Pulse;
use Physics::UEMColumn::Laser;
use Physics::UEMColumn::Photocathode;

use Physics::UEMColumn::Auxiliary ':all';

use MooseX::Types::NumUnit qw/num_of_unit/;
my $seconds = num_of_unit('s');

has 'debug' => ( isa => 'Num', is => 'ro', default => 0);

# possibly do transform here, in branches

has 'number' => ( isa => 'Num', is => 'rw', predicate => 'has_number');

has 'pulse' => (
  isa => 'Physics::UEMColumn::Pulse',
  is => 'ro',
  lazy => 1,
  builder => '_generate_pulse',
  predicate => 'has_pulse',
);

has 'column' => ( 
  isa => 'Physics::UEMColumn::Column', 
  is => 'ro', 
  required => 1,
  handles => [ qw/ add_element / ],
);

has 'start_time' => ( isa => $seconds, is => 'rw', default => 0 );
has 'end_time' => ( isa => $seconds, is => 'rw', lazy => 1, builder => '_est_init_end_time' );
has 'steps' => (isa => 'Int', is => 'rw', default => 100); # this is not likely to be the number of output steps
has 'step_width' => ( isa => $seconds, is => 'ro', lazy => 1, builder => '_set_step_width' );

#when estimating end times what additional error should be given. Set to 1 for no extra time.
has 'time_error' => ( isa => 'Num', is => 'ro', default => 1.1 );
#opts hashref passed directly to ode_solver
has 'solver_opts' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );
#has 'need_jacobian' => ( isa => 'Bool', is => 'ro', default => 0 );


method BUILD ($param) {

  # check for proper combinations of inputs
  unless ( $self->has_pulse or $self->column->can_make_pulse ) {
    die "You must either provide a pulse object to the simulation object or else include laser, accelerator and photocathode objects to the column";
  }

  if ( $self->has_pulse and $self->has_number ) {
    carp "'number' attribute is superfluous (and ignored) when a pulse object is provided";
  }

  unless ( $self->has_pulse or $self->has_number ) {
    die "You must provide either a pulse object or a number of electrons to create";
  }

  # initialize some solver options, if not specified
  my $solver_opts = $self->solver_opts;
  
  $solver_opts->{h_max}  = exists $solver_opts->{h_max}  ? $solver_opts->{h_max}  : 5e-12;
  $solver_opts->{h_init} = exists $solver_opts->{h_init} ? $solver_opts->{h_init} : 5e-13;
}

method _generate_pulse () {
  $self->column->photocathode->generate_pulse( $self->number );
}

method _set_step_width () {
  return ( ($self->end_time - $self->start_time) / $self->steps );
}

method _est_init_end_time () {
  my $t0 = $self->start_time;
  my $tf = $t0;

  my $acc = $self->column->accelerator;

  # this test is a holdover, leaving in case I want to implement a Null Accelerator
  # test should always succeed as acclerator is now a required attribute of the column
  if ($acc) {
    $tf += $acc->est_exit_time;
    $tf += ( ($self->column->length() - $acc->length()) / $acc->est_exit_vel );
  } else {
    # otherwise use given velocity
    $tf += $self->column->length() / $self->pulse->velocity;
  }

  #add 10% error factor (time will be extended later if needed)
  $tf *= $self->time_error;

  return $tf;
}

method propagate () {

  my $iter = 0;
  my $result = [];

  # continue to evaluate until pulse leaves column
  while ($self->pulse->location < $self->column->length) {
    $iter++;
    warn "Segment iteration number: " . $iter . "\n" if $self->debug;

    my $segment_result = $self->_evaluate_single_run();
    join_data( $result, $segment_result );
    last if $self->debug;
  }
  
  my $stored_data = $self->pulse->data;
  join_data( $stored_data, $result );

  # return only this propagation result
  # full data available from $pulse->data;
  return $result;

}

method _evaluate_single_run () {
  my $pulse		= $self->pulse;
  my $eqns		= $self->_make_diffeqs;
  my $start_time	= $self->start_time;
  my $end_time	= $self->end_time;

  if ($end_time == $start_time) {
    $end_time = $self->time_error * ($self->column->length - $pulse->location) / $self->pulse->velocity;
    $self->end_time( $end_time );
  }

  #logic here allows uniform step width over multiple runs
  my $steps = int(0.5 + ($end_time - $start_time) / $self->step_width);

  #calculate the propagation on the specified time range
  my $result;
  {
    local $SIG{__WARN__} = sub{ unless( $_[0] =~ /'ode_solver'/) { warn @_ } };
    $result = ode_solver( $eqns, [ $start_time, $end_time, $steps ], $self->solver_opts);
  }

  #update the simulation/pulse parameters from the result
  #this sets up the next run if needed
  my $end_state = $result->[-1];
  $self->start_time($end_state->[0] );
  $pulse->location( $end_state->[1] );
  $pulse->velocity( $end_state->[2] );
  $pulse->sigma_t(  $end_state->[3] );
  $pulse->sigma_z(  $end_state->[4] );
  #$pulse->eta_t(    $end_state->[5] );
  #$pulse->eta_z(    $end_state->[6] );
  $pulse->gamma_t(  $end_state->[5] );
  $pulse->gamma_z(  $end_state->[6] );
  $pulse->eta_t( $pulse->liouville_gamma2_t / $pulse->sigma_t );
  $pulse->eta_z( $pulse->liouville_gamma2_z / $pulse->sigma_z );

  return $result;
}

method _make_diffeqs () {
  my @return;

  my $pulse = $self->pulse;
  my $Ne = $pulse->number;
  my $Cn = $Ne * (qe**2) / ( 24 * pi * epsilon_0 * sqrt(pi));
  my $lg2_t = $pulse->liouville_gamma2_t;
  my $lg2_z = $pulse->liouville_gamma2_z;

  my @init_conds = (
    $pulse->location,
    $pulse->velocity,
    $pulse->sigma_t,
    $pulse->sigma_z,
    $pulse->gamma_t,
    $pulse->gamma_z,
  );

  #get the effect of all the elements in the column
  my $elements = $self->column->elements;
  my (@M_t, @M_z, @acc_z);
  foreach my $effect (map { $_->effect } @$elements) {
    push @M_t,   $effect->{M_t} if defined $effect->{M_t};
    push @M_z,   $effect->{M_z} if defined $effect->{M_z};
    push @acc_z, $effect->{acc} if defined $effect->{acc};
  }

  ## Create DE Code Reference ##
  my $eqns = sub {

    ## Initial Conditions ##

    unless (@_) {
      return @init_conds;
    }

    ## Parameters ##

    my ($t, $z, $v, $st, $sz, $gt, $gz) = @_;

    #if (1) { #make if $debug
    #  push @main::debug, [ $t, $z, $v, $st, $sz, $gt, $gz ];
    #}

    if ($st < 0) {
      warn "Sigma_t has gone negative at z=$z, t=$t\n";
      return (undef) x 6;
    }
    if ($sz < 0) {
      warn "Sigma_z has gone negative at z=$z, t=$t\n";
      return (undef) x 6;
    }

    my $M_t = sum map { $_->($t, $z, $v) } @M_t;
    my $M_z = sum map { $_->($t, $z, $v) } @M_z;
    my $acc_z = sum map { $_->($t, $z, $v) } @acc_z;

    #avoid "mathematical use of undef" warnings
    $M_t   ||= 0;
    $M_z   ||= 0;
    $acc_z ||= 0;

    ## Setup Differentials ##

    my $dz = $v;
    my $dv = $acc_z;

    my $dst = 2 * $gt / me;
    my $dsz = 2 * $gz / me;

    my $dgt = 
      ($lg2_t + ($gt**2)) / ( me * $st ) 
      + $Cn / sqrt($st) * L_t(sqrt($sz/$st))
      - $M_t * $st;
    my $dgz = 
      ($lg2_z + ($gz**2)) / ( me * $sz ) 
      + $Cn / sqrt($sz) * L_z(sqrt($sz/$st))
      - $M_z * $sz;

    return ($dz, $dv, $dst, $dsz, $dgt, $dgz);
  };

  return $eqns;

}

sub import {
  my $class = shift;
  my $caller = caller;

  my %opts = ref $_[0] ? %{ shift() } : @_;

  if (exists $opts{alias} and $caller) {
    $class->_setup_aliases( $caller, $opts{alias} );
  }
}

#hic sunt dracones
sub _setup_aliases {
  my $class = shift;
  my ($caller, $alias) = @_;

  # find all "classes" under Physics::UEMColumn and their short names
  my %can_alias =
    map  { @$_ }
    grep { $_->[1]->can('new') }
    map  { [ $_ => 'Physics::UEMColumn::' . $_ ] } 
    grep { s/::$// } 
    keys %Physics::UEMColumn::;

  # these are the classes that will be exported in place of the :standard tag
  my @standard = ( qw/ Laser Column Photocathode MagneticLens DCAccelerator RFCavity / );

  # define requested aliases
  my @to_alias = ref $alias ? @$alias : ( $alias );

  if ( $to_alias[0] eq ':standard' ) {
    shift @to_alias;
    unshift @to_alias, @standard;

  } elsif( $to_alias[0] eq ':all' ) {
    @to_alias = keys %can_alias;
  }

  # do the aliasing
  for my $short ( @to_alias ) {
    my $full = $can_alias{$short};
    
    # check that requested alias is known
    unless (defined $full) {
      carp "Unknown alias requested ($short)";
      next;
    }

    no strict 'refs';
    *{$caller . '::' . $short} = sub () { $full };
  }
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Physics::UEMColumn - An Implementation of the Analytic Gaussian (AG) Model for Ultrafast Electron Pulse Propagation

=head1 SYNOPSIS

  use strict;
  use warnings;

  use Physics::UEMColumn alias => ':standard';
  use Physics::UEMColumn::Auxiliary ':constants';

  my $pulse = Pulse->new(
    number   => 1e8,
    velocity => '1e8 m/s',
    sigma_t  => 100 ** 2 / 2 . 'um^2',
    sigma_z  => 50 ** 2 / 2 . 'um^2',
    eta_t    => me * 5.3 / 3 * 0.5 / 10 . 'kg eV',
  );

  my $column = Column->new(
    length => '100 cm',
  );

  my $sim = Physics::UEMColumn->new(
    column => $column,
    pulse  => $pulse,
  );

  my $result = $sim->propagate;

=head1 DESCRIPTION

L<Physics::UEMColumn> is an implementation of the Analytic Gaussian (AG) electron pulse propagation model, presented by Michalik and Sipe (L<http://dx.doi.org/10.1063/1.2178855>) and extended by Berger and Schroeder (L<http://dx.doi.org/10.1063/1.3512847>). 

=head2 About the Model

This extended model calculates the dynamics of electron pulse propagation for an ultrashort pulse of electrons (that is electron packets of short enough temporal length to be completely contained inside the acceleration region). These electrons are then subject to the internal repulsive Coulomb forces, as well as the external forces of acceleration regions, magnetic lenses and radio-frequency (RF) cavities. 

=head2 Caveats

The model is a self-similar Gaussian model, and therefore a mean-field model; futher the modeling of external forces is restricted to perfect lensing. Also, the equations governing the generation of pulse (and therefore the initial parameters), are as-yet unpublished, and unexplained. Should this not be preferable, one should manually create a L<Physics::UEMColumn::Pulse> object, rather than allowing the C<Physics::UEMColumn::Photocathode> object to create one automatically.

=head2 Examples

Included in the source package is an F<examples> directory. Contained within is a system analogous to an optical Cooke triplet. After a Tantalum photocathod and the acceleration region, is a magnetic lens, RF cavity and magnetic lens triplet. The script then uses L<PDL> and L<PDL::Graphics::Prima> to plot the transverse (red) and longitudinal (green) HW1/eM beam widths.

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Physics-UEMColumn>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

