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
  use Physics::UEMColumn::Transform;

  use Physics::UEMColumn::Auxiliary ':all';

  has 'debug' => ( isa => 'Num', is => 'ro', default => 0);

  has 'transform' => ( isa => 'Physics::UEMColumn::Transform', is = 'ro', builder => '_make_transform' );

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
  #opts hashref passed directly to ode_solver
  has 'solver_opts' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );
  has 'need_jacobian' => ( isa => 'Bool', is => 'ro', default => 0 );

  method _make_transform () {
    return Physics::UEMColumn::Transform->new();
  }

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
      last if $self->debug;
    }
    
    my $stored_data = $self->pulse->data;
    join_data( $stored_data, $result );

    # return only this propagation result
    # full data available from $pulse->data;
    return $result;

  }

  method _evaluate_single_run () {
    my $pulse		= $self->pulse;
    my @eqns		= $self->_make_diffeqs;
    my $start_time	= $self->start_time;
    my $end_time	= $self->end_time;

    if ($end_time == $start_time) {
      $end_time = $self->time_error * ($self->column->length - $pulse->location) / $self->pulse->velocity;
      $self->end_time( $end_time );
    }

    #logic here allows uniform step width over multiple runs
    my $steps = int(0.5 + ($end_time - $start_time) / $self->step_width);

    #calculate the propagation on the specified time range
    my $result;
    {
      local $SIG{__WARN__} = sub{ unless( $_[0] =~ /'ode_solver'/) { warn @_ } };
      $result = ode_solver( \@eqns, [ $start_time, $end_time, $steps ], $self->solver_opts);
    }

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
    my @return;

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
      push @M_t,   $effect->{M_t} if defined $effect->{M_t};
      push @M_z,   $effect->{M_z} if defined $effect->{M_z};
      push @acc_z, $effect->{acc} if defined $effect->{acc};
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
        warn "Sigma_t has gone negative at z=$z, t=$t\n";
        return (undef) x 8;
      }
      if ($sz < 0) {
        warn "Sigma_z has gone negative at z=$z, t=$t\n";
        return (undef) x 8;
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
      $dsz = 2 * $gz / me;

      $det = - 2 * $gt * $et / ( me * $st );
      $dez = - 2 * $gz * $ez / ( me * $sz );

      $dgt = 
        ($et + ($gt**2) / $st) 
        + $Ne * (qe**2) * 1 / (4 * pi * epsilon_0) * 1 / (6 * sqrt($st * pi)) * L_t(sqrt($sz/$st))
        - $M_t * $st;
      $dgz = 
        ($ez + ($gz**2) / $sz) 
        + $Ne * (qe**2) * 1 / (4 * pi * epsilon_0) * 1 / (6 * sqrt($sz * pi)) * L_z(sqrt($sz/$st))
        - $M_z * $sz;

      return ($dz, $dv, $dst, $dsz, $det, $dez, $dgt, $dgz);
    };

    push @return, $eqns;

    if ($self->need_jacobian) {
    
      ## Create Jacobian Code Reference ##
      my $jac = sub {

        ## Parameters ##

        my ($t, $z, $v, $st, $sz, $et, $ez, $gt, $gz) = @_;

        if ($st < 0) {
          warn "Sigma_t has gone negative at z=$z, t=$t\n";
          return (undef) x 8;
        }
        if ($sz < 0) {
          warn "Sigma_z has gone negative at z=$z, t=$t\n";
          return (undef) x 8;
        }

        my $M_t = sum map { $_->($t, $z, $v) } @M_t;
        my $M_z = sum map { $_->($t, $z, $v) } @M_z;
        my $acc_z = sum map { $_->($t, $z, $v) } @acc_z;

        #avoid "mathematical use of undef" warnings
        $M_t   ||= 0;
        $M_z   ||= 0;
        $acc_z ||= 0;

        ## Setup Differentials ##
        my $Cn = $Ne * (qe**2) * 1 / (4 * pi * epsilon_0) * 1 / (6 * sqrt(pi));

        my $xi = sqrt($sz/$st);
        my $L_t = L_t($xi);
        my $L_z = L_z($xi);
        my $dL_t = dL_tdxi($xi);
        my $dL_z = dL_zdxi($xi);

        my ($dxidst, $dxidsz) = (
          -$xi/(2*$st),
          1/(2*$st*$xi)
        );

        my ($ddgtdst, $ddgtdsz, $ddgzdst, $ddgzdsz) = (
          -(($gt/$st)**2) - $Cn*$L_t/(2*($st**(3/2))) + $Cn*$dxidst*$dL_t/sqrt($st) + $M_t,
          $Cn*$dxidsz*$dL_t/sqrt($st),
          $Cn*$dxidst*$dL_z/sqrt($sz),
          -(($gz/$sz)**2) - $Cn*$L_z/(2*($sz**(3/2))) + $Cn*$dxidsz*$dL_z/sqrt($sz) + $M_z
        );

        my $jacobian = [
          [0, 1, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 2 / me, 0],
          [0, 0, 0, 0, 0, 0, 0, 2 / me],
          [0, 0, 4 * $gt * $et / (me * ($st**2)), 0, - 2 * $gt / ( me * $st ), 0, - 2 * $et / ( me * $st ), 0 ],
          [0, 0, 0, 4 * $gz * $ez / (me * ($sz**2)), 0, - 2 * $gz / ( me * $sz ), 0, - 2 * $ez / ( me * $sz ) ],
          [0, 0, $ddgtdst, $ddgtdsz, 1 / $st, 0, 2 * $gt / $st, 0 ],
          [0, 0, $ddgzdst, $ddgzdsz, 0, 1 / $sz, 0, 2 * $gz / $sz ],
        ];

        my $dfdt = [
          0, 0, 0, 0, 0, 0, 0, 0
        ];
  
        return ($jacobian, $dfdt);
      };

      push @return, $jac;
    }

    return @return;

  }

}

