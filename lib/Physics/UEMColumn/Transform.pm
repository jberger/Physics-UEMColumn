use MooseX::Declare;

class Physics::UEMColumn::Transform {

  use Physics::UEMColumn::Auxiliary ':all';

  has 'active' => ( isa => 'Bool', is => 'ro', default => 0 );

  method time (Num $input, Num $direction = 1) {
    return $input;
  }

  method space (Num $input, Num $direction = 1) {
    return $input;
  }

  method velocity (Num $input, Num $direction = 1) {
    return $input;
  }

  method sigma (Num $input, Num $direction = 1) {
    return $input;
  }

  method eta (Num $input, Num $direction = 1) {
    return $input;
  }

  method gamma (Num $input, Num $direction = 1) {
    return $input;
  }

  method mass (Num $input, Num $direction = 1) {
    return $input;
  }

  method effect (Num $input, Num $direction = 1) {
    return $input;
  }

  method charge (Num $input, Num $direction = 1) {
    return $input;
  }

  method permitivity (Num $input, Num $direction = 1) {
    return $input;
  }


}
