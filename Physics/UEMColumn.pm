use MooseX::Declare;

class Physics::UEMColumn {

  use Carp;
  use List::Util 'sum';

  use Math::GSLx::ODEIV2;

  use Physics::UEMColumn::Column;
  use Physics::UEMColumn::Element;
  use Physics::UEMColumn::Pulse;

  use Physics::UEMColumn::Auxiliary ':all';

  has 'pulse' => (
    isa => 'Physics::UEMColumn::Pulse',
    is => 'ro',
    required => 1,
  );

  has 'column' => ( 
    isa => 'Physics::UEMColumn::Column', 
    is => 'ro', 
    default => sub { Physics::UEMColumn::Column->new() },
  );

  has 'start_time' => ( isa => 'Num', is => 'rw', default => 0 );
  has 'end_time' => ( isa => 'Num', is => 'rw', lazy => 1, builder => '_est_end_time' );
  has 'steps' => (isa => 'Int', is => 'rw', default => 100); # this is not likely to be the number of output steps
  has 'step_width' => ( isa => 'Num', is => 'ro', lazy => 1, builder => '_set_step_width' );

  method _set_step_width () {
    return ( ($self->end_time - $self->start_time) / $self->steps );
  }

  method _est_end_time () {
    my $t0 = $self->start_time;
    my $tf = $t0;

    # search for the first acceleration element
    my (@acc) = 
      sort { $a->location <=> $b->location } 
      grep { blessed($_) eq 'Physics::UEMColumn::DCAccelerator' } 
      @{ $self->column->elements };
    my $acc = $acc[0];

    # if found use estimations from that
    if ($acc) {
      $tf += $acc->est_exit_time;
      $tf += ( ($self->column->length() - $acc->length()) / $acc->est_exit_vel );
    } else {
      # otherwise use given velocity
      $tf += $self->column->length() / $self->pulse->velocity;
    }

    #add 10% error factor (time will be extended later if needed)
    $tf *= 1.1;

    return $tf;
  }

  method propagate () {

    my $result = $self->_evaluate_single_run();
    my $stored_data = $self->pulse->data;
    
    join_data( $stored_data, $result );
    return $result;

  }

  method _evaluate_single_run () {
    my $eqns       = $self->_make_diffeqs;
    my $start_time = $self->start_time;
    my $end_time   = $self->end_time;

    #logic here allows uniform step width over multiple runs
    my $steps = int(0.5 + ($end_time - $start_time) / $self->step_width);

    my $result = ode_solver( $eqns, [ $start_time, $end_time, $steps ] );

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
        die "Sigma_t has gone negative!\n";
      }
      if ($sz < 0) {
        die "Sigma_z has gone negative!\n";
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

