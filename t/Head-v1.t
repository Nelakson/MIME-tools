BEGIN { 
    push(@INC, "./blib/lib", "./etc", "./t");
}

use MIME::ToolUtils;
use MIME::Head;
use Checker;
config MIME::ToolUtils EMULATE_VERSION=>1.0;


#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------
print "1..11\n";

#------------------------------------------------------------
note "Read a bogus file (this had better fail...)";
#------------------------------------------------------------
my $WARNS = $SIG{'__WARN__'}; $SIG{'__WARN__'} = sub { };
my $head = MIME::Head->from_file('BLAHBLAH');
check(!$head => "read of bogus file failed, as it should have?");
$SIG{'__WARN__'} = $WARNS;

#------------------------------------------------------------
note "Parse in the crlf.hdr file:";
#------------------------------------------------------------
($head = MIME::Head->from_file('./testin/crlf.hdr'))
    or die "couldn't parse input";  # stop now
check($head => "read of crlf.hdr okay?");

#------------------------------------------------------------
note "Did we get all the fields?";
#------------------------------------------------------------
my @actuals = qw(path
		 from
		 newsgroups
		 subject
		 date
		 organization
		 lines
		 mail-from
		 message-id
		 nntp-posting-host
		 mime-version
		 content-type
		 content-transfer-encoding
		 x-mailer
		 x-url
		 );
my $actual = join '|', sort @actuals;
my $parsed = join '|', sort($head->fields);
# note "Actual = $actual";
# note "Parsed = $parsed";
check(($parsed eq $actual) => "all the fields check out?");

#------------------------------------------------------------
note "Could we get() the 'subject'?";
#------------------------------------------------------------
my $subject = $head->get('subject');
check(($subject eq 'EMPLOYMENT: CHICAGO, IL UNIX/CGI/WEB/DBASE'),
      "able to get 'subject'?");
	
#------------------------------------------------------------
note "Could we set() the 'Subject', and get it as 'SUBJECT'?";
#------------------------------------------------------------
my $newsubject = 'Hellooooooo, nurse!';
$head->set('Subject', $newsubject);
$subject = $head->get('SUBJECT');
check(($subject eq $newsubject),
      "able to set 'Subject', and get as 'SUBJECT'?");

#------------------------------------------------------------
note "Does the exists() method work?";
#------------------------------------------------------------
check(($head->exists('NNTP-Posting-Host') and
       $head->exists('nntp-POSTING-HOST') and
       !($head->exists('Doesnt-Exist'))),
      "exists method working?");

#------------------------------------------------------------
note "Create a custom structured field, and extract parameters";
#------------------------------------------------------------
$head->set('X-Files', 
	'default ; (comment 1) name="X Files Test"(comment2); LENgth=60 ;setting="6"');
my $params = $head->params('X-Files');
check(($params),                                 "got params?");
check(($$params{_}         eq 'default'),        "got default param?");
check(($$params{'name'}    eq 'X Files Test'),   "got name?");
check(($$params{'length'}  eq '60'),             "got length?");
check(($$params{'setting'} eq '6'),              "got setting?");

# Done!
exit(0);
1;



