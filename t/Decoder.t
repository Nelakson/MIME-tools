use lib "./blib/lib", "./t";

use MIME::Tools;
use MIME::Decoder;
config MIME::Tools QUIET=>1;

# config MIME::Tools DEBUGGING=>1;
use Checker;

#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------

# Is gzip available?  Quick and dirty test:
my $has_gzip = which('gzip');
if ($has_gzip) {
   require MIME::Decoder::Gzip64;
   install MIME::Decoder::Gzip64 'x-gzip64';
}

# Get list of encodings we think we provide:
my @encodings = ('base64',
		 'quoted-printable',
		 '7bit',
		 '8bit',
		 'binary',
		 ($has_gzip ? 'x-gzip64' : ()),
		 'x-uuencode');

# Create checker:
my $T = new Checker "./testout/Decoder.tlog";
$T->begin(scalar(@encodings));

# Report what tests we may be skipping:
$T->msg($has_gzip 
	? "Using gzip: $has_gzip"
	: "No gzip: skipping x-gzip64 test");

# Test each encoding in turn:
my ($e, $eno) = (undef, 0);
foreach $e (@encodings) {
    ++$eno;
    my $decoder = new MIME::Decoder $e;
    $decoder or next;
 
    $T->msg("Encoding/decoding of $e");
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
    if ($e =~ /^(base64|quoted-printable|binary|x-gzip64|x-uuencode)$/i) {
	$T->test(((-s $infile) == (-s $decfile)),
		  "size of $infile == size of $decfile");
    }
    else {
	$T->test_ok;
    }
}

# Done!
$T->end;
exit(0);
1;





