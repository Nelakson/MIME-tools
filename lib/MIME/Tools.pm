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
$VERSION = substr q$Revision: 4.113 $, 10;

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

B<Run with -w.>  If you see a warning about a deprecated method,
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

See the README file in the distribution for the most-recent changes.
For a full history, see the ./docs/MIME-tools.pod file in the distribution.



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

$Revision: 4.113 $ 


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

