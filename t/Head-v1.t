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
print STDERR "\n";

#------------------------------------------------------------
note "Read a bogus file (this had better fail...)";
#------------------------------------------------------------
my $head = MIME::Head->from_file('BLAHBLAH');
check(!$head => "read failed, as it should have");

#------------------------------------------------------------
note "Parse in the crlf.hdr file:";
#------------------------------------------------------------
($head = MIME::Head->from_file('./testin/crlf.hdr'))
    or die "couldn't parse input";  # stop now
check($head => "read okay");

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
check(($parsed eq $actual) => "all the fields check out");

#------------------------------------------------------------
note "Could we get() the 'subject'?";
#------------------------------------------------------------
my $subject = $head->get('subject');
check($subject eq 'EMPLOYMENT: CHICAGO, IL UNIX/CGI/WEB/DBASE');

#------------------------------------------------------------
note "Could we set() the 'Subject', and get it as 'SUBJECT'?";
#------------------------------------------------------------
my $newsubject = 'Hellooooooo, nurse!';
$head->set('Subject', $newsubject);
$subject = $head->get('SUBJECT');
check($subject eq $newsubject);

#------------------------------------------------------------
note "Does the exists() method work?";
#------------------------------------------------------------
check($head->exists('NNTP-Posting-Host') and
      $head->exists('nntp-POSTING-HOST') and
      !($head->exists('Doesnt-Exist')));

#------------------------------------------------------------
note "Create a custom structured field, and extract parameters";
#------------------------------------------------------------
$head->set('X-Files', 
	'default ; (comment 1) name="X Files Test"(comment2); LENgth=60 ;setting="6"');
my $params = $head->params('X-Files');
check($params);
check($$params{_}         eq 'default');
check($$params{'name'}    eq 'X Files Test');
check($$params{'length'}  eq '60');
check($$params{'setting'} eq '6');

# Done!
exit(0);
1;





