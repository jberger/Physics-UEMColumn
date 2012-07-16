use strict;
use warnings;

use Test::More;

use Physics::UEMColumn;
use Physics::UEMColumn::Auxiliary ':constants';

my $pulse = Physics::UEMColumn::Pulse->new(
  number => 1,
  velocity => '1e8 m/s',
  sigma_t => 100 ** 2 / 2 . 'um^2',
  sigma_z => 50 ** 2 / 2 . 'um^2',
  eta_t => me * 5.3 / 3 * 0.5 / 10 . 'kg eV',
);
isa_ok($pulse, 'Physics::UEMColumn::Pulse');

my $column = Physics::UEMColumn::Column->new(
  length => '100 cm',
);
isa_ok($column, 'Physics::UEMColumn::Column');

my $solver_opts = {
  h_max => 5e-12,
  h_init => 1e-12 / 2,
};
my $sim = Physics::UEMColumn->new(
  column => $column,
  pulse => $pulse,
  debug => 1,
  solver_opts => $solver_opts,
);

my $result = $sim->propagate;
ok( $result, 'Got a result from simulation' );
is( ref $result, 'ARRAY', 'Result is an arrayref' );

done_testing;

