BEGIN { 
    push(@INC, "./blib/lib", "./etc", "./t");
}
use MIME::ToolUtils;
use Checker;
use strict;
MIME::ToolUtils->debugging(0);

use MIME::Parser;
print STDERR "\n";

# Set the counter:
my $Counter = 0;

# Messages we know about:
my %MESSAGES = 
    (
     'ak-0696.msg' => {
	 Type=>'multipart/mixed',
	 Parts => [
		   { Type=>'text/plain',
		     Enc=>'7bit'},	
		   { Type=>'message/rfc822',
		     Enc=>'7bit'}
		   ],
     },
     'german.msg' => {
	 Type=>'text/plain',
	 Enc=>'quoted-printable',
     },
     'multi-2gifs.msg' => {
	 Type=>'multipart/mixed',
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
	 Type=>'text/plain',
     },
     );

#------------------------------------------------------------
# Check an entity for sanity:

sub check_entity {
    my ($name, $ent, $info) = @_;
    my ($type, $enc, $i);

    my $t_type = ($info->{Type} || 'text/plain');
    my $t_enc  = ($info->{Enc}  || '7bit');

    check($ent => "$name parsed");
    check(($type = $ent->head->mime_type) eq $t_type =>
	  "$name: got type $type");
    check(($enc = $ent->head->mime_encoding) eq $t_enc =>
	  "$name: got encoding $enc");
    check((-s "testout/$info->{File}") =>
	  "$name: nonzero output file $info->{File}")
	if $info->{File};
    check(((-s "testout/$info->{File}") == $info->{Size}) =>
	  "$name: expected size of $info->{Size}")
	if $info->{Size};

    for ($i = 0; $i < int(@{$info->{Parts} || []}); $i++) {
	my $part = ($ent->parts)[$i];
	check_entity("$name.$i", $part, $info->{Parts}[$i]);
    }
}

#------------------------------------------------------------
# Simple_output_path -- sample hook function, for testing

sub simple_output_path {
    my ($parser, $head) = @_;

    # Get the recommended filename:
    my $filename = $head->recommended_filename;
    if (defined($filename) && MIME::Parser::evil_name($filename)) {
	warn "Parser.t: ignoring an evil recommended filename ($filename)\n";
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
unlink <$DIR/[a-z]*>;


#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------
print "1..39\n";

my $parser;
my $entity;
my $msgno;
my $infile;
my $type;
my $enc;


#------------------------------------------------------------
note "Read a nested multipart MIME message";
#------------------------------------------------------------
$parser = new MIME::Parser;
$parser->output_dir($DIR);
$parser->output_path_hook(\&simple_output_path);
open IN, "./testin/multi-nested.msg" or die "open: $!";
$entity = $parser->read(\*IN);
check($entity => "parsed okay");

#------------------------------------------------------------
note "Check the various output files";
#------------------------------------------------------------
check((-s "$DIR/3d-vise.gif" == 419) => "vise gif okay");
check((-s "$DIR/3d-eye.gif" == 357)  => "3d-eye gif okay");
for $msgno (1..4) {
    check((-s "$DIR/message-$msgno.dat") => "message $msgno okay");
}

#------------------------------------------------------------
note "Same message, but CRLF-terminated and no output path hook";
#------------------------------------------------------------
$parser = new MIME::Parser;
$parser->output_dir($DIR);
open IN, "./testin/multi-nested2.msg" or die "open: $!";
$entity = $parser->read(\*IN);
check($entity => "parsed CRLF-terminated message okay");

#------------------------------------------------------------
# Check various messages
#------------------------------------------------------------
$parser = new MIME::Parser;
$parser->output_dir($DIR);
foreach $infile (sort keys %MESSAGES) {
    my $ent;  

    note "Parsing $infile (and checking results)...";
    open IN, "./testin/$infile" or die "open: $!";
    $ent = $parser->read(\*IN);
    close IN;
    check_entity($infile, $ent, $MESSAGES{$infile});
}

# Done!
exit(0);
1;

