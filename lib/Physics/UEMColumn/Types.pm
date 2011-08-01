package Physics::UEMColumn::Types;

use strict;
use warnings;

use Physics::UEMColumn::Auxiliary ':constants';

use MooseX::Types -declare => [ qw/
  Energy
/ ];

# import builtin types
use MooseX::Types::Moose qw/Num Str/;

subtype Energy,
  as Num;

coerce Energy,
  from Str,
  via { my $in = $_; if ( $in =~ s/ *eV// ) { qe * $in } else { $in }  };

1;

