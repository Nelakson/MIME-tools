BEGIN { 
    push(@INC, "./blib/lib", "./etc", "./t");
}
use MIME::Head;
use Checker;

#------------------------------------------------------------
# BEGIN
#------------------------------------------------------------
print STDERR "\n";
print "1..12\n";


#------------------------------------------------------------
note "Read a bogus file (this had better fail...)";
#------------------------------------------------------------
my $head = MIME::Head->from_file('BLAHBLAH');
check(!$head);

#------------------------------------------------------------
note "Parse in the crlf.hdr file:";
#------------------------------------------------------------
($head = MIME::Head->from_file('./testin/crlf.hdr'))
    or die "couldn't parse input";  # stop now
check('HERE');

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
		 message-id
		 nntp-posting-host
		 mime-version
		 content-type
		 content-transfer-encoding
		 x-mailer
		 x-url
		 );
push(@actuals, "From ");
my $actual = join '|', sort( map {lc($_)} @actuals);
my $parsed = join '|', sort( map {lc($_)} $head->tags);
check($parsed eq $actual);

#------------------------------------------------------------
note "Could we get() the 'subject'? (it'll end in \\r\\n)";
#------------------------------------------------------------
my $subject;
($subject) = ($head->get('subject',0));    # force array context, see if okay
note("subject = ", length($subject));
check($subject eq "EMPLOYMENT: CHICAGO, IL UNIX/CGI/WEB/DBASE\r\n");

#------------------------------------------------------------
note "Could we set() the 'Subject', and get it as 'SUBJECT'?";
#------------------------------------------------------------
my $newsubject = "Hellooooooo, nurse!\r\n";
$head->replace('Subject', $newsubject);
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
$head->set('X-Files', 'default ; name="X Files Test"; LENgth=60 ;setting="6"');
my $params = $head->params('X-Files');
check($params);
check($$params{_}         eq 'default');
check($$params{'name'}    eq 'X Files Test');
check($$params{'length'}  eq '60');
check($$params{'setting'} eq '6');

#------------------------------------------------------------
note "Output to a desired file";
#------------------------------------------------------------
open TMP, ">./testout/tmp.head" or die "open: $!";
$head->print(\*TMP);
close TMP;
check((-s "./testout/tmp.head") > 50);      # looks okay

# Done!
exit(0);
1;





