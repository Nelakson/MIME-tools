package Checker;

@ISA = qw(Exporter);
@EXPORT = qw($CHECK okay_if note check);

$Checker::CHECK = 0;

sub okay_if { 
    print( ($_[0] ? "ok\n" : "not ok\n")) 
}
sub note    { 
    print STDERR "   ### ", @_, "\n" 
}
sub check   { 
    ++$CHECK;
    my ($ok, $note) = @_;
    $note = ($note ? ": $note" : '');
    my $stat = ($ok ? 'OK ' : 'ERR');
    printf STDERR "   $stat (test %2d)$note\n", $CHECK;
    print(($ok ? "ok $CHECK\n" : "not ok $CHECK\n"));
}
1;

