use MooseX::Declare;

class Physics::UEMColumn::Transform {

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

  method effect (Num $input, Num $direction = 1) {
    return $input;
  }

  method mass (Num $input, Num $direction = 1) {
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

  use Physics::UEMColumn::Auxiliary ':all';

  has '+active' => ( default => 1 );

  method time (Num $input, Num $direction = 1) {
    return $input unless $self->active;
    return $input * (1e12)**($direction);
  }

  method space (Num $input, Num $direction = 1) {
    return $input unless $self->active;
    return $input * (1e6)**($direction);
  }

  method velocity (Num $input, Num $direction = 1) {
    return $input unless $self->active;
    return $input * (1e-6)**($direction);
  }

  method sigma (Num $input, Num $direction = 1) {
    return $input unless $self->active;
    return $input * (1e12)**($direction);
  }

  method eta (Num $input, Num $direction = 1) {
    return $input unless $self->active;
    return $input * (1/me)**($direction);
  }

  method gamma (Num $input, Num $direction = 1) {
    return $input unless $self->active;
    return $input * (1e-12/(me**2))**($direction);
  }

  method effect (Num $input, Num $direction = 1) {
    return $input unless $self->active;
    return $input * (1e-24/me)**($direction);
  }

  method mass (Num $input, Num $direction = 1) {
    return $input unless $self->active;
    return $input * (1/me)**($direction);
  }

  method charge (Num $input, Num $direction = 1) {
    return $input unless $self->active;
    return $input * (1/qe)**($direction);
  }

  method permittivity (Num $input, Num $direction = 1) {
    return $input unless $self->active;
    return $input * (314.15/epsilon_0)**($direction);
  }

}




