BEGIN { 
    push(@INC, "./blib/lib", "./etc", "./t");
}
use MIME::Entity;
use MIME::Parser;
use Checker;


#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------
print "1..12\n";
print STDERR "\n";


#------------------------------------------------------------
note "Create an entity";
#------------------------------------------------------------

# Create the top-level, and set up the mail headers:
my $top = build MIME::Entity Type=>"multipart/mixed";
$top->head->add('from',    "me\@myhost.com");
$top->head->add('to',      "you\@yourhost.com");
$top->head->add('subject', "Hello, nurse!");

# Attachment #1: a simple text document: 
attach $top  Path=>"./testin/short.txt";

# Attachment #2: a GIF file:
attach $top  Path        => "./docs/mime-sm.gif",
             Type        => "image/gif",
             Encoding    => "base64";

# Attachment #3: a document we'll create manually:
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

# Attachment #4: a document we'll create, not-so-manually:
my $LINE = "This is the first and last line, with no CR at the end.";
$attach = attach $top Data=>$LINE;

okay_if("here");
unlink <testout/entity.msg*>;

#------------------------------------------------------------
note "Output msg1 to explicit filehandle glob";
#------------------------------------------------------------
open TMP, ">testout/entity.msg1" or die "open: $!";
$top->print(\*TMP);
close TMP;
okay_if((-s "testout/entity.msg1"));

#------------------------------------------------------------
note "Output msg2 to selected filehandle";
#------------------------------------------------------------
open TMP, ">testout/entity.msg2" or die "open: $!";
my $oldfh = select TMP;
$top->print;
select $oldfh;
close TMP;
okay_if((-s "testout/entity.msg2"));

#------------------------------------------------------------
note "Compare";
#------------------------------------------------------------
# Same?
okay_if((-s "testout/entity.msg1") == (-s "testout/entity.msg2"));

#------------------------------------------------------------
note "Parse it back in, to check syntax";
#------------------------------------------------------------
my $parser = new MIME::Parser;
$parser->output_dir("testout");
open IN, "./testout/entity.msg1" or die "open: $!";
$top = $parser->read(\*IN);
okay_if($top);

#------------------------------------------------------------
note "Check the number of parts";
#------------------------------------------------------------
okay_if($top->parts == 4);

#------------------------------------------------------------
note "Check attachment 1 [the GIF]";
#------------------------------------------------------------
okay_if((-s "./docs/mime-sm.gif") == (-s "./testout/mime-sm.gif"));
my $part = ($top->parts)[1];
okay_if($part->head->mime_type eq 'image/gif');

#------------------------------------------------------------
note "Check attachment 3 [the short message]";
#------------------------------------------------------------
my $part = ($top->parts)[3];
$io = $part->bodyhandle->open("r");
my $line = ($io->getline);
$io->close;
okay_if($line eq $LINE);
okay_if($part->head->mime_type eq 'text/plain');
okay_if($part->head->mime_encoding eq '7bit');

#------------------------------------------------------------
note "Write it out, and compare";
#------------------------------------------------------------
open TMP, ">testout/entity.msg3" or die "open: $!";
$top->print(\*TMP);
close TMP;
okay_if((-s "testout/entity.msg2") == (-s "testout/entity.msg3"));

# Done!
exit(0);
1;




