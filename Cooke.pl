#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';

use Physics::UEMColumn;
use Physics::UEMColumn::Auxiliary ':materials';

use PDL;
use PDL::Graphics::Prima::Simple [700,500];

my $laser = Physics::UEMColumn::Laser->new(
  width => 1e-3,
  duration => 1e-12,
  energy => '4.75 eV',
);

my $acc = Physics::UEMColumn::DCAccelerator->new(
  'length' => 0.020,
  voltage => 20000,
);

my $column = Physics::UEMColumn::Column->new(
  'length' => 0.400, 
  laser => $laser,
  accelerator => $acc,
  photocathode => Physics::UEMColumn::Photocathode->new(Ta),
);

my $solver_opts = {
  h_max => 5e-12,
  h_init => 1e-12 / 2,
};
my $sim = Physics::UEMColumn->new(
  column => $column,
  number => 1,
  debug => 1,
  solver_opts => $solver_opts,
);

my $z_rf = 0.200;
my $l_mag_lens = 25.4e-3;
my $cooke_sep = 0.050;
my $str_mag = 33e-13;

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

my $z = $result->slice('(1),');
my $st = $result->slice('(3),');
my $sz = $result->slice('(4),');

plot(
  -st => ds::Pair( 
    $z, sqrt( $st / maximum($st) ),
    colors => pdl(255,0,0)->rgb_to_color,
    plotType => ppair::Lines,
    lineWidths => 3,
  ),
  -sz => ds::Pair( 
    $z, sqrt( $sz / maximum($sz) ),
    colors => pdl(0,255,0)->rgb_to_color,
    plotType => ppair::Lines,
    lineWidths => 3,
  ),
  x => { label => 'Position (m)' },
);

my $min_length = sqrt( 2 * minimum($sz)->sclr );
my $min_duration = $min_length / $sim->pulse->velocity;
printf "Min Length: %.2fnm (%.2ffs)\n", $min_length/1e-9, $min_duration/1e-15;


