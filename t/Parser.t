use lib "./blib/lib", "./t";
use MIME::Tools;

use Checker;
use Globby;

use strict;
config MIME::Tools DEBUGGING=>0;

use MIME::Parser;

# Set the counter, for filenames:
my $Counter = 0;

# Messages we know about:
my %MESSAGES = 
    (

     'ak-0696.msg, try 0 (no nesting)' => {
	 Infile=>'ak-0696.msg',
 	 Nested=>0,	
	 Type  =>'multipart/mixed',
	 Parts => [
		   { Type=>'text/plain',
		     Enc=>'7bit'},	
		   { Type=>'message/rfc822',
		     Enc=>'7bit'}
		   ],
     },

     'ak-0696.msg, try 1 (nesting=NEST)' => {
	 Infile=>'ak-0696.msg',
 	 Nested=>'NEST',
	 Type  =>'multipart/mixed',
	 Parts => [
		   { Type=>'text/plain',
		     Enc=>'7bit'},	
		   { Type=>'message/rfc822',
		     Enc=>'7bit'}
		   ],
     },

     'ak-0696.msg, try 2 (nesting=REPLACE)' => {
	 Infile=>'ak-0696.msg',
 	 Nested=>'REPLACE',
	 Type  =>'multipart/mixed',
	 Parts => [
		   { Type=>'text/plain',
		     Enc=>'7bit'},	
		   { Type=>'text/plain',
		     Enc=>'quoted-printable'}
		   ],
     },

     'german.msg' => {
	 Infile=>'german.msg',
 	 Nested=>0,
	 Type  =>'text/plain',
	 Enc   =>'quoted-printable',
     },

     'multi-2gifs.msg' => {
	 Infile=>'multi-2gifs.msg',
 	 Nested=>0,
	 Type  =>'multipart/mixed',
	 Parts => [
		   { Type=>'text/plain',
		     Enc=>'7bit'},	
		   { Type=>'image/gif',
		     Enc=>'base64',
		     File=>'3d-compress.gif',
		     Size=>419},
		   { Type=>'image/gif',
		     Enc=>'base64',
		     File=>'3d-eye.gif',
		     Size=>357},
		   ],
     },

     'simple.msg' => {
	 Infile=>'simple.msg',
 	 Nested=>0,
	 Type  =>'text/plain',
     },

     );

#------------------------------------------------------------
# Check an entity for sanity:

sub check_entity {
    my ($name, $ent, $info) = @_;
    my ($type, $enc, $i);

    my $t_type = ($info->{Type} || 'text/plain');
    my $t_enc  = ($info->{Enc}  || '7bit');

    check($ent, "$name parsed");
    check((($type = $ent->head->mime_type || '') eq $t_type),
	  "$name: verified type $t_type?")
	if $ent;
    check((($enc = $ent->head->mime_encoding || '') eq $t_enc),
	  "$name: verified encoding $t_enc?")
	if $ent;
    check((-s "testout/$info->{File}"),
	  "$name: nonzero output file $info->{File}?")
	if ($ent and $info->{File});
    check(((-s "testout/$info->{File}") == $info->{Size}),
	  "$name: got expected size of $info->{Size}?")
	if ($ent and $info->{Size});

    if ($type =~ /multipart/) {
	for ($i = 0; $i < int(@{$info->{Parts} || []}); $i++) {
	    my $part = ($ent ? ($ent->parts)[$i] : undef);
	    check_entity("$name.$i", $part, $info->{Parts}[$i]);
	}
    }
}

#------------------------------------------------------------
# Simple_output_path -- sample hook function, for testing

sub simple_output_path {
    my ($parser, $head) = @_;

    # Get the recommended filename:
    my $filename = $head->recommended_filename;
    if (defined($filename) && $parser->evil_filename($filename)) {
	note "Parser.t: ignoring an evil recommended filename ($filename)";
	$filename = undef;      # forget it: it was evil
    }
    if (!defined($filename)) {  # either no name or an evil name
	++$Counter;
	$filename = "message-$Counter.dat";
    }

    # Get the output filename:
    my $outdir = $parser->output_dir;
    "$outdir/$filename";
}

# Check and clear the output directory:
my $DIR = "./testout";
((-d $DIR) && (-w $DIR)) or die "no output directory $DIR";
unlink globby("$DIR/[a-z]*");


#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------

# Create checker:
my $T = new Checker "./testout/Parser.tlog";
$T->begin(61);

my $parser;
my $entity;
my $msgno;
my $infile;
my $type;
my $enc;


#------------------------------------------------------------
note "Create a parser";
#------------------------------------------------------------
$parser = new MIME::Parser;
$parser->output_dir($DIR);
{
    local($^W) = 0;
    $parser->output_path_hook(\&simple_output_path);
}

#------------------------------------------------------------
note "Read a nested multipart MIME message";
#------------------------------------------------------------
open IN, "./testin/multi-nested.msg" or die "open: $!";
$entity = $parser->read(\*IN);
check($entity, "parse of nested multipart");

#------------------------------------------------------------
note "Check the various output files";
#------------------------------------------------------------
check((-s "$DIR/3d-vise.gif" == 419), "vise gif");
check((-s "$DIR/3d-eye.gif" == 357) , "3d-eye gif");
for $msgno (1..4) {
    check((-s "$DIR/message-$msgno.dat"), "message $msgno");
}

#------------------------------------------------------------
note "Same message, but CRLF-terminated and no output path hook";
#------------------------------------------------------------
$parser = new MIME::Parser;
{ local $^W = undef;
$parser->output_dir($DIR);
open IN, "./testin/multi-nested2.msg" or die "open: $!";
$entity = $parser->read(\*IN);
check($entity, "parse of CRLF-terminated message");
}

#------------------------------------------------------------
note "Read a simple in-core MIME message, three ways";
#------------------------------------------------------------
my $data_scalar = <<EOF;
Content-type: text/html

<H1>This is test one.</H1>

EOF
my $data_scalarref = \$data_scalar;
my $data_arrayref  = [ map { "$_\n" } (split "\n", $data_scalar) ];
my $data_test;

$parser->output_to_core('ALL');
foreach $data_test ($data_scalar, $data_scalarref, $data_arrayref) {
    $entity = $parser->parse_data($data_test);
    check(($entity and $entity->head->mime_type eq 'text/html') ,
	((ref($data_test)||'NO') . "-REF"));
}
$parser->output_to_core('NONE');


#------------------------------------------------------------
note "Simple message, in two parts";
#------------------------------------------------------------
$entity = $parser->parse_two("./testin/simple.msgh", "./testin/simple.msgb");
my $es = ($entity ? $entity->head->get('subject',0) : '');
check(($es =~ /^Request for Leave$/),
      "parse of 2-part simple message (subj <$es>)");

#------------------------------------------------------------
note "Check various messages";
#------------------------------------------------------------
$parser = new MIME::Parser;
$parser->output_dir($DIR);
my $message;
foreach $message (sort keys %MESSAGES) {
    my $ent;  
 
    # Set options:
    $parser->parse_nested_messages($MESSAGES{$message}{Nested});

    # Parse:
    note "Parsing/checking $message...";
    open IN, "./testin/$MESSAGES{$message}{Infile}" or die "open: $!";
    $ent = eval { $parser->read(\*IN) };
    close IN;
    check_entity($MESSAGES{$message}{Infile}, $ent, $MESSAGES{$message});
}

# Done!
exit(0);
1;


