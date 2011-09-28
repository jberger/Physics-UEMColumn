use MooseX::Declare;

class Physics::UEMColumn::Transform {

  use Physics::UEMColumn::Auxiliary ':all';

  # active should be respected by each method (except on this null case)
  # the Physics::UEMColumn does NOT always check for it, only on computationally intensive calls
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

  method permittivity (Num $input, Num $direction = 1) {
    return $input;
  }


}

class Physics::UEMColumn::Transform::UmPsMe0Qe0 
  extends Physics::UEMColumn::Transform {

  has '+active' => ( default => 1 );

  method time (Num $input, Num $direction = 1) {
    return $input unless $self->active;
  }

  method space (Num $input, Num $direction = 1) {
    return $input unless $self->active;
  }

  method velocity (Num $input, Num $direction = 1) {
    return $input unless $self->active;
  }

  method sigma (Num $input, Num $direction = 1) {
    return $input unless $self->active;
  }

  method eta (Num $input, Num $direction = 1) {
    return $input unless $self->active;
  }

  method gamma (Num $input, Num $direction = 1) {
    return $input unless $self->active;
  }

  method mass (Num $input, Num $direction = 1) {
    return $input unless $self->active;
  }

  method effect (Num $input, Num $direction = 1) {
    return $input unless $self->active;
  }

  method charge (Num $input, Num $direction = 1) {
    return $input unless $self->active;
  }

  method permittivity (Num $input, Num $direction = 1) {
    return $input unless $self->active;
  }

}




