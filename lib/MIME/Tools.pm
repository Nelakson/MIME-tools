package MIME::Tools;

#------------------------------
# Because the POD documenation is pretty extensive, it follows
# the __END__ statement below...
#------------------------------

use MIME::ToolUtils;
use vars qw($VERSION);

# Delegate configuration:
sub config { shift; MIME::ToolUtils->config(@_) }

# The TOOLKIT version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4.119 $, 10;

#------------------------------
1;
__END__


=head1 NAME

MIME-tools - modules for parsing (and creating!) MIME entities



=head1 SYNOPSIS

Here's some pretty basic code for B<parsing a MIME message,> and outputting
its decoded components to a given directory:

    use MIME::Parser;
     
    # Create parser, and set the output directory:
    my $parser = new MIME::Parser;
    $parser->output_dir("$ENV{HOME}/mimemail");
     
    # Parse input:
    $entity = $parser->read(\*STDIN) or die "couldn't parse MIME stream";
    
    # Take a look at the top-level entity (and any parts it has):
    $entity->dump_skeleton; 

Here's some code which B<composes and sends a MIME message> containing 
three parts: a text file, an attached GIF, and some more text:

    use MIME::Entity;

    # Create the top-level, and set up the mail headers:
    $top = build MIME::Entity Type    =>"multipart/mixed",
                              From    => "me\@myhost.com",
	                      To      => "you\@yourhost.com",
                              Subject => "Hello, nurse!";
    
    # Part #1: a simple text document: 
    attach $top  Path=>"./testin/short.txt";
    
    # Part #2: a GIF file:
    attach $top  Path        => "./docs/mime-sm.gif",
                 Type        => "image/gif",
                 Encoding    => "base64";
        
    # Part #3: some literal text:
    attach $top  Data=>$message;
    
    # Send it:
    open MAIL, "| /usr/lib/sendmail -t -i" or die "open: $!";
    $top->print(\*MAIL);
    close MAIL;



=head1 DESCRIPTION

MIME-tools is a collection of Perl5 MIME:: modules for parsing, decoding,
I<and generating> single- or multipart (even nested multipart) MIME 
messages.  (Yes, kids, that means you can send messages with attached 
GIF files).



=head1 A QUICK TOUR

=head2 Overview of the classes

Here are the classes you'll generally be dealing with directly:


           .------------.       .------------.           
           | MIME::     |------>| MIME::     |
           | Parser     |  isa  | ParserBase |   
           `------------'       `------------'
              | parse()
              | returns a...
              |
              |
              |
              |    head()       .--------.
              |    returns...   | MIME:: | get()
              V       .-------->| Head   | etc... 
           .--------./          `--------'      
     .---> | MIME:: | 
     `-----| Entity |           .--------. 
   parts() `--------'\          | MIME:: | 
   returns            `-------->| Body   |
   sub-entities    bodyhandle() `--------'
   (if any)        returns...       | open() 
                                    | returns...
                                    | 
                                    V  
                                .--------. read()    
                                | IO::   | getline()  
                                | Handle | print()          
                                `--------' etc...    


To illustrate, parsing works this way:

=over 4

=item *

B<The "parser" parses the MIME stream.>
Every "parser" inherits from the "parser base" class, which does
the real work.  When a message is parsed, the result is an "entity".

=item *

B<An "entity" has a "head" and a "body".>  
Entities are MIME message parts.

=item *

B<A "body" knows where the data is.>  
You can ask to "open" this data source for I<reading> or I<writing>, 
and you will get back an "I/O handle".

=item *

B<An "I/O handle" knows how to read/write the data.>
It is an object that is basically like an IO::Handle or 
a FileHandle... it can be any class, so long as it supports a small,
standard set of methods for reading from or writing to the underlying
data source.

=back

A typical multipart message containing two parts -- a textual greeting 
and an "attached" GIF file -- would be a tree of MIME::Entity objects,
each of which would have its own MIME::Head.  Like this:

    .--------.
    | MIME:: | Content-type: multipart/mixed 
    | Entity | Subject: Happy Samhaine!
    `--------'
         |
         `----.
        parts |
              |   .--------.   
              |---| MIME:: | Content-type: text/plain; charset=us-ascii
              |   | Entity | Content-transfer-encoding: 7bit
              |   `--------' 
              |   .--------.   
              |---| MIME:: | Content-type: image/gif
                  | Entity | Content-transfer-encoding: base64
                  `--------' Content-disposition: inline; filename="hs.gif"



=head2 Parsing, in a nutshell

You usually start by creating an instance of B<L<MIME::Parser>> (a subclass
of the abstract B<L<MIME::ParserBase>>), and setting up
certain parsing parameters: what directory to save extracted files 
to, how to name the files, etc.

You then give that instance a readable filehandle on which waits a
MIME message.  If all goes well, you will get back a B<L<MIME::Entity>>
object (a subclass of B<Mail::Internet>), which consists of...

=over 4

=item *

A B<MIME::Head> (a subclass of B<Mail::Header>) which holds the MIME 
header data.

=item *

A B<MIME::Body>, which is a object that knows where the body data is.
You ask this object to "open" itself for reading, and it
will hand you back an "I/O handle" for reading the data: this is
a FileHandle-like object, and could be of any class, so long as it
conforms to a subset of the B<IO::Handle> interface.  

=back

If the original message was a multipart document, the MIME::Entity
object will have a non-empty list of "parts", each of which is in 
turn a MIME::Entity (which might also be a multipart entity, etc, 
etc...).

Internally, the parser (in MIME::ParserBase) asks for instances 
of B<MIME::Decoder> whenever it needs to decode an encoded file.  
MIME::Decoder has a mapping from supported encodings (e.g., 'base64') 
to classes whose instances can decode them.  You can add to this mapping 
to try out new/experiment encodings.  You can also use 
MIME::Decoder by itself.  


=head2 Composing, in a nutshell

All message composition is done via the B<L<MIME::Entity>> class.
For single-part messages, you can use the L<MIME::Entity/build>
constructor to create MIME entities very easily.

For multipart messages, you can start by creating a top-level
C<multipart> entity with L<MIME::Entity/build>, and then use
the similar L<MIME::Entity/attach> method to attach parts to 
that message.  I<Please note:> what most people think of as 
"a text message with an attached GIF file" is I<really> a multipart
message with 2 parts: the first being the text message, and the
second being the GIF file. 

When building MIME a entity, you'll have to provide two very important
pieces of information: the I<content type> and the 
I<content transfer encoding>.  The type is usually easy, as it is directly 
determined by the file format; e.g., an HTML file is C<text/html>.   
The encoding, however, is trickier... for example, some HTML files are
C<7bit>-compliant, but others might have very long lines and would need to be
sent C<quoted-printable> for reliability.  

See the section on encoding/decoding for more details, as well as
L<"A MIME PRIMER">.


=head2 Encoding/decoding, in a nutshell

The L<MIME::Decoder> class can be used to I<encode> as well; this is done
when printing MIME entities.  All the standard encodings are supported
(see L<"A MIME PRIMER"> for details): 

    Encoding...       Normally used when message contents are...
    -------------------------------------------------------------------
    7bit              7-bit data with under 1000 chars/line, or multipart.
    8bit              8-bit data with under 1000 chars/line.
    binary            8-bit data with possibly long lines (or no line breaks).
    quoted-printable  Text files with some 8-bit chars (e.g., Latin-1 text).
    base64            Binary files.

Which encoding you choose for a given document depends largely on 
(1) what you know about the document's contents (text vs binary), and
(2) whether you need the resulting message to have a reliable encoding
for 7-bit Internet email transport. 

In general, only C<quoted-printable> and C<base64> guarantee reliable
transport of all data; the other three "no-encoding" encodings simply
pass the data through, and are only reliable if that data is 7bit ASCII 
with under 1000 characters per line, and has no conflicts with the
multipart boundaries.

I've considered making it so that the content-type and encoding
can be automatically inferred from the file's path, but that seems
to be asking for trouble... or at least, for Mail::Cap...


=head2 Other stuff you can do

If you want to tweak the way this toolkit works (for example, to 
turn on debugging), use the routines in the B<L<MIME::ToolUtils>> module.


=head2 Good advice

=over 4

=item *

B<Run with C<-w> on.>  If you see a warning about a deprecated method,
change your code ASAP.  This will ease upgrades tremendously.

=item *

B<Don't try to MIME-encode using the non-standard MIME encodings.>
It's just not a good practice if you want people to be able to
read your messages.

=item *

B<Be aware of possible thrown exceptions.>
For example, if your mail-handling code absolutely must not die, 
then perform mail parsing like this:

    $entity = eval { $parser->parse(\*INPUT) };
    
Parsing is a complex process, and some components may throw exceptions
if seriously-bad things happen.  Since "seriously-bad" is in the
eye of the beholder, you're better off I<catching> possible exceptions 
instead of asking me to propagate C<undef> up the stack.  Use of exceptions in
reusable modules is one of those religious issues we're never all 
going to agree upon; thankfully, that's what C<eval{}> is good for.

=back




=head1 NOTES


=head2 Terminology

Here are some excerpts from RFC-1521 explaining the terminology
we use; each is accompanied by the equivalent in MIME:: module terms...

=over 4

=item Message

From RFC-1521:

    The term "message", when not further qualified, means either the
    (complete or "top-level") message being transferred on a network, or
    a message encapsulated in a body of type "message".

There currently is no explicit package for messages; under MIME::, 
messages are streams of data which may be read in from files or 
filehandles.

=item Body part

From RFC-1521:

    The term "body part", in this document, means one of the parts of the
    body of a multipart entity. A body part has a header and a body, so
    it makes sense to speak about the body of a body part.

Since a body part is just a kind of entity (see below), a body part 
is represented by an instance of L<MIME::Entity>.

=item Entity

From RFC-1521:

    The term "entity", in this document, means either a message or a body
    part.  All kinds of entities share the property that they have a
    header and a body.

An entity is represented by an instance of L<MIME::Entity>.
There are instance methods for recovering the header (a L<MIME::Head>)
and the body (a L<MIME::Body>).

=item Header

This is the top portion of the MIME message, which contains the
Content-type, Content-transfer-encoding, etc.  Every MIME entity has
a header, represented by an instance of L<MIME::Head>.  You get the
header of an entity by sending it a head() message.

=item Body

From RFC-1521:

    The term "body", when not further qualified, means the body of an
    entity, that is the body of either a message or of a body part.

A body is represented by an instance of L<MIME::Body>.  You get the
body of an entity by sending it a bodyhandle() message.

=back


=head2 Compatibility

As of 4.x, MIME-tools can no longer emulate the old MIME-parser
distribution.  If you're installing this as a replacement for the 
MIME-parser 1.x release, you'll have to do a little tinkering with
your code.


=head2 Design issues

=over 4

=item Why assume that MIME objects are email objects?

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
MIME::, but we're a little beyond that stage now.  (I<Note: RFC-1521 
has recently been obsoleted by RFCs 2045-2049, so it's just as well 
we didn't go that route...>)

However, in my mind's eye, I see a mythical abstract class which does what 
Achim suggests... so you could say:

     my $attrs = new MIME::Attrs type => "text/plain",
				 charset => ...,
                                 disposition => ..., ... ;

We could even make it a superclass or companion class of MIME::Head, 
such that MIME::Head would allow itself to be initiallized from a 
MIME::Attrs object.

B<In the meanwhile,> look at the build() and attach() methods of MIME::Entity:
they follow the spirit of this mythical class.


=item To subclass or not to subclass?

When I originally wrote these modules for the CPAN, I agonized for a long
time about whether or not they really should subclass from B<Mail::Internet> 
(then at version 1.17).  Thanks to Graham Barr, who graciously evolved
MailTools 1.06 to be more MIME-friendly, unification was achieved
at MIME-tools release 2.0.   The benefits in reuse alone have been
substantial.

=back



=head2 Questionable practices

=over 4

=item Fuzzing of CRLF and newline on input

RFC-1521 dictates that MIME streams have lines terminated by CRLF
(C<"\r\n">).  However, it is extremely likely that folks will want to 
parse MIME streams where each line ends in the local newline 
character C<"\n"> instead. 

An attempt has been made to allow the parser to handle both CRLF 
and newline-terminated input.  

I<See MIME::ParserBase for further details.>


=item Fuzzing of CRLF and newline when decoding

The C<"7bit"> and C<"8bit"> decoders will decode both
a C<"\n"> and a C<"\r\n"> end-of-line sequence into a C<"\n">.

The C<"binary"> decoder (default if no encoding specified) 
still outputs stuff verbatim... so a MIME message with CRLFs 
and no explicit encoding will be output as a text file 
that, on many systems, will have an annoying ^M at the end of
each line... I<but this is as it should be>.

I<See MIME::ParserBase for further details.>


=item Fuzzing of CRLF and newline when encoding/composing

All encoders currently output the end-of-line sequence as a C<"\n">,
with the assumption that the local mail agent will perform
the conversion from newline to CRLF when sending the mail.

However, there probably should be an option to output CRLF as per RFC-1521.
I'm currently working on a good mechanism for this.

I<See MIME::ParserBase for further details.>


=item Inability to handle multipart boundaries with embedded newlines

First, let's get something straight: this is an evil, EVIL practice.
If your mailer creates multipart boundary strings that contain 
newlines, give it two weeks notice and find another one.  If your
mail robot receives MIME mail like this, regard it as syntactically
incorrect, which it is.

I<See MIME::ParserBase for further details.>


=back




=head1 A MIME PRIMER

So you need to parse (or create) MIME, but you're not quite up on 
the specifics?  No problem...


=head2 Content types

This indicates what kind of data is in the MIME message, usually
as I<majortype/minortype>.  The standard major types are shown below.
A more-comprehensive listing may be found in RFC-2046.

=over 4

=item application

Data which does not fit in any of the other categories, particularly 
data to be processed by some type of application program. 
C<application/octet-stream>, C<application/gzip>, C<application/postscript>...

=item audio

Audio data.
C<audio/basic>...

=item image

Graphics data.
C<image/gif>, C<image/jpeg>...

=item message

A message, usually another mail or MIME message.
C<message/rfc822>...

=item multipart

A message containing other messages.
C<multipart/mixed>, C<multipart/alternative>...

=item text

Textual data, meant for humans to read.
C<text/plain>, C<text/html>...

=item video

Video or video+audio data.
C<video/mpeg>...

=back


=head2 Content transfer encodings

This is how the message body is packaged up for safe transit.
There are the 5 major MIME encodings.
A more-comprehensive listing may be found in RFC-2045.

=over 4

=item 7bit

No encoding is done at all.  This label simply asserts that no
8-bit characters are present, and that lines do not exceed 1000 characters 
in length (including the CRLF).

=item 8bit

No encoding is done at all.  This label simply asserts that the message 
might contain 8-bit characters, and that lines do not exceed 1000 characters 
in length (including the CRLF).

=item binary

No encoding is done at all.  This label simply asserts that the message 
might contain 8-bit characters, and that lines may exceed 1000 characters 
in length.  Such messages are the I<least> likely to get through mail 
gateways.

=item base64

A standard encoding, which maps arbitrary binary data to the 7bit domain.
Like "uuencode", but very well-defined.  This is how you should send
essentially binary information (tar files, GIFs, JPEGs, etc.). 

=item quoted-printable

A standard encoding, which maps arbitrary line-oriented data to the
7bit domain.  Useful for encoding messages which are textual in
nature, yet which contain non-ASCII characters (e.g., Latin-1,
Latin-2, or any other 8-bit alphabet).

=back




=head1 TERMS AND CONDITIONS

Copyright (c) 1996, 1997 by Eryq.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself.  See the COPYING file in the distribution for details.



=head1 SUPPORT

Please email me directly with questions/problems (see AUTHOR below).

If you want to be placed on an email distribution list (not a mailing list!)
for MIME-tools, and receive bug reports, patches, and updates as to when new 
MIME-tools releases are planned, just email me and say so.  If your project
is using MIME-tools, it might not be a bad idea to find out about those
bugs I<before> they become problems...



=head1 CHANGE LOG


=head2 Future plans

=over 4

=item *

Dress up mimedump and mimeexplode utilities to take cmd line options
for directory, environment vars (MIMEDUMP_OUTPUT, etc.).

=item *

Support for S/MIME and message/partial?

=back



=head2 Current events

=over 4

=item Version 4.117

B<Nicer MIME::Entity::build.> 
        No longer outputs warnings with undefined Filename, and now
        accepts Charset as well.
	I<Thanks to Jason Tibbits III for the inspirational patch.>

B<Documentation fixes.>  
        Hopefully we've seen the last of the pod2man warnings...

B<Better test logging.>  
        Now uses ExtUtils::TBone.


=item Version 4.116

B<Bug fix:> 
        MIME::Head and MIME::Entity were not downcasing the
        content-type as they claimed.  This has now been fixed.
	I<Thanks to Rodrigo de Almeida Siqueira for finding this.>


=item Version 4.114

B<Gzip64-encoding has been improved, and turned off as a default,>
	since it depends on having gzip installed.  
        See MIME::Decoder::Gzip64 if you want to activate it in your app.
	You can	now set up the gzip/gunzip commands to use, as well.
	I<Thanks to Paul J. Schinder for finding this bug.>


=item Version 4.113

B<Bug fix:>
        MIME::ParserBase was accidentally folding newlines in header fields.
	I<Thanks to Jason L. Tibbitts III for spotting this.>


=item Version 4.112

B<MIME::Entity::print_body now recurses> when printing multipart
	entities, and prints "everything following the header."  This is more
	likely what people expect to happen.  PLEASE read the
        "two body problem" section of MIME::Entity's docs.


=item Version 4.111

Clean build/test on Win95 using 5.004.  Whew.


=item Version 4.110

B<Added> make_multipart() and make_singlepart() in MIME::Entity.

B<Improved> handling/saving of preamble/epilogue.


=item Version 4.109

=over 4

=item Overall

B<Major version shift to 4.x> 
	accompanies numerous structural changes, and
	the deletion of some long-deprecated code.  Many apologies to those
	who are inconvenienced by the upgrade.

B<MIME::IO deprecated.> 
	You'll see IO::Scalar, IO::ScalarArray, and IO::Wrap
	to make this toolkit work.

B<MIME::Entity deep code.>
	You can now deep-copy MIME entities (except for on-disk data files).


=item Encoding/decoding

B<MIME::Latin1 deprecated, and 8-to-7 mapping removed.> 
	Really, MIME::Latin1 was one of my more dumber ideas.  
	It's still there, but if you want to map 8-bit characters to 
	Latin1 ASCII approximations when 7bit encoding, you'll have to 
	request it explicitly.	I<But use quoted-printable for your 8-bit 
	documents; that's what it's there for!>

B<7bit and 8bit "encoders" no longer encode.>
	As per RFC-2045, these just do a pass-through of the data,
	but they'll warn you if you send bad data through.

B<MIME::Entity suggests encoding.>
	Now you can ask MIME::Entity's build() method to "suggest"
	a legal encoding based on the body and the content-type.
	No more guesswork!  See the "mimesend" example.

B<New module structure for MIME::Decoder classes.> 
	It should be easier for you to see what's happening.

B<New MIME decoders!>  
	Support added for decoding C<x-uuencode>, and for 
	decoding/encoding C<x-gzip64>.  You'll need "gzip" to make
	the latter work.

B<Quoted-printable back on track... and then some.>
	The 'quoted-printable' decoder now uses the newest MIME::QuotedPrint,
	and amends its output with guideline #8 from RFC2049 (From/.).
	I<Thanks to Denis N. Antonioli for suggesting this.>

=item Parsing

B<Preamble and epilogue are now saved.>
	These are saved in the parsed entities as simple
	string-arrays, and are output by print() if there. 
	I<Thanks to Jason L. Tibbitts for suggesting this.>

B<The "multipart/digest" semantics are now preserved.> 
	Parts of digest messages have their mime_type() defaulted 
	to "message/rfc822" instead of "text/plain", as per the RFC.
	I<Thanks to Carsten Heyl for suggesting this.>

=item Output

B<Well-defined, more-complete print() output.>
	When printing an entity, the output is now well-defined if the
	entity came from a MIME::Parser, even if using parse_nested_messages.
	See MIME::Entity for details.

B<You can prevent recommended filenames from being output.> 
	This possible security hole has been plugged; when building MIME 
	entities, you can specify a body path but suppress the filename
	in the header.
	I<Thanks to Jason L. Tibbitts for suggesting this.>

=item Bug fixes

B<Win32 installations should work.>
	The binmode() calls should work fine on Win32 now.
	I<Thanks to numerous folks for their patches.>

B<MIME::Head::add()> now no longer downcases its argument.
	I<Thanks to Brandon Browning & Jason L. Tibbitts for finding this bug.>

=back

=back



=head2 Old news

=over 4

=item Version 3.204

B<Bug in MIME::Head::original_text fixed.>
	Well, it took a while, but another bug surfaced from my transition 
	from 1.x to 2.x.  This method was, quite idiotically, sorting the 
	header fields.
	I<Thanks, as usual, to Andreas Koenig for spotting this one.>

B<MIME::ParserBase no longer defaults to RFC-1522-decoding headers.>
	The documentation correctly stated that the default setting was 
	to I<not> RFC-1522-decode the headers.  The code, on the other hand,
	was init'ing this parser option in the "on" position.  
	This has been fixed.

B<MIME::ParserBase::parse_nested_messages reexamined.>
	If you use this feature, please re-read the documentation.
	It explains a little more precisely what the ramifications are.

B<MIME::Entity tries harder to ensure MIME compliance.>
	It is now a fatal error to use certain bad combinations of content
	type and encoding when "building", or to attempt to "attach" to
	anything that is not a multipart document.  My apologies if this
	inconveniences anyone, but it was just too darn easy before for folks
	to create bad MIME, and gosh darn it, good libraries should at least
	I<try> to protect you from mistakes.

B<The "make" now halts if you don't have the right stuff,> 
	provided your MakeMaker supports PREREQ_PM.  See the L<"REQUIREMENTS">
	section for what you need to install this package.  I still provide
	old courtesy copies of the MIME:: decoding modules.
I<Thanks to Hugo van der Sanden for suggesting this.>

B<The "make test" is far less chatty.>
	Okay, okay, STDERR is evil.  Now a C<"make test"> will just give you
	the important stuff: do a C<"make test TEST_VERBOSE=1"> if you want
	the gory details (advisable if sending me a bug report).
I<Thanks to Andreas Koenig for suggesting this.>


=item Version 3.203

B<No, there haven't been any major changes between 2.x and 3.x.>
	The major-version increase was from a few more tweaks to get $VERSION
	to be calculated better and more efficiently (I had been using RCS
	version numbers in a way which created problems for users of CPAN::).
	After a couple of false starts, all modules have been upgraded to RCS
	3.201 or higher.

B<You can now parse a MIME message from a scalar,> 
	an array-of-scalars, or any MIME::IO-compliant object (including IO::
	objects.)  Take a look at parse_data() in MIME::ParserBase.  The
	parser code has been modified to support the MIME::IO interface.
	I<Thanks to fellow Chicagoan Tim Pierce (and countless others) 
	for asking.>

B<More sensible toolkit configuration.>
	A new config() method in MIME::ToolUtils makes a lot of toolkit-wide
	configuration cleaner.  Your old calls will still work, but with
	deprecation warnings.

B<You can now sign messages> just like in Mail::Internet.
	See MIME::Entity for the interface.

B<You can now remove signatures from messages> just like in Mail::Internet.
	See MIME::Entity for the interface.

B<You can now compute/strip content lengths> 
	and other non-standard MIME fields.  
	See sync_headers() in MIME::Entity.
	I<Thanks to Tim Pierce for bringing the basic problem to my attention.>

B<Many warnings are now silent unless $^W is true.>  
	That means unless you run your Perl with C<-w>, you won't see 
        deprecation warnings, non-fatal-error messages, etc.  
        But of course you run with C<-w>, so this doesn't affect you.  C<:-)>

B<Completed the 7-bit encodings in MIME::Latin1.>
	We hadn't had complete coverage in the conversion from 8- to 7-bit; 
	now we do. I<Thanks to Rolf Nelson for bringing this to my attention.>

B<Fixed broken parse_two() in MIME::ParserBase.>
	BTW, if your code worked with the "broken" code, it should I<still>
	work.  
	I<Thanks again to Tim Pierce for bringing this to my attention.>


=item Version 2.14

Just a few bug fixes to improve compatibility with Mail-Tools 1.08,
and with the upcoming Perl 5.004 release.
I<Thanks to Jason L. Tibbitts III for reporting the problems so quickly.>


=item Version 2.13

=over 4

=item New features

B<Added RFC-1522-style decoding of encoded header fields.>
	Header decoding can now be done automatically during parsing via the 
	new C<decode()> method in MIME::Head... just tell your parser
	object that you want to C<decode_headers()>. 
	I<Thanks to Kent Boortz for providing the idea, and the baseline 
	RFC-1522-decoding code!>

B<Building MIME messages is even easier.>  
	Now, when you use MIME::Entity's C<build()> or C<attach()>, 
	you can also supply individual 
	mail headers to set (e.g., C<-Subject>, C<-From>, C<-To>).

Added C<Disposition> to MIME::Entity's C<build()> method.
	I<Thanks to Kurt Freytag for suggesting this feature.>

An C<X-Mailer> header is now output 
	by default in all MIME-Entity-prepared messages, 
	so any bad MIME we generate can be traced back to this toolkit.

Added C<purge()> method to MIME::Entity for deleteing leftover files.
	I<Thanks to Jason L. Tibbitts III for suggesting this feature.>

Added C<seek()> and C<tell()> methods to built-in MIME::IO classes.
	Only guaranteed to work when reading!
	I<Thanks to Jason L. Tibbitts III for suggesting this feature.>

When parsing a multipart message with apparently no boundaries, 
	the error message you get has been improved.  
	I<Thanks to Andreas Koenig for suggesting this.>

=item Bug fixes

B<Patched over a Perl 5.002 (and maybe earlier and later) bug involving
FileHandle::new_tmpfile.>  It seems that the underlying filehandles
were not being closed when the FileHandle objects went out of scope!
There is now an internal routine that creates true FileHandle
objects for anonymous temp files. 
I<Thanks to Dragomir R. Radev and Zyx for reporting the weird behavior
that led to the discovery of this bug.>

MIME::Entity's C<build()> method now warns you if you give it an illegal 
boundary string, and substitutes one of its own.

MIME::Entity's C<build()> method now generates safer, fully-RFC-1521-compliant 
boundary strings.

Bug in MIME::Decoder's C<install()> method was fixed.  
I<Thanks to Rolf Nelson and Nickolay Saukh for finding this.>

Changed FileHandle::new_tmpfile to FileHandle->new_tmpfile, so some 
Perl installations will be happier.  
I<Thanks to Larry W. Virden for finding this bug.>

Gave C<=over> an arg of 4 in all PODs.
I<Thanks to Larry W. Virden for pointing out the problems of bare =over's>

=back


=item Version 2.04

B<A bug in MIME::Entity's output method was corrected.>
MIME::Entity::print now outputs everything to the desired filehandle
explicitly.  
I<Thanks to Jake Morrison for pointing out the incompatibility 
with Mail::Header.>


=item Version 2.03

B<Fixed bug in autogenerated filenames> resulting from transposed "if" 
statement in MIME::Parser, removing spurious printing of header as well.
(Annoyingly, this bug is invisible if debugging is turned on!)
I<Thanks to Andreas Koenig for bringing this to my attention.>

Fixed bug in MIME::Entity::body() where it was using the bodyhandle
completely incorrectly.  
I<Thanks to Joel Noble for bringing this to my attention.>

Fixed MIME::Head::VERSION so CPAN:: is happier.
I<Thanks to Larry Virden for bringing this to my attention.>

Fixed undefined-variable warnings when dumping skeleton
(happened when there was no Subject: line)
I<Thanks to Joel Noble for bringing this to my attention.>


=item Version 2.02

B<Stupid, stupid bugs in both BASE64 encoding and decoding were fixed.>
I<Thanks to Phil Abercrombie for locating them.>


=item Version 2.01

B<Modules now inherit from the new Mail:: modules!>
This means big changes in behavior.

B<MIME::Parser can now store message data in-core.>
There were a I<lot> of requests for this feature.

B<MIME::Entity can now compose messages.>
There were a I<lot> of requests for this feature.

Added option to parse C<"message/rfc822"> as a pseduo-multipart document.
I<Thanks to Andreas Koenig for suggesting this.>

=back


=head2 Ancient history

=over 4

=item Version 1.13 	

MIME::Head now no longer requires space after ":", although
either a space or a tab after the ":" will be swallowed
if there.  
I<Thanks to Igor Starovoitov for pointing out this shortcoming.>

=item Version 1.12	

Fixed bugs in parser where CRLF-terminated lines were 
blowing out the handling of preambles/epilogues.
I<Thanks to Russell Sutherland for reporting this bug.>

Fixed idiotic is_multipart() bug.  
I<Thanks to Andreas Koenig for noticing it.>

Added untested binmode() calls to parser for DOS, etc.
systems.  No idea if this will work...

Reorganized the output_path() methods to allow easy use
of inheritance, as per Achim Bohnet's suggestion.

Changed MIME::Head to report mime_type more accurately.

POSIX module no longer loaded by Parser if perl >= 5.002.
Hey, 5.001'ers: let me know if this breaks stuff, okay?

Added unsupported ./examples directory.

=item Version 1.11	

Converted over to using Makefile.PL.  
I<Thanks to Andreas Koenig for the much-needed kick in the pants...>

Added t/*.t files for testing.  Eeeeeeeeeeeh...it's a start.

Fixed bug in default parsing routine for generating 
output paths; it was warning about evil filenames if
there simply I<were> no recommended filenames.  D'oh!

Fixed redefined parts() method in Entity.

Fixed bugs in Head where field name wasn't being case folded.

=item Version 1.10	

A typo was causing the epilogue of an inner multipart
message to be swallowed to the end of the OUTER multipart
message; this has now been fixed.  
I<Thanks to Igor Starovoitov for reporting this bug.>

A bad regexp for parameter names was causing 
some parameters to be parsed incorrectly; this has also
been fixed.  
I<Thanks again to Igor Starovoitov for reporting this bug.>
	
It is now possible to get full control of the filenaming
algorithm before output files are generated, and the default
algorithm is safer.  
I<Thanks to Laurent Amon for pointing out the problems, and suggesting 
some solutions.>

Fixed illegal "simple" multipart test file.  D'OH!

=item Version 1.9	

No changes: 1.8 failed CPAN registration

=item Version 1.8.	

Fixed incompatibility with 5.001 and FileHandle::new_tmpfile
Added COPYING file, and improved README.

=back




=head1 AUTHOR 

MIME-tools was created by:

    ___  _ _ _   _  ___ _     
   / _ \| '_| | | |/ _ ' /    Eryq (President, Zero G Inc.)
  |  __/| | | |_| | |_| |     http://www.zeegee.com/
   \___||_|  \__, |\__, |__   eryq@zeegee.com
             |___/    |___/

Release as MIME-parser (1.0): 28 April 1996.
Release as MIME-tools (2.0): Halloween 1996.
Release of 4.0: Christmas 1997. 


=head1 VERSION

$Revision: 4.119 $ 


=head1 ACKNOWLEDGMENTS

B<This kit would not have been possible> but for the direct 
contributions of the following:

    Gisle Aas             The MIME encoding/decoding modules.
    Laurent Amon          Bug reports and suggestions.
    Graham Barr           The new MailTools.
    Achim Bohnet          Numerous good suggestions, including the I/O model.
    Kent Boortz           Initial code for RFC-1522-decoding of MIME headers.
    Andreas Koenig        Numerous good ideas, tons of beta testing,
                            and help with CPAN-friendly packaging.
    Igor Starovoitov      Bug reports and suggestions.
    Jason L Tibbitts III  Bug reports, suggestions, patches.
 
Not to mention the Accidental Beta Test Team, whose bug reports (and
comments) have been invaluable in improving the whole:

    Phil Abercrombie
    Brandon Browning
    Kurt Freytag
    Steve Kilbane
    Jake Morrison
    Rolf Nelson
    Joel Noble    
    Michael W. Normandin 
    Tim Pierce
    Andrew Pimlott
    Dragomir R. Radev
    Nickolay Saukh
    Russell Sutherland
    Larry Virden
    Zyx

Please forgive me if I've accidentally left you out.  
Better yet, email me, and I'll put you in.



=head1 SEE ALSO

Users of this toolkit may wish to read the documentation of Mail::Header 
and Mail::Internet.

The MIME format is documented in RFCs 1521-1522, and more recently
in RFCs 2045-2049.

The MIME header format is an outgrowth of the mail header format
documented in RFC 822.



=cut
