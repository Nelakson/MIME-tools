use lib "./blib/lib", "./t";

use strict;
use Checker;

use MIME::Body;
use MIME::Tools;
config MIME::Tools DEBUGGING=>0;

#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------

# Create checker:
my $T = new Checker "./testout/Body.tlog";
$T->begin(18);

# Check bodies:
my $sbody = new MIME::Body::Scalar;
my $fbody = new MIME::Body::File "./testout/fbody";
my $buf;
my @lines;
my $line;
my $body;
my $pos;
foreach $body ($sbody, $fbody) {
    my $io;
    my $class = ref($body);

    #------------------------------------------------------------
    $T->msg("Checking class: ", ref($body));
    #------------------------------------------------------------

    # Open body for writing, and write stuff:
    $io = $body->open("w");
    $T->test($io, 
	     "$class: opened for writing");
    $io->print("Line 1\nLine 2\nLine 3");
    $io->close;
    
    # Open body for reading:
    $io = $body->open("r");
    $T->test($io, 
	     "$class: able to open body for reading?");

    # Read all lines:
    @lines = $io->getlines;
    $T->test((($lines[0] eq "Line 1\n") && 
	      ($lines[1] eq "Line 2\n") &&
	      ($lines[2] eq "Line 3")),
	     "$class: getlines method works?"
	     );
	  
    # Seek forward, read:
    $io->seek(3, 0);
    $io->read($buf, 3);
    $T->test(($buf eq 'e 1'), 
	     "$class: seek(SEEK_START) plus read works?");

    # Tell, seek, and read:
    $pos = $io->tell;
    $io->seek(-5, 1);
    $pos = $io->tell;
    $T->test($pos == 1, 
	     "$class: tell and seek(SEEK_CUR) works?");

    $io->read($buf, 5);
    $T->test(($buf eq 'ine 1'), 
	     "$class: seek(SEEK_CUR) plus read works?");

    # Read all lines, one at a time:
    @lines = ();
    $io->seek(0, 0);
    while ($line = $io->getline()) { push @lines, $line }
    $T->test((($lines[0] eq "Line 1\n") &&
	      ($lines[1] eq "Line 2\n") &&
	      ($lines[2] eq "Line 3")),
	     "$class: getline works?"
	     );
    
    # Done!
    $io->close;


    # Slurp lines:
    @lines = $body->as_lines;
    $T->test((($lines[0] eq "Line 1\n") &&
	      ($lines[1] eq "Line 2\n") &&
	      ($lines[2] eq "Line 3")),
	     "$class: as_lines works?"
	     );

    # Slurp string:
    my $str = $body->as_string;
    $T->test(($str eq "Line 1\nLine 2\nLine 3"),
	     "$class: as_string works?");
}
    
# Done!
$T->end;
exit(0);
1;

