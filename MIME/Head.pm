package MIME::Head;


=head1 NAME

MIME::Head - MIME message header (a subclass of Mail::Header)


=head1 SYNOPSIS

Start off by requiring or using this package:

    require MIME::Head;

You can B<create> a MIME::Head object in a number of ways:

    # Create a new, empty header, and populate it manually:    
    $head = MIME::Head->new;
    $head->set('content-type', 'text/plain; charset=US-ASCII');
    $head->set('content-length', $len);
    
    # Create a new header by parsing in the STDIN stream:
    $head = MIME::Head->read(\*STDIN);
    
    # Create a new header by parsing in a file:
    $head = MIME::Head->from_file("/tmp/test.hdr");
    
    # Create a new header by running a program:
    $head = MIME::Head->from_file("cat a.hdr b.hdr |");

To get rid of all internal newlines in all fields (called B<unfolding>):

    # Get rid of all internal newlines:
    $head->unfold();

To RFC-1522-decode any Q- or B-encoded-text in the header fields:

    $head->decode();

To test whether a given field B<exists> (consider using the inherited
C<count> method instead, though: C<exists> has been deprecated, but will
continue to work even if your MailTools is old):

    # Was a "Subject:" given?
    if ($head->exists('subject')) {
        # yes, it does!
    }

To B<get the contents of a field,> either a I<specific> occurence (defaults 
to the first occurence in a scalar context) or I<all> occurences 
(in an array context):

    # Is this a reply?
    $reply = 1 if ($head->get('Subject') =~ /^Re: /);
    
    # Get receipt information:
    print "Last received from: ", $head->get('Received', 0), "\n";
    @all_received = $head->get('Received');

To B<get the first occurence> of a field as a string,
regardless of context:

    # Print the subject, or the empty string if none:
    print "Subject: ", $head->get('Subject',0), "\n";

To B<get all occurences> of a field as an array, regardless of context:

    # Too many hops?  Count 'em and see!
    if (int($head->get_all('Received')) > 5) { ...

To B<set a field> to a given string:

    # Declare this to be an HTML header:
    $head->replace('Content-type', 'text/html');

To get certain commonly-used B<MIME information>:

    # The content type (e.g., "text/html"):
    $mime_type     = $head->mime_type;
    
    # The content transfer encoding (e.g., "quoted-printable"):
    $mime_encoding = $head->mime_encoding;
    
    # The recommended filename (e.g., "choosy-moms-choose.gif"):
    $file_name     = $head->recommended_filename;
    
    # The boundary text, for multipart messages:
    $boundary      = $head->multipart_boundary;


=head1 DESCRIPTION

A class for parsing in and manipulating RFC-822 message headers, with some 
methods geared towards standard (and not so standard) MIME fields as 
specified in RFC-1521, I<Multipurpose Internet Mail Extensions>.


=head1 PUBLIC INTERFACE

=cut

#------------------------------------------------------------

require 5.001;

# Pragmas:
use strict;
use vars qw($VERSION @ISA);

# System modules:
use Carp;

# Other modules:
use Mail::Header;
use MIME::Base64;
use MIME::QuotedPrint;

# Kit modules:
use MIME::ToolUtils qw(:config :msgs);
use MIME::Field::ConTraEnc;
use MIME::Field::ContDisp;
use MIME::Field::ContType;

@ISA = qw(Mail::Header);



#------------------------------
#
# Public globals...
#
#------------------------------

# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 3.202 $, 10;

# Sanity (we put this test after our own version, for CPAN::):
$Mail::Header::VERSION >= 1.01 or confess "Need Mail::Header 1.01 or better";



#------------------------------

=head2 Creation, input, and output

=over 4

=cut

#------------------------------

#------------------------------------------------------------
# new
#------------------------------------------------------------

=item new [ARG],[OPTIONS]

I<Class method, inherited.>
Creates a new header object.  Arguments are the same as those in the 
superclass.  

=cut

sub new {
    my $class = shift;
    debug "creating new MIME::Head: $class";
    my $new = Mail::Header->new(@_);
    bless $new, $class;
}

#------------------------------------------------------------
# copy
#------------------------------------------------------------
sub copy {
    my $self = shift;
    usage "deprecated: please use the dup() method instead.";
    $self->dup();
}

#------------------------------------------------------------
# from_file
#------------------------------------------------------------

=item from_file EXPR,OPTIONS

I<Class or instance method>.
For convenience, you can use this to parse a header object in from EXPR, 
which may actually be any expression that can be sent to open() so as to 
return a readable filehandle.  The "file" will be opened, read, and then 
closed:

    # Create a new header by parsing in a file:
    my $head = MIME::Head->from_file("/tmp/test.hdr");

Since this method can function as either a class constructor I<or> 
an instance initializer, the above is exactly equivalent to:

    # Create a new header by parsing in a file:
    my $head = MIME::Head->new->from_file("/tmp/test.hdr");

On success, the object will be returned; on failure, the undefined value.

The OPTIONS are the same as in new(), and are passed into new()
if this is invoked as a class method.

B<NOTE:> This is really just a convenience front-end onto C<read()>,
provided mostly for backwards-compatibility with MIME-parser 1.0.

=cut

sub from_file {
    my ($self, $file, @opts) = @_;   # at this point, $self is inst. or class!
    my $class = ref($self) ? ref($self) : $self;

    # Parse:
    open(HDR, $file) or return error("open $file: $!");
    $self = $class->new(\*HDR, @opts);      # now, $self is instance or undef
    close(HDR);
    $self;
}


#------------------------------------------------------------
# read
#------------------------------------------------------------

=item read FILEHANDLE

I<Instance (or class) method.> 
This initiallizes a header object by reading it in from a FILEHANDLE,
until the terminating blank line is encountered.  
A syntax error or end-of-stream will also halt processing.

Supply this routine with a reference to a filehandle glob; e.g., C<\*STDIN>:

    # Create a new header by parsing in STDIN:
    $head->read(\*STDIN);

On success, the self object will be returned; on failure, a false value.

B<Note:> in the MIME world, it is perfectly legal for a header to be
empty, consisting of nothing but the terminating blank line.  Thus,
we can't just use the formula that "no tags equals error".

B<Warning:> as of the time of this writing, Mail::Header::read did not flag
either syntax errors or unexpected end-of-file conditions (an EOF
before the terminating blank line).  MIME::ParserBase takes this
into account.

=cut

sub read {
    my $self = shift;      # either instance or class!

    ref($self) or $self = $self->new;    # if used as class method, make new
    $self->Mail::Header::read(@_);       # do it!
}



#------------------------------

=back

=head2 Getting/setting fields

The following are methods related to retrieving and modifying the header 
fields.  Some are inherited from Mail::Header, but I've kept the
documentation around for convenience.

=over 4

=cut

#------------------------------


#------------------------------------------------------------
# add
#------------------------------------------------------------

=item add TAG,TEXT,[INDEX]

I<Instance method, inherited.>
Add a new occurence of the field named TAG, given by TEXT:

    # Add the trace information:    
    $head->add('Received', 'from eryq.pr.mcs.net by gonzo.net with smtp');

Normally, the new occurence will be I<appended> to the existing 
occurences.  However, if the optional INDEX argument is 0, then the 
new occurence will be I<prepended>.  If you want to be I<explicit> 
about appending, specify an INDEX of -1.

B<NOTE:> use of "BEFORE" (for index 0) or "AFTER" (for index -1)
is still allowed, but deprecated.

B<WARNING>: this method always adds new occurences; it doesn't overwrite
any existing occurences... so if you just want to I<change> the value
of a field (creating it if necessary), then you probably B<don't> want to use 
this method: consider using C<set()> instead.

=cut

sub add {
    my ($self, $tag, $text, $index) = @_;
    $tag = lc($tag);       # coerce to lowercase

    # Coerce old-style 'index' to new-style 'index':
    if (!defined($index)) {
	$index = -1;	
    }
    elsif ($index eq 'BEFORE') {
	usage "changed: index '$index' should now be given as the number 0";
	$index = 0;
    }
    elsif ($index eq 'AFTER') {
	usage "changed: index '$index' should now be given as the number -1";
	$index = -1;
    }

    # Do it!
    $self->Mail::Header::add($tag, $text, $index);
}

#------------------------------------------------------------
# add_text
#------------------------------------------------------------
# DEPRECATED, and now very inefficient.  Use replace() instead.

sub add_text {
    my ($self, $tag, $text) = @_;
    usage "deprecated: use method replace() with an index of -1 instead";

    my $old = $self->get($tag,-1);
    $old =~ s/\n$//;
    $self->replace($tag, "$old$text", -1);   
}

#------------------------------------------------------------
# decode
#------------------------------------------------------------

=item decode

I<Instance method.>
Go through all the header fields, looking for RFC-1522-style "Q"
(quoted-printable, sort of) or "B" (base64) encoding, and decode them
in-place.  Fellow Americans, you probably don't know what the hell I'm
talking about.  Europeans, Russians, et al, you probably do.  C<:-)>. 

For example, here's a valid header you might get:

      From: =?US-ASCII?Q?Keith_Moore?= <moore@cs.utk.edu>
      To: =?ISO-8859-1?Q?Keld_J=F8rn_Simonsen?= <keld@dkuug.dk>
      CC: =?ISO-8859-1?Q?Andr=E9_?= Pirard <PIRARD@vm1.ulg.ac.be>
      Subject: =?ISO-8859-1?B?SWYgeW91IGNhbiByZWFkIHRoaXMgeW8=?=
       =?ISO-8859-2?B?dSB1bmRlcnN0YW5kIHRoZSBleGFtcGxlLg==?=
       =?US-ASCII?Q?.._cool!?=

That basically decodes to (sorry, I can only approximate the
Latin characters with 7 bit sequences /o and 'e):

      From: Keith Moore <moore@cs.utk.edu>
      To: Keld J/orn Simonsen <keld@dkuug.dk>
      CC: Andr'e  Pirard <PIRARD@vm1.ulg.ac.be>
      Subject: If you can read this you understand the example... cool!

B<NOTE:> currently, the decodings are done without regard to the
character set: thus, the Q-encoding C<=F8> is simply translated to the
octet (hexadecimal C<F8>), period.  Perhaps this is a bad idea; I
honestly don't know.  Certainly, a mail I<reader> intended for humans
should use the raw (undecoded) header.  But a mail robot?  Anyway,
I'll gladly take guidance from anyone who has a
clear idea of what should happen.

B<WARNING:> the CRLF+SPACE separator that splits up long encoded words 
into shorter sequences (see the Subject: example above) gets lost
when the field is unfolded, and so decoding after unfolding causes
a spurious space to be left in the field.  
I<THEREFORE: if you're going to decode, do so BEFORE unfolding!>

This method returns the self object.

I<Thanks to Kent Boortz for providing the idea, and the baseline 
RFC-1522-decoding code!>

=cut

sub decode {
    my $self = shift;
    my ($tag, $i, @decoded);
    foreach $tag ($self->tags()) {
	@decoded = map { _decode_header($_) } $self->get_all($tag);
	for ($i = 0; $i < @decoded; $i++) {
	    $self->replace($tag, $decoded[$i], $i);
	}
    }
    $self;
}

# _decode_header STRING
#     Private: used by decode() to decode a single header field.
sub _decode_header {
    my $str = shift;

    # Collapse boundaries between adjacent encoded words:
    $str =~ s/(\?=)\r?\n[ \t](=\?)/$1$2/g;

    # Decode:
    $str =~ s/=\?([^\?]+)\?q\?([^\? ]+)\?=/_decode_Q_text($1,$2)/gie;
    $str =~ s/=\?([^\?]+)\?b\?([^\? ]+)\?=/_decode_B_text($1,$2)/gie;
    $str;
}

# _decode_Q_text CHARSET,STRING
#     Private: used by _decode_header() to decode "Q" encoding, which is
#     almost, but not exactly, quoted-printable.  :-P
sub _decode_Q_text {
    my ($enc, $str) = @_;
    $str =~ s/=([\da-fA-F]{2})/pack("C", hex($1))/ge;  # RFC-1522, Q rule 1
    $str =~ s/_/\x20/g;                                # RFC-1522, Q rule 2
    $str;
}

# _decode_B_text CHARSET,STRING
#     Private: used by _decode_header() to decode "B" encoding.
sub _decode_B_text {
    my ($enc, $str) = @_;
    decode_base64($str);
}


#------------------------------------------------------------
# delete
#------------------------------------------------------------

=item delete TAG,[INDEX]

I<Instance method, inherited.>
Delete all occurences of the field named TAG.

    # Remove all the MIME information:
    $head->delete('MIME-Version');
    $head->delete('Content-type');
    $head->delete('Content-transfer-encoding');
    $head->delete('Content-disposition');

=cut

### Inherited


#------------------------------------------------------------
# exists
#------------------------------------------------------------

=item exists TAG

I<Instance method, inherited, DEPRECATED.>
Returns whether a given field exists:

    # Was a "Subject:" given?
    if ($head->exists('subject')) {
        # yes, it does!
    }

The TAG is treated in a case-insensitive manner.
This method returns some false value if the field doesn't exist,
and some true value if it does.

B<DEPRECATED> by Mail::Header v.1.06.  If you have a recent copy of
Mail::Header, you should use count() instead, which returns equivalent 
boolean values.  MIME::Head::exists uses count() if it's available,
but exists() is currently kept without warning for backwards-compatibility
(since we don't want to demand that you have count()).

=cut

sub exists {    
    if (defined(&Mail::Header::count)) {
	shift->count(@_);
    }
    else {
	shift->Mail::Header::exists(@_);
    }
}

#------------------------------------------------------------
# fields
#------------------------------------------------------------
# DEPRECATED.  Use tags() instead.

sub fields {
    my $self = shift;
    usage "deprecated: use method tags() instead.\n\t",
          "WARNING: downcasing is no longer done automatically!";
    if ($CONFIG{EMULATE_VERSION} < 2.0) {       # we used to downcase...
	return (map {lc($_)} $self->tags);
    }
    $self->tags;
}

#------------------------------------------------------------
# get
#------------------------------------------------------------

=item get TAG,[INDEX]

I<Instance method, inherited.>  
Get the contents of field TAG.

If a B<numeric INDEX> is given, returns the occurence at that index, 
or undef if not present:

    # Print the first 'Received:' entry (explicitly):
    print "Most recent: ", $head->get('received',0), "\n";
   
    # Print the last 'Received:' entry:
    print "Least recent: ", $head->get('received', -1), "\n"; 

If B<no INDEX> is given, but invoked in a B<scalar> context, then
INDEX simply defaults to 0:

    # Get the first 'Received:' entry (implicitly):
    my $most_recent = $head->get('received');

If B<no INDEX> is given, and invoked in an B<array> context, then
I<all> occurences of the field are returned:

    # Get all 'Received:' entries:
    my @all_received = $head->get('received');

B<WARNING:> I<This has changed since MIME-parser 1.x.  
You should now use the two-argument form if you want the old behavior, 
or else tweak the module to emulate version 1.0.>

=cut

sub get {
    my $self = shift;    
    if ($CONFIG{EMULATE_VERSION} < 2.0) {
	my $tag   = shift;
	my $index = shift || 0;
	my $value = $self->Mail::Header::get($tag, $index);
	$value =~ s/\r?\n$// if defined($value);
	return $value;
    }
    else {    # normal
	$self->Mail::Header::get(@_);
    }
}

#------------------------------------------------------------
# get_all
#------------------------------------------------------------

=item get_all FIELD

I<Instance method.>
Returns the list of I<all> occurences of the field, or the 
empty list if the field is not present:

    # How did it get here?
    @history = $head->get_all('Received');

B<NOTE:> I had originally experimented with having C<get()> return all 
occurences when invoked in an array context... but that causes a lot of 
accidents when you get careless and do stuff like this:

    print "\u$field: ", $head->get($field), "\n";

It also made the intuitive behaviour unclear if the INDEX argument 
was given in an array context.  So I opted for an explicit approach
to asking for all occurences.

=cut

sub get_all {
    my ($self, $tag) = @_;

    $self->exists($tag) or return ();          # empty if doesn't exist
    ( $self->Mail::Header::get($tag) );
}

#------------------------------------------------------------
# original_text
#------------------------------------------------------------

=item original_text

I<Instance method.>
Recover the original text that was read() in to create this object:

    print "PARSED FROM:\n", $head->original_text;    

B<WARNING:> does no such thing now.  Just returns a reasonable
approximation of that text.  Think of it as nothing more than a poorly-named
C<as_string()> method, which outputs the header fields in the order received.
Provided for backwards-compatibility only.

This method depends on Mail::Header::header returning the information in 
the proper order.

=cut
    
sub original_text {
    my $self = shift;    
    # Be real careful, here... we must have newlines!  
    join('', map { /\n$/ ? $_ : "$_\n" } @{$self->header});
}


#------------------------------------------------------------
# print
#------------------------------------------------------------

=item print [FILEHANDLE]

I<Instance method, inherited.>
Print the header out to the given filehandle.

=cut

### Inherited


#------------------------------------------------------------
# set
#------------------------------------------------------------

=item set TAG,TEXT

I<Instance method.>
Set the field named TAG to [the single occurence given by the TEXT:

    # Set the MIME type:
    $head->set('content-type', 'text/html');
    
The TAG is treated in a case-insensitive manner.

B<DEPRECATED.>  Use replace() instead.

=cut

sub set {
    my $self = shift;
    usage "deprecated: use the replace() method instead.";
    $self->replace(@_);
}

#------------------------------------------------------------
# unfold
#------------------------------------------------------------

=item unfold [FIELD]

I<Instance method, inherited.>
Unfold the text of all occurences of the given FIELD.  
If the FIELD is omitted, I<all> fields are unfolded.

"Unfolding" is the act of removing all newlines.

    $head->unfold;

Returns the "self" object.

=cut

### Inherited


#------------------------------------------------------------

=back

=head2 MIME-specific methods

All of the following methods extract information from the following fields:

    Content-type
    Content-transfer-encoding
    Content-disposition

Be aware that they do not just return the raw contents of those fields,
and in some cases they will fill in sensible (I hope) default values.
Use C<get()> if you need to grab and process the raw field text.

B<NOTE:> some of these methods are provided both as a convenience and
for backwards-compatibility only, while others (like
recommended_filename()) I<really do have to be in MIME::Head to work
properly,> since they look for their value in more than one field.
However, if you know that a value is restricted to a single
field, you should really use the Mail::Field interface to get it.

=over 4

=cut

#------------------------------------------------------------


#------------------------------------------------------------
# params TAG
#------------------------------------------------------------
# Extract parameter info from a structured field, and return
# it as a hash reference.  
#
# DEPRECATED.  Provided for 1.0 compatibility only!
# Use the new MIME::Field interface classes (subclasses of Mail::Field).  

sub params {
    my ($self, $tag) = @_;
    usage "deprecated: use the MIME::Field interface classes from now on!";
    return MIME::Field::ParamVal->parse_params($self->get($tag,0));     
}

#------------------------------------------------------------
# mime_encoding
#------------------------------------------------------------

=item mime_encoding

I<Instance method.>
Try I<real hard> to determine the content transfer encoding
(e.g., C<"base64">, C<"binary">), which is returned in all-lowercase.

If no encoding could be found, the default of C<"7bit"> is returned.  
I quote from RFC-1521 section 5:

    This is the default value -- that is, "Content-Transfer-Encoding: 7BIT" 
    is assumed if the Content-Transfer-Encoding header field is not present.

=cut

sub mime_encoding {
    my $self = shift;

    # Get the field object:
    my $field = Mail::Field->extract('content-transfer-encoding', $self, 0)
	|| return '7bit';            # no field
    $field->encoding || '7bit';      # no value!
}

#------------------------------------------------------------
# mime_type 
#------------------------------------------------------------

=item mime_type

I<Instance method.>
Try C<real hard> to determine the content type (e.g., C<"text/plain">,
C<"image/gif">, C<"x-weird-type">, which is returned in all-lowercase.  

If no content type could be found, the default of C<"text/plain"> 
is returned.  I quote from RFC-1521 section 7.1:

    The default Content-Type for Internet mail is 
    "text/plain; charset=us-ascii".

=cut

sub mime_type {
    my $self = shift;

    # Get the field object:
    my $field = Mail::Field->extract('content-type', $self, 0) 
	|| return 'text/plain';             # default
    $field->type;
}

#------------------------------------------------------------
# multipart_boundary
#------------------------------------------------------------

=item multipart_boundary

I<Instance method.>
If this is a header for a multipart message, return the 
"encapsulation boundary" used to separate the parts.  The boundary
is returned exactly as given in the C<Content-type:> field; that
is, the leading double-hyphen (C<-->) is I<not> prepended.

(Well, I<almost> exactly... from RFC-1521:

   (If a boundary appears to end with white space, the white space 
   must be presumed to have been added by a gateway, and must be deleted.)  

so we oblige and remove any trailing spaces.)

Returns undef (B<not> the empty string) if either the message is not
multipart, if there is no specified boundary, or if the boundary is
illegal (e.g., if it is empty after all trailing whitespace has been
removed).

=cut

sub multipart_boundary {
    my $self = shift;

    # Get the field object:
    my $field = Mail::Field->extract('content-type', $self, 0) || return undef;
    my $value = $field->multipart_boundary;
    ($value eq '') ? undef : $value;
}

#------------------------------------------------------------
# recommended_filename
#------------------------------------------------------------

=item recommended_filename

I<Instance method.>
Return the recommended external filename.  This is used when
extracting the data from the MIME stream.

Returns undef if no filename could be suggested.

=cut

sub recommended_filename {
    my $self = shift;
    my ($field, $value);

    # Start by trying to get 'filename' from the 'content-disposition':
    if ($field = Mail::Field->extract('content-disposition', $self, 0)) {
	return $value if (($value = $field->filename) ne '');
    }

    # No?  Okay, try to get 'name' from the 'content-type':
    if ($field = Mail::Field->extract('content-type', $self, 0)) {
	return $value if (($value = $field->name) ne '');
    }

    # Sorry:
    undef;
}


#------------------------------------------------------------

=back

=head2 Compatibility tweaks

=over 4

=cut

#------------------------------------------------------------
# tweak_FROM_parsing
#------------------------------------------------------------
# DEPRECATED.  Use the inherited mail_from() class method now.

sub tweak_FROM_parsing {
    my $self = shift;
    usage "deprecated.  Use mail_from() instead.";
    $self->mail_from(@_);
}


#------------------------------------------------------------

=back


=head1 NOTES

=head2 Design issues

=over 4

=item Why have separate objects for the entity, head, and body?

See the documentation for the MIME-parser distribution
for the rationale behind this decision.


=item Why assume that MIME headers are email headers?

I quote from Achim Bohnet, who gave feedback on v.1.9 (I think
he's using the word I<header> where I would use I<field>; e.g.,
to refer to "Subject:", "Content-type:", etc.):

    There is also IMHO no requirement [for] MIME::Heads to look 
    like [email] headers; so to speak, the MIME::Head [simply stores] 
    the attributes of a complex object, e.g.:

        new MIME::Head type => "text/plain",
                       charset => ...,
                       disposition => ..., ... ;

I agree in principle, but (alas and dammit) RFC-1521 says otherwise.
RFC-1521 [MIME] headers are a syntactic subset of RFC-822 [email] headers.
Perhaps a better name for these modules would be RFC1521:: instead of
MIME::, but we're a little beyond that stage now.

In my mind's eye, I see an abstract class, call it MIME::Attrs, which does
what Achim suggests... so you could say:

     my $attrs = new MIME::Attrs type => "text/plain",
				 charset => ...,
                                 disposition => ..., ... ;

We could even make it a superclass of MIME::Head: that way, MIME::Head
would have to implement its interface, I<and> allow itself to be
initiallized from a MIME::Attrs object.

However, when you read RFC-1521, you begin to see how much MIME information
is organized by its presence in particular fields.  I imagine that we'd
begin to mirror the structure of RFC-1521 fields and subfields to such 
a degree that this might not give us a tremendous gain over just
having MIME::Head.


=item Why all this "occurence" and "index" jazz?  Isn't every field unique?

Aaaaaaaaaahh....no.

(This question is generic to all Mail::Header subclasses, but I'll
field it here...)

Looking at a typical mail message header, it is sooooooo tempting to just
store the fields as a hash of strings, one string per hash entry.  
Unfortunately, there's the little matter of the C<Received:> field, 
which (unlike C<From:>, C<To:>, etc.) will often have multiple 
occurences; e.g.:

    Received: from gsfc.nasa.gov by eryq.pr.mcs.net  with smtp
        (Linux Smail3.1.28.1 #5) id m0tStZ7-0007X4C; Thu, 21 Dec 95 16:34 CST
    Received: from rhine.gsfc.nasa.gov by gsfc.nasa.gov (5.65/Ultrix3.0-C)
        id AA13596; Thu, 21 Dec 95 17:20:38 -0500
    Received: (from eryq@localhost) by rhine.gsfc.nasa.gov (8.6.12/8.6.12) 
        id RAA28069; Thu, 21 Dec 1995 17:27:54 -0500
    Date: Thu, 21 Dec 1995 17:27:54 -0500
    From: Eryq <eryq@rhine.gsfc.nasa.gov>
    Message-Id: <199512212227.RAA28069@rhine.gsfc.nasa.gov>
    To: eryq@eryq.pr.mcs.net
    Subject: Stuff and things

The C<Received:> field is used for tracing message routes, and although
it's not generally used for anything other than human debugging, I
didn't want to inconvenience anyone who actually wanted to get at that
information.  

I I<also> didn't want to make this a special case; after all, who
knows what B<other> fields could have multiple occurences in the
future?  So, clearly, multiple entries had to somehow be stored
multiple times... and the different occurences had to be retrievable.

=back


=head1 WARNINGS

=head2 NEWS FLASH! 

Rejoice!  As of MIME-parser 2.0, this is a subclass of Mail::Header,
as the Maker of All Things intended.  It will continue to exist, both
for backwards-compatibility with MIME-parser 1.0, and to allow me to
tinker with MIME-specific methods.

If you are upgrading from the MIME-parser 1.0 package, and you used 
this module directly, you may notice some warnings about deprecated 
constructs in your code... all your stuff should (hopefully) 
still work... you'll just see a lot of warnings.  
B<However, you should read the B<COMPATIBILITY TWEAKS> and
B<WARNINGS> sections before installing it!> 

I have also changed terminology to match with the new MailTools distribution.
Thus, the I<name> of a field ("Subject", "From", "To", etc.) is now 
called a B<"tag"> instead of a "field".

However, I have retained all the documentation where appropriate,
even when inheriting from the Mail::Header module.  Hopefully, you won't
need to flip back and forth between man pages to use this module.



=head2 UPGRADING FROM 1.x to 2.x

=over 4

=item Altered methods/usage

There are things you must beware of if you are either a MIME-parser 
1.x user or a Mail::Header user:

=over 4

=item Modified get() behavior

In the old system, always C<get()> returned a single value, and C<get_all()>
returned multiple values: array vs. scalar context was not used.

Since Mail::Header does stuff differently, we have to obey our superclass
or we might break some of its complex methods that use C<get()>
(like C<Mail::Header::combine()>, which expects C<get()> to return 
all fields in an array context).  Unfortunately, this will break 
some of I<your> old code. 

B<For now,> you can tell the system to emulate the MIME-parser 
version 1 behavior.

B<For future compatibility,> you should, as soon as possible, modify
your code to use the two-arg form of C<get> if you want a single value, 
with the second arg being 0.  This does what the old C<get()> method did:

    print "Subject: ",  $head->get('subject',0), "\n";

=back


=item Deprecated methods/usage

The following are deprecated as of MIME-parser v.2.0.  
In many cases, they are redundant with Mail::Header subroutines
of different names:

=over 4

=item add

Use numeric index 0 for 'BEFORE' and -1 for 'AFTER'.

=item add_text

If you really need this, use the inherited C<replace()> method instead.
The current implementation is now somewhat inefficient.

=item copy

Use the inherited C<dup()> method instead.

=item fields

Use the inherited C<tags()> method instead.  B<Beware:> that method does not
automatically downcase its output for you: you will have to do that
yourself.

=item params

Use the new MIME::Field interface classes (subclasses of Mail::Field)
to access portions of a structured MIME field.

=item set

Use the inherited C<replace()> method instead.

=item tweak_FROM_parsing 

Use the inherited C<mail_from()> method instead.

=back

=back


=head1 AUTHOR

Copyright (c) 1996 by Eryq / eryq@rhine.gsfc.nasa.gov  

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.

The more-comprehensive filename extraction is courtesy of 
Lee E. Brotzman, Advanced Data Solutions.

=head1 VERSION

$Revision: 3.202 $ $Date: 1997/01/22 05:00:29 $

=cut


#------------------------------------------------------------
# Execute simple test if run as a script.
#------------------------------------------------------------
{ 
  package main; no strict;
  eval join('',<main::DATA>) || die "$@ $main::DATA" unless caller();
}
1;           # end the module
__END__


# Pick up other MIME stuff, just in case...
BEGIN { unshift @INC, ".", "./etc" }
use MIME::Head;

my $head;
$^W = 1;

print "* Reading MIME header from STDIN...\n";
$head = MIME::Head->new->read(\*STDIN) or die "couldn't parse input";
$head->print;
$head->modify(1);

print "\n* Printing original text to STDOUT...\n";
print '=' x 60, "\n";
print $head->original_text;
print '=' x 60, "\n\n";


print "* Listing all fields...\n";
print "    ", join(', ', sort $head->fields), "\n";

print "* Forcing content-type of 'text/plain' if none given...\n";
unless ($head->exists('content-type')) {
    $head->set('Content-type', 'text/plain');
}

print "* Forcing US-ASCII charset if none given...\n";
unless ($head->get('content-type') =~ m/\bcharset=/) {
    $head->add_text('Content-type', '; charset="US-ASCII"');
}

print "* Creating custom field 'X-Files'...\n";
$head->set('X-Files', 'default ; name="X Files Test"; length=60 ;setting="6"');

print "* Parameters of X-Files...\n";
my $params = $head->params('X-Files');
while (($key, $val) = each %$params) {
    print "    \u$key = <$val>\n" if defined($val);
}

print "* Adding two 'received' fields...\n";
$head->add('Received', 'from kermit.net by gonzo.net with smtp');
$head->add('Received', 'from gonzo.net by muppet.net with smtp');

print "\n* Printing original text to STDOUT...\n";
print '=' x 60, "\n";
print $head->original_text;
print '=' x 60, "\n\n";

print "\n* Dumping current header to STDOUT...\n";
print '=' x 60, "\n";
$head->print(\*STDOUT);
print '=' x 60, "\n\n";

print "\n* Decoding and dumping again...\n";
$head->decode;
print '=' x 60, "\n";
$head->print(\*STDOUT);
print '=' x 60, "\n\n";

print "\n* Unfolding and dumping again...\n";
$head->unfold;
print '=' x 60, "\n";
$head->print(\*STDOUT);
print '=' x 60, "\n\n";

# So we know everything went well...
exit 0;

#------------------------------------------------------------
1;
