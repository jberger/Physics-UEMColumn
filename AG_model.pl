#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';

use Physics::UEMColumn;
use Physics::UEMColumn::Auxiliary ':materials';

use PDL;
use PDL::Graphics::PGPLOT::Window;

my $laser = Physics::UEMColumn::Laser->new(
  width => 1e-3,
  duration => 1e-12,
  energy => '4.75eV',
);

my $acc = Physics::UEMColumn::DCAccelerator->new(
  'length' => 0.01,
  voltage => 20000,
);

my $column = Physics::UEMColumn::Column->new(
  'length' => 0.2, 
  laser => $laser,
  accelerator => $acc,
  photocathode => Physics::UEMColumn::Photocathode->new(Ta),
);

my $sim = Physics::UEMColumn->new(
  column => $column,
  number => 1e8,
);

my $lens = Physics::UEMColumn::MagneticLens->new(
  location => 0.05,
  'length' => 0.01,
  strength => 1.2e-11,
);
$sim->column->add_element($lens);

my $rf_cav = Physics::UEMColumn::RFCavity->new(
  location  => 0.12,
  'length'  => 0.02,
  strength  => 4e5,
  frequency => 3e9,
);
$sim->column->add_element($rf_cav);

my $result = pdl( $sim->propagate );

my $win_t = pgwin( Device => '/xs');
my $win_z = pgwin( Device => '/xs');
#$win->line( $result->slice('(1),'), $result->slice('(2),') / $result->at(2,-1) );
$win_t->line( $result->slice('(1),'), sqrt( $result->slice('(3),') / $result->at(3,0) ) );
$win_z->line( $result->slice('(1),'), sqrt( $result->slice('(4),') / $result->at(4,0) ) );
print $result;



