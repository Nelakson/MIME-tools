use lib "./blib/lib", "./t";
use MIME::ToolUtils qw(tmpopen);
use Checker;
use FileHandle;

# Create checker:
my $ntests = 800;
my $T = new Checker "./testout/Tmpfile.tlog";
$T->begin($ntests);

# Run the test:
my $i;
for ($i = 0; $i < $ntests; $i++) {
### print STDERR "+";
    STDERR->flush;
    leak();
}

# leak
sub leak {
    my $TMP = (tmpopen() || die "tmpopen: $!");
    print $TMP "Hello!\nGoodbye!\n";
    seek($TMP, 0, 0);
    my $line = <$TMP>;
    $T->test(($line eq "Hello!\n"));
    # no close! hopefully, the destructor will handle it!
}




1;
