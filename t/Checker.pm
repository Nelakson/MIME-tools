package Checker;

=head1 NAME

Checker - assist in writing checks

=cut

@ISA = qw(Exporter);
@EXPORT = qw(okay_if note check which);

# Last checker to be created:
my $LAST = undef;


#------------------------------
#
# Functions
#
#------------------------------

# which PROGRAM 
sub which {
    my $prog = shift;
    foreach (split ':', $ENV{PATH}) {
	return "$_/$prog" if (-x "$_/$prog");
    }
    undef;
}

# okay_if CONDITION
sub okay_if { 
    $LAST->test(@_) if $LAST;
}

# note MESSAGE...
sub note    { 
    $LAST->msg(@_) if $LAST;
}

# check CONDITION, NOTE
sub check   { 
    $LAST->test(@_) if $LAST;
}

#------------------------------
#
# Public interfave
#
#------------------------------

# new
sub new {
    shift;
    $LAST = Checker::Runtime->new(@_);
    $LAST;
}



#------------------------------------------------------------
package Checker::Runtime;
#------------------------------------------------------------

# new [OPENARGS...]
sub new {
    my $self = bless {
	Begin=>0,
	End  =>0,
	Count=>0,
    }, shift;
    $self->open(@_) if @_;
    $self;
}

# DESTROY
sub DESTROY {
    $_[0]->close;
}

# open LOGFILE
sub open {
    my ($self, $path) = @_;
    $self->{Path} = $path;
    $self->{FH} = FileHandle->new(">$path") || die "open $path: $!";
    $self;
}

# close
sub close {
    my $self = shift;
    if ($self->{FH}) {
	close($self->{FH}); 
	$self->{FH} = undef;
    }
    1;
}

# msg MESSAGE...
sub msg { 
    my $self = shift;
    my $text = join '', @_;
    $text =~ s{\n}{\n   }gm;
    $self->lprint("** ", $text, "\n");
}

# lprint MESSAGE...
sub lprint { 
    my $self = shift;
    $self->{FH} or return;
    print {$self->{FH}} @_;
}

# lfmt MESSAGE...
sub lfmt { 
    my $self = shift;
    my $p = $self->{Count};
    my $msg = join '', @_;
    $msg =~ s{^}{$p: }mg;
    $msg =~ s{\n\Z}{}g;
    $self->lprint($msg, "\n");
}

# oprint MESSAGE...
sub oprint { 
    shift;
    print STDOUT @_;
}

# print MESSAGE...
sub print { 
    my $self = shift;
    $self->lfmt(@_);
    $self->oprint(@_);
}

# begin NUMTESTS  
sub begin {
    my ($self, $n) = @_;
    $self->print("1..$n\n") unless $self->{Begin}++;
}

# end
sub end {
    my ($self) = @_;
    $self->print("END\n") unless $self->{End}++;
}

# _test BOOL, [TESTNAME]
sub _test   { 
    my ($self, $ok, $test) = @_;
    ++($self->{Count});
    my $status = ($ok ? "ok " : "not ok ") . $self->{Count};

    # Output:
    $self->oprint($status, "\n");

    # Log:
    $self->lfmt($test) if $test;
    $self->lfmt($status);
}

# test BOOL, [TESTNAME]
sub test { 
    my $self = shift;
    $self->_test(@_);
    $self->lprint("\n");       # space after tests
}

# test_eq STRING1, STRING2, [TESTNAME]
sub test_eq { 
    my ($self, $s1, $s2, $test) = @_;
    $self->_test(($s1 eq $s2), $test);
    $self->lfmt("   S1: <$s1>\n");
    $self->lfmt("   S2: <$s2>\n");
    $self->lprint("\n");       # space after tests
}

# test_eqn N1, N2, [TESTNAME]
sub test_eqn { 
    my ($self, $n1, $n2, $test) = @_;
    $self->_test(($n1 == $n2), $test);
    $self->lfmt("   N1: <$n1>\n");
    $self->lfmt("   N2: <$n2>\n");
    $self->lprint("\n");       # space after tests
}

# test_ok
sub test_ok   { 
    my $self = shift;
    $self->_test(1, "okay if here");
    $self->lprint("\n");       # space after tests
}

#------------------------------------------------------------
1;



