#!/usr/bin/env perl

use strict;
use warnings;

use Physics::UEMColumn;
use Physics::UEMColumn::Auxiliary ':materials';

use PDL;
use PDL::Graphics::PGPLOT::Window;

my $pulse = Physics::UEMColumn::Pulse->new(
  number => 1e8,
  velocity => 1,
  width => 1e-3,
  duration => 1e-12,
  energy_laser => 4.75,
  sigma_z => ( 1e-4 )**2 / 2,
  Ta,
);

my $sim = Physics::UEMColumn->new(
  pulse => $pulse,
);

my $acc = Physics::UEMColumn::DCAccelerator->new(
  'length' => 0.01,
  voltage => 20000,
);
$sim->column->add_element($acc);

my $lens = Physics::UEMColumn::MagneticLens->new(
  location => 0.05,
  'length' => 0.01,
  strength => 5e-11,
);
$sim->column->add_element($lens);

my $result = pdl( $sim->evaluate );

my $win = pgwin( Device => '/xs');
#$win->line( $result->slice('(1),'), $result->slice('(2),') / $result->at(2,-1) );
$win->line( $result->slice('(1),'), sqrt( $result->slice('(4),') / $result->at(4,0) ) );
print $result;



