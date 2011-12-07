#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';

use Physics::UEMColumn;
use Physics::UEMColumn::Auxiliary ':materials';

use PDL;
use PDL::Graphics::Gnuplot qw/plotlines/;

my $laser = Physics::UEMColumn::Laser->new(
  width => 1e-3,
  duration => 1e-12,
  energy => '4.75eV',
);

my $acc = Physics::UEMColumn::DCAccelerator->new(
  'length' => 0.020,
  voltage => 20000,
);

my $column = Physics::UEMColumn::Column->new(
  'length' => 0.350, 
  laser => $laser,
  accelerator => $acc,
  photocathode => Physics::UEMColumn::Photocathode->new(Ta),
);

my $solver_opts = {
#  type => 'bsimp_j',
#  type => 'msbdf_j',
#  scaling => 'yp',
#  epsrel => 1e-6,
#  h_max => 5e-12,
#  h_init => 1e-12 / 2,
};
my $sim = Physics::UEMColumn->new(
  column => $column,
  number => 1e8,
  debug => 1,
  solver_opts => $solver_opts,
#  need_jacobian => 1,
  use_transform => 1,
);

my $z_rf = 0.200;
my $l_mag_lens = 25.4e-3;
my $cooke_sep = 0.050;
my $str_mag = 15e-13;

my $lens1 = Physics::UEMColumn::MagneticLens->new(
  location => $z_rf - $cooke_sep,
  'length' => $l_mag_lens,
  strength => $str_mag,
);
my $lens2 = Physics::UEMColumn::MagneticLens->new(
  location => $z_rf + $cooke_sep,
  'length' => $l_mag_lens,
  strength => $str_mag,
);
$sim->column->add_element($lens1);
$sim->column->add_element($lens2);

my $rf_cav = Physics::UEMColumn::RFCavity->new(
  location  => $z_rf,
  'length'  => 0.02,
  strength  => 2.3e5,
  frequency => 3e9,
);
$sim->column->add_element($rf_cav);

my $result = pdl( $sim->propagate );

my $st = $result->slice('(3),');
my $sz = $result->slice('(4),');

plotlines( 
  $result->slice('(1),'), sqrt( $st / maximum($st) ), 
  $result->slice('(1),'), sqrt( $sz / maximum($sz) ),
);
#print $result;



