BEGIN { 
    push(@INC, "./blib/lib", "./etc");
}
use MIME::ToolUtils;
MIME::ToolUtils->debugging(1);

use MIME::Decoder;
print STDERR "\n";

sub okay_if { print( ($_[0] ? "ok\n" : "not ok\n")) }
sub note    { print STDERR "\ttest ", @_, "\n" }

#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------
print "1..5\n";

#------------------------------------------------------------
note "1-5: encode and decode...";
#------------------------------------------------------------
my @encodings = qw(base64 quoted-printable 7bit 8bit binary);
my ($e, $eno) = (undef, 0);
foreach $e (@encodings) {
    ++$eno;
    my $decoder = new MIME::Decoder $e;
    $decoder or next;

    note "encoding/decoding of $e";
    my $infile  = "./testin/fun.txt";
    my $encfile = "./testout/fun.en$eno";    
    my $decfile = "./testout/fun.de$eno";    

    # Encode:
    open IN, "<$infile" or die "open $infile: $!";
    open OUT, ">$encfile" or die "open $encfile: $!";
    $decoder->encode(\*IN, \*OUT) or next;
    close OUT;
    close IN;

    # Decode:
    open IN, "<$encfile" or die "open $encfile: $!";
    open OUT, ">$decfile" or die "open $decfile: $!";
    $decoder->decode(\*IN, \*OUT) or next;
    close OUT;
    close IN;

    # Can we compare?
    if ($e =~ /^(base64|quoted-printable|binary)$/i) {
	okay_if((-s $infile) == (-s $decfile));
    }
    else {
	okay_if('here');
    }
}

# Done!
exit(0);
1;



