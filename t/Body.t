BEGIN { 
    push(@INC, "./blib/lib", "./etc", "./t");
}
use MIME::ToolUtils;
use Checker;
use strict;
config MIME::ToolUtils DEBUGGING=>0;

use MIME::Body;

# Set the counter:
my $Counter = 0;

#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------
print "1..14\n";


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
    note "Checking ", ref($body), " class";
    #------------------------------------------------------------

    $io = $body->open("w");
    check($io, "$class: opened for writing");
    $io->print("Line 1\nLine 2\nLine 3");
    $io->close;
    
    $io   = $body->open("r");
    check($io, "$class: able to open body for reading?");

    # Read all lines:
    @lines = $io->getlines;
    check((($lines[0] eq "Line 1\n") && 
	   ($lines[1] eq "Line 2\n") &&
	   ($lines[2] eq "Line 3")),
	  "$class: getlines method works?"
	  );
	  
    # Seek forward, read:
    $io->seek(3, 0);
    $io->read($buf, 3);
    check(($buf eq 'e 1'), "$class: seek(SEEK_START) plus read works?");

    # Tell, seek, and read:
    $pos = $io->tell;
    $io->seek(-5, 1);
    $pos = $io->tell;
    check($pos == 1, "$class: tell and seek(SEEK_CUR) works?");
    $io->read($buf, 5);
    check(($buf eq 'ine 1'), "$class: seek(SEEK_CUR) plus read works?");

    # Read all lines, one at a time:
    @lines = ();
    $io->seek(0, 0);
    while ($line = $io->getline()) {
	push @lines, $line;
    }
    check((($lines[0] eq "Line 1\n") && 
	   ($lines[1] eq "Line 2\n") &&
	   ($lines[2] eq "Line 3")),
	  "$class: getline works?"
	  );

    # Done!
    $io->close;
}
    
# Done!
exit(0);
1;

