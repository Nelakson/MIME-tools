use lib "./blib/lib", "./t";

use MIME::Entity;
use MIME::Parser;
use Checker;
use strict;

# MIME::ToolUtils->emulate_tmpfile("NO");


my $top;
my $attach;
my $io;
my $line;
my $LINE;
my $part;
my $parser;
my $oldfh;
my $gif_real;
my $gif_this;

#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------

# Create checker:
my $T = new Checker "./testout/Entity.tlog";
$T->begin(17);

#------------------------------------------------------------
note "Create an entity";
#------------------------------------------------------------

# Create the top-level, and set up the mail headers in a couple
# of different ways:
$top = build MIME::Entity Type  => "multipart/mixed",
	                  -From => "me\@myhost.com",
	                  -To   => "you\@yourhost.com";
$top->head->add('subject', "Hello, nurse!");
$top->preamble([]);
$top->epilogue([]);

# Attachment #0: a simple text document: 
attach $top  Path=>"./testin/short.txt";

# Attachment #1: a GIF file:
attach $top  Path        => "./testin/mime-sm.gif",
             Type        => "image/gif",
             Encoding    => "base64",
	     Disposition => "attachment";

# Attachment #2: a document we'll create manually:
$attach = new MIME::Entity;
$attach->head(new MIME::Head ["X-Origin: fake\n",
			      "Content-transfer-encoding: quoted-printable\n",
			      "Content-type: text/plain\n"]);
$attach->bodyhandle(new MIME::Body::Scalar);
$io = $attach->bodyhandle->open("w");
$io->print(<<EOF
This  is the first line.
This is the middle.
This is the last.
EOF
);
$io->close;
$top->add_part($attach);

# Attachment #3: a document we'll create, not-so-manually:
$LINE = "This is the first and last line, with no CR at the end.";
$attach = attach $top Data=>$LINE;

$T->test("here", 
	 "built a message");
unlink <testout/entity.msg*>;

#------------------------------------------------------------
note "Check body";
#------------------------------------------------------------
my $bodylines = $top->parts(0)->body;
$T->test($bodylines > 0, "old-style body call ok");
my $preamble_len = length(join '', @{$top->preamble || []});
my $epilogue_len = length(join '', @{$top->epilogue || []});

#------------------------------------------------------------
note "Output msg1 to explicit filehandle glob";
#------------------------------------------------------------
open TMP, ">testout/entity.msg1" or die "open: $!";
$top->print(\*TMP);
close TMP;
$T->test((-s "testout/entity.msg1"), "wrote msg1 to filehandle glob");

#------------------------------------------------------------
note "Output msg2 to selected filehandle";
#------------------------------------------------------------
open TMP, ">testout/entity.msg2" or die "open: $!";
$oldfh = select TMP;
$top->print;
select $oldfh;
close TMP;
$T->test((-s "testout/entity.msg2"), "write msg2 to selected filehandle");

#------------------------------------------------------------
note "Compare";
#------------------------------------------------------------
# Same?
$T->test(((-s "testout/entity.msg1") == (-s "testout/entity.msg2")),
	"message files are same length");

#------------------------------------------------------------
note "Parse it back in, to check syntax";
#------------------------------------------------------------
$parser = new MIME::Parser;
$parser->output_dir("testout");
open IN, "./testout/entity.msg1" or die "open: $!";
$top = $parser->read(\*IN);
$T->test($top, "parsed msg1 back in");

my $preamble_len2 = length(join '', @{$top->preamble || []});
my $epilogue_len2 = length(join '', @{$top->epilogue || []});
$T->test(($preamble_len == $preamble_len2), 
	"preambles match ($preamble_len == $preamble_len2)");
$T->test(($epilogue_len == $epilogue_len2), 
	"epilogues match ($epilogue_len == $epilogue_len2)");

#------------------------------------------------------------
note "Check the number of parts";
#------------------------------------------------------------
$T->test(($top->parts == 4), "number of parts is correct (4)");

#------------------------------------------------------------
note "Check attachment 1 [the GIF]";
#------------------------------------------------------------
$gif_real = (-s "./testin/mime-sm.gif");
$gif_this = (-s "./testout/mime-sm.gif");
$T->test(($gif_real == $gif_this),
	"GIF is right size (real = $gif_real, this = $gif_this)");
$part = ($top->parts)[1];
$T->test(($part->head->mime_type eq 'image/gif'), 
	"GIF has correct MIME type");

#------------------------------------------------------------
note "Check attachment 3 [the short message]";
#------------------------------------------------------------
$part = ($top->parts)[3];
$io = $part->bodyhandle->open("r");
$line = ($io->getline);
$io->close;
$T->test(($line eq $LINE), 
	"getline gets correct value (IO = $io, <$line>, <$LINE>)");
$T->test(($part->head->mime_type eq 'text/plain'), 
	"MIME type okay");
$T->test(($part->head->mime_encoding eq '7bit'),
	"MIME encoding okay");

#------------------------------------------------------------
note "Write it out, and compare";
#------------------------------------------------------------
open TMP, ">testout/entity.msg3" or die "open: $!";
$top->print(\*TMP);
close TMP;
$T->test(((-s "testout/entity.msg2") == (-s "testout/entity.msg3")),
	"msg2 same size as msg3");

#------------------------------------------------------------
note "Duplicate";
#------------------------------------------------------------
my $dup = $top->dup;
open TMP, ">testout/entity.dup3" or die "open: $!";
$dup->print(\*TMP);
close TMP;
my $msg3_s = -s "testout/entity.msg3";
my $dup3_s = -s "testout/entity.dup3";
$T->test(($msg3_s == $dup3_s),
	"msg3 size ($msg3_s) is same as dup3 size ($dup3_s)");

#------------------------------------------------------------
note "Test signing";
#------------------------------------------------------------
$top->sign(File=>"./testin/sig");
$top->remove_sig;
$top->sign(File=>"./testin/sig2", Remove=>56);
$top->sign(File=>"./testin/sig3");

#------------------------------------------------------------
note "Write it out again, after synching";
#------------------------------------------------------------
$top->sync_headers(Nonstandard=>'ERASE',
		   Length=>'COMPUTE');	
open TMP, ">testout/entity.msg4" or die "open: $!";
$top->print(\*TMP);
close TMP;

#------------------------------------------------------------
note "Purge the files";
#------------------------------------------------------------
$top->purge;
$T->test((! -e "./testout/mime-sm.gif"), "purge worked");

# Done!
exit(0);
1;




