use lib "./t";

use strict;
use ExtUtils::TBone;

use MIME::QuotedPrint qw(decode_qp);
use MIME::WordDecoder;

#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------

# Create checker:
my $T = typical ExtUtils::TBone;
$T->begin(5 + 5 + 5 + 2 + 6 + 5);

### Init decoders:
my %WD = (
	  ISO_8859_1_o => MIME::WordDecoder::ISO_8859->new(1),
	  US_ASCII_o   => MIME::WordDecoder::US_ASCII->new,

	  ISO_8859_1   => MIME::WordDecoder->for("ISO-8859-1"),
	  US_ASCII     => MIME::WordDecoder->for("US-ASCII"),
	  UTF_8        => MIME::WordDecoder->for("UTF-8"),
	  UTF_16       => MIME::WordDecoder->for("UTF-16"),
);


### Make sure we can test:
foreach (keys %WD) { 
    $WD{$_} or die "couldn't load test decoder '$_'\n";
}

### Test:
{
    local($/) = '';

    open CASES, "<testin/DecodeWords.dat" or die "open: $!";
    my $Cases = eval join '', <CASES>; die "$@" if "$@";
    close CASES;
	
    foreach my $case (@$Cases) {
	my $raw    = delete $case->{Raw};
	my $caseno = delete $case->{Case};
	
	my @wdnames = sort keys %$case;
	foreach my $wdname (@wdnames) {
	    
	    my $wd = $WD{$wdname};
	    
	    ### Decode it:
	    my $decoded = $wd->decode($raw);
	    my $expect = $case->{$wdname};
	    $T->ok($expect eq $decoded,
		   "Got expected value",
		   Case   => $caseno,
		   WordDecoder => $wdname,
		   Raw    => $raw,
		   Expect => $expect,
		   Actual => $decoded);
	}
    }
}    

# Done!
$T->end;
exit(0);
1;

