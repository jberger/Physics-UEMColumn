use MooseX::Declare;

class Physics::UEMColumn {

  use Carp;
  use List::Util 'sum';

  use Math::GSLx::ODEIV2;

  use Physics::UEMColumn::Column;
  use Physics::UEMColumn::Element;
  use Physics::UEMColumn::Pulse;
  use Physics::UEMColumn::Laser;
  use Physics::UEMColumn::Photocathode;

  use Physics::UEMColumn::Auxiliary ':all';

  has 'number' => ( isa => 'Num', is => 'rw', required => 1);

  has 'pulse' => (
    isa => 'Physics::UEMColumn::Pulse',
    is => 'ro',
    lazy => 1,
    builder => '_generate_pulse',
  );

  has 'column' => ( 
    isa => 'Physics::UEMColumn::Column', 
    is => 'ro', 
    required => 1,
  );

  has 'start_time' => ( isa => 'Num', is => 'rw', default => 0 );
  has 'end_time' => ( isa => 'Num', is => 'rw', lazy => 1, builder => '_est_init_end_time' );
  has 'steps' => (isa => 'Int', is => 'rw', default => 100); # this is not likely to be the number of output steps
  has 'step_width' => ( isa => 'Num', is => 'ro', lazy => 1, builder => '_set_step_width' );

  #when estimating end times what additional error should be given. Set to 1 for no extra time.
  has 'time_error' => ( isa => 'Num', is => 'ro', default => 1.1 );

  method _generate_pulse () {
    $self->column->photocathode->generate_pulse( $self->column, $self->number);
  }

  method _set_step_width () {
    return ( ($self->end_time - $self->start_time) / $self->steps );
  }

  method _est_init_end_time () {
    my $t0 = $self->start_time;
    my $tf = $t0;

    my $acc = $self->column->accelerator;

    # this test is a holdover, leaving in case I want to implement a Null Accelerator
    # test should always succeed as acclerator is now a required attribute of the column
    if ($acc) {
      $tf += $acc->est_exit_time;
      $tf += ( ($self->column->length() - $acc->length()) / $acc->est_exit_vel );
    } else {
      # otherwise use given velocity
      $tf += $self->column->length() / $self->pulse->velocity;
    }

    #add 10% error factor (time will be extended later if needed)
    $tf *= $self->time_error;

    return $tf;
  }

  method propagate () {

    my $iter = 1;
    my $result = [];

    # continue to evaluate until pulse leaves column
    while ($self->pulse->location < $self->column->length) {
      warn "Segment iteration number: " . $iter++ . "\n";

      my $segment_result = $self->_evaluate_single_run();
      join_data( $result, $segment_result );
    }
    
    my $stored_data = $self->pulse->data;
    join_data( $stored_data, $result );

    # return only this propagation result
    # full data available from $pulse->data;
    return $result;

  }

  method _evaluate_single_run () {
    my $pulse      = $self->pulse;
    my $eqns       = $self->_make_diffeqs;
    my $start_time = $self->start_time;
    my $end_time   = $self->end_time;

    if ($end_time == $start_time) {
      $end_time = $self->time_error * ($self->column->length - $pulse->location) / $self->pulse->velocity;
      $self->end_time( $end_time );
    }

    #logic here allows uniform step width over multiple runs
    my $steps = int(0.5 + ($end_time - $start_time) / $self->step_width);

    #calculate the propagation on the specified time range
    my $result = ode_solver( $eqns, [ $start_time, $end_time, $steps ] );

    #update the simulation/pulse parameters from the result
    #this sets up the next run if needed
    my $end_state = $result->[-1];
    $self->start_time($end_state->[0] );
    $pulse->location( $end_state->[1] );
    $pulse->velocity( $end_state->[2] );
    $pulse->sigma_t(  $end_state->[3] );
    $pulse->sigma_z(  $end_state->[4] );
    $pulse->eta_t(    $end_state->[5] );
    $pulse->eta_z(    $end_state->[6] );
    $pulse->gamma_t(  $end_state->[7] );
    $pulse->gamma_z(  $end_state->[8] );

    return $result;
  }

  method _make_diffeqs () {

    my $pulse = $self->pulse;

    my $Ne = $self->pulse->number;
    my @init_conds = (
      $pulse->location,
      $pulse->velocity,
      $pulse->sigma_t,
      $pulse->sigma_z,
      $pulse->eta_t,
      $pulse->eta_z,
      $pulse->gamma_t,
      $pulse->gamma_z,
    );

    #get the effect of all the elements in the column
    my $elements = $self->column->elements;
    my (@M_t, @M_z, @acc_z);
    foreach my $effect (map { $_->effect } @$elements) {
      push @M_t,   $effect->[0] if $effect->[0];
      push @M_z,   $effect->[1] if $effect->[1];
      push @acc_z, $effect->[2] if $effect->[2];
    }

    ## Create DE Code Reference ##
    my $eqns = sub {

      ## Initial Conditions ##

      unless (@_) {
        return @init_conds;
      }

      ## Parameters ##

      my ($t, $z, $v, $st, $sz, $et, $ez, $gt, $gz) = @_;
      my ($dz, $dv, $dst, $dsz, $det, $dez, $dgt, $dgz);

      if ($st < 0) {
        die "Sigma_t has gone negative at z=$z, t=$t\n";
      }
      if ($sz < 0) {
        die "Sigma_z has gone negative at z=$z, t=$t\n";
      }

      my $M_t = sum map { $_->($t, $z, $v) } @M_t;
      my $M_z = sum map { $_->($t, $z, $v) } @M_z;
      my $acc_z = sum map { $_->($t, $z, $v) } @acc_z;

      #avoid "mathematical use of undef" warnings
      $M_t   ||= 0;
      $M_z   ||= 0;
      $acc_z ||= 0;

      ## Setup Differentials ##

      $dz = $v;
      $dv = $acc_z;

      $dst = 2 * $gt / me;
      $dsz = 2 * $gt / me;

      $det = - 2 * $gt * $et / ( me * $st );
      $dez = - 2 * $gz * $ez / ( me * $sz );

      $dgt = 
        ($et + ($gt**2) / $st) 
        + $Ne * (qe**2) * k / (6 * sqrt($st * pi)) * L_t(sqrt($sz/$st))
        - $M_t * $st;
      $dgz = 
        ($ez + ($gz**2) / $sz) 
        + $Ne * (qe**2) * k / (6 * sqrt($sz * pi)) * L_z(sqrt($sz/$st))
        - $M_z * $sz;

      return ($dz, $dv, $dst, $dsz, $det, $dez, $dgt, $dgz);
    };

    return $eqns;

  }

}

