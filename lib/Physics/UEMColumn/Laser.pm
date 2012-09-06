package Physics::UEMColumn::Laser;

use Moose;
use namespace::autoclean;

use MooseX::Types::NumUnit qw/num_of_unit/;

has 'energy'   => ( isa => num_of_unit('J'), is => 'ro', required => 1 );
has 'width'    => ( isa => num_of_unit('m'), is => 'rw', required => 1 );
has 'duration' => ( isa => num_of_unit('s'), is => 'rw', required => 1 );

__PACKAGE__->meta->make_immutable;

1;

