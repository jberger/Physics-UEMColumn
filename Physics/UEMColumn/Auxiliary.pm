package Physics::UEMColumn::Auxiliary;

use strict;
use warnings;

use Math::Trig;
use Math::GSLx::ODEIV2;

use parent 'Exporter';
our %EXPORT_TAGS = ( 
  constants => [ qw/ pi me qe epsilon_0 k / ],
  L_funcs   => [ qw/ L L_t L_z / ],
  materials => [ qw/ Ta / ],
);

our @EXPORT_OK;
push @EXPORT_OK, @$_ for values %EXPORT_TAGS;

$EXPORT_TAGS{'all'} = \@EXPORT_OK;

## Tag: constants ## 

use constant {
  me => 9.1e-31,
  qe => 1.6e-19,
  epsilon_0 => 8.85e-12,
};

use constant {
  k => 1 / (4 * pi * epsilon_0),
};

## Tag: materials ##

sub Ta() {
  return (
    energy_fermi => 5.3,
    work_function => 4.25,
  );
}

## Tag: L_funcs ##

sub L {
  my ($xi) = @_;

  if ($xi >= 1) {
    my $sqrt = sqrt(($xi**2) - 1);
    return log($xi + $sqrt) / $sqrt;

  } elsif ( $xi >= 0) {
    my $sqrt = sqrt(1 - ($xi**2));
    return asin($sqrt) / $sqrt;

  } else {
    die "xi is out of range";
  }
}

sub L_t {
  my ($xi) = @_;
  my $L = L($xi);

  return 1.5 * ( $L + (($xi**2)*$L - $xi) / (1 - $xi**2) );
}

sub L_z {
  my ($xi) = @_;
  my $L = L($xi);

  return 3 * ($xi**2) * ( $xi * $L - 1) / (($xi**2) - 1)
}

1;

