use strict;
use warnings;

use Test::More;

use Physics::UEMColumn;

my $pulse = Physics::UEMColumn::Pulse->new(
  number => 1,
  velocity => '1e8 m/s',
  sigma_t => 100 ** 2 / 2 . 'um^2',
  sigma_z => 50 ** 2 / 2 . 'um^2',
  eta_t => (1e6)**2 . 'm^2 / s^2',
);
isa_ok($pulse, 'Physics::UEMColumn::Pulse');

my $column = Physics::UEMColumn::Column->new(
  length => '100 cm',
);

done_testing;

