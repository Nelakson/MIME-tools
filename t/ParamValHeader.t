use lib "./t";
use MIME::Head;
use MIME::Field::ParamVal;
use MIME::Tools;

#MIME::Tools->debugging(0);

use ExtUtils::TBone;

#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------

# Create checker:
my $T = typical ExtUtils::TBone;
$T->begin(4 + 3 + 4);

#------------------------------------------------------------
$T->msg("Parse in the defang1.hdr file:");
#------------------------------------------------------------
my $head;
($head = MIME::Head->from_file('./testin/defang1.hdr'))
    or die "couldn't parse input";  # stop now

$T->log("Read...\n".$head->as_string."\n");

$T->ok_eq($head->mime_attr('content-type._'),       "audio/x-wav");
$T->ok_eq($head->mime_attr('content-type.name'),    "bb[1].wav");

###$T->ok_eq($head->mime_attr('content-type.volume'),  "10");    ### TBD CHANGE!
$T->ok(1);

$T->ok_eq($head->mime_attr('content-type.audacity'),"very.high");

$T->ok_eq($head->mime_attr('content-type-2._'),           "message/external-body");
$T->ok_eq($head->mime_attr('content-type-2.access-type'), "URL");
$T->ok_eq($head->mime_attr('content-type-2.url'), "ftp://cs.utk.edu/pub/moore/bulk-mailer/bulk-mailer.tar");


if (1) {
    my $fieldtxt = <<EOF;
Message/Partial;
    number=2; total=3;
    id="oc=jpbe0M2Yt4s@thumper.bellcore.com"
EOF
    my $params = MIME::Field::ParamVal->parse_params($fieldtxt);
    $T->ok_eq($$params{_}, 'Message/Partial');
    $T->ok_eq($$params{'number'}, 2);
    $T->ok_eq($$params{'total'}, 3);
    $T->ok_eq($$params{'id'}, "oc=jpbe0M2Yt4s@thumper.bellcore.com");
}
$T->end;

# Done!
exit(0);
1;




