package Physics::UEMColumn::Accelerator;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Physics::UEMColumn::Element'; }

use Method::Signatures;

method field () {
  return 0;
}

__PACKAGE__->meta->make_immutable;

1;


