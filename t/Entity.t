BEGIN { 
    push(@INC, "./blib/lib", "./etc", "./t");
}
use MIME::Entity;
use MIME::Parser;
use Checker;
use strict;

# MIME::ToolUtils->emulate_tmpfile("NO");

#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------
print "1..13\n";
print STDERR "\n";


#------------------------------------------------------------
note "Create an entity";
#------------------------------------------------------------

# Create the top-level, and set up the mail headers in a couple
# of different ways:
my $top = build MIME::Entity Type  => "multipart/mixed",
	                     -From => "me\@myhost.com",
	                     -To   => "you\@yourhost.com";
$top->head->add('subject', "Hello, nurse!");

# Attachment #0: a simple text document: 
attach $top  Path=>"./testin/short.txt";

# Attachment #1: a GIF file:
attach $top  Path        => "./docs/mime-sm.gif",
             Type        => "image/gif",
             Encoding    => "base64",
	     Disposition => "attachment";

# Attachment #2: a document we'll create manually:
my $attach = new MIME::Entity;
$attach->head(new MIME::Head ["X-Origin: fake\n",
			      "Content-transfer-encoding: quoted-printable\n",
			      "Content-type: text/plain\n"]);
$attach->bodyhandle(new MIME::Body::Scalar);
my $io = $attach->bodyhandle->open("w");
$io->print(<<EOF
This  is the first line.
This is the middle.
This is the last.
EOF
);
$io->close;
$top->add_part($attach);

# Attachment #3: a document we'll create, not-so-manually:
my $LINE = "This is the first and last line, with no CR at the end.";
$attach = attach $top Data=>$LINE;

check("here", "built a message");
unlink <testout/entity.msg*>;

#------------------------------------------------------------
note "Output msg1 to explicit filehandle glob";
#------------------------------------------------------------
open TMP, ">testout/entity.msg1" or die "open: $!";
$top->print(\*TMP);
close TMP;
check((-s "testout/entity.msg1"), "wrote msg1 to filehandle glob");

#------------------------------------------------------------
note "Output msg2 to selected filehandle";
#------------------------------------------------------------
open TMP, ">testout/entity.msg2" or die "open: $!";
my $oldfh = select TMP;
$top->print;
select $oldfh;
close TMP;
check((-s "testout/entity.msg2"), "write msg2 to selected filehandle");

#------------------------------------------------------------
note "Compare";
#------------------------------------------------------------
# Same?
check(((-s "testout/entity.msg1") == (-s "testout/entity.msg2")),
	"message files are same length");

#------------------------------------------------------------
note "Parse it back in, to check syntax";
#------------------------------------------------------------
my $parser = new MIME::Parser;
$parser->output_dir("testout");
open IN, "./testout/entity.msg1" or die "open: $!";
$top = $parser->read(\*IN);
check($top, "parsed msg1 back in");

#------------------------------------------------------------
note "Check the number of parts";
#------------------------------------------------------------
check(($top->parts == 4), "number of parts is correct (4)");

#------------------------------------------------------------
note "Check attachment 1 [the GIF]";
#------------------------------------------------------------
my $gif_real = (-s "./docs/mime-sm.gif");
my $gif_this = (-s "./testout/mime-sm.gif");
check(($gif_real == $gif_this),
	"GIF is right size (real = $gif_real, this = $gif_this)");
my $part = ($top->parts)[1];
check(($part->head->mime_type eq 'image/gif'), 
	"GIF has correct MIME type");

#------------------------------------------------------------
note "Check attachment 3 [the short message]";
#------------------------------------------------------------
my $part = ($top->parts)[3];
$io = $part->bodyhandle->open("r");
my $line = ($io->getline);
$io->close;
check(($line eq $LINE), 
	"getline gets correct value (IO = $io, <$line>, <$LINE>)");
check(($part->head->mime_type eq 'text/plain'), 
	"MIME type okay");
check(($part->head->mime_encoding eq '7bit'),
	"MIME encoding okay");

#------------------------------------------------------------
note "Write it out, and compare";
#------------------------------------------------------------
open TMP, ">testout/entity.msg3" or die "open: $!";
$top->print(\*TMP);
close TMP;
check(((-s "testout/entity.msg2") == (-s "testout/entity.msg3")),
	"msg2 same size as msg3");

#------------------------------------------------------------
note "Purge the files";
#------------------------------------------------------------
$top->purge;
check((! -e "./testout/mime-sm.gif"), "purge worked");

# Done!
exit(0);
1;




