package MIME::Entity;


=head1 NAME

MIME::Entity - class for parsed-and-decoded MIME message


=head1 SYNOPSIS

Create a MIME entity from an array, and output it as a MIME stream to STDOUT:

    $ent = new MIME::Entity [
			  "Subject: Greetings\n",
			  "Content-type: text/plain\n",
			  "Content-transfer-encoding: 7bit\n",
			  "\n",
			  "Hi there!\n", 
			  "Bye there!\n"
        		  ];
    $ent->print(\*STDOUT);

Create a document for an ordinary 7-bit ASCII text file (lots of 
stuff is defaulted for us):

    $msg = build MIME::Entity Path=>"english-msg.txt";
    $msg->print(\*STDOUT);

Create a document for a text file with 8-bit (Latin-1) characters:

    $msg = build MIME::Entity Path     =>"french-msg.txt",
                              Encoding =>"quoted-printable";
    $msg->print(\*STDOUT);

Create a document for a GIF file (the description is completely optional,
and note that we have to specify content-type and encoding since they're
not the default values):

    $gif = build MIME::Entity Description => "A pretty picture",
                              Path        => "./docs/mime-sm.gif",
                              Type        => "image/gif",
                              Encoding    => "base64";
    $gif->print(\*STDOUT);

Create a multipart message (could it I<be> much easier?)

    # Create the top-level, and set up the mail headers:
    $top = build MIME::Entity Type=>"multipart/mixed";
    $top->head->add('from',    "me\@myhost.com");
    $top->head->add('to',      "you\@yourhost.com");
    $top->head->add('subject', "Hello, nurse!");
    
    # Attachment #1: a simple text document: 
    attach $top  Path=>"./testin/short.txt";
    
    # Attachment #2: a GIF file:
    attach $top  Path        => "./docs/mime-sm.gif",
                 Type        => "image/gif",
                 Encoding    => "base64";
    
    # Output!
    $top->print(\*STDOUT);

Extract information from MIME entities:

    # Get the head, a MIME::Head:
    $head = $ent->head;
    
    # Get the body, as a MIME::Body;
    $bodyh = $ent->bodyhandle;

See MIME::Parser for additional examples of usage.


=head1 DESCRIPTION

A subclass of B<Mail::Internet>.

This package provides a class for representing MIME message entities,
as specified in RFC 1521, I<Multipurpose Internet Mail Extensions>.

Here are some excerpts from RFC-1521 explaining the terminology:
each is accompanied by the equivalent in MIME:: terms:

=over 4

=item Message

From RFC-1521:

    The term "message", when not further qualified, means either the
    (complete or "top-level") message being transferred on a network, or
    a message encapsulated in a body of type "message".

There currently is no explicit package for messages; under MIME::, 
messages may be read in from readable files or filehandles.
A future extension will allow them to be read from any object 
reference that responds to a special "next line" method.

=item Body part

From RFC-1521:

    The term "body part", in this document, means one of the parts of the
    body of a multipart entity. A body part has a header and a body, so
    it makes sense to speak about the body of a body part.

Since a body part is just a kind of entity (see below), a body part 
is represented by an instance of MIME::Entity.

=item Entity

From RFC-1521:

    The term "entity", in this document, means either a message or a body
    part.  All kinds of entities share the property that they have a
    header and a body.

An entity is represented by an instance of MIME::Entity.
There are instance methods for recovering the header (a MIME::Head)
and the body (see below).

=item Body

From RFC-1521:

    The term "body", when not further qualified, means the body of an
    entity, that is the body of either a message or of a body part.

Well, this is a toughie.  Both Mail::Internet (1.17) and Mail::MIME (1.03)
represent message bodies in-core; unfortunately, this is not always the
best way to handle things, especially for MIME streams that contain
multi-megabyte tar files.

=back


=head1 PUBLIC INTERFACE

=cut

#------------------------------------------------------------

# Pragmas:
use vars qw(@ISA $VERSION); 
use strict;

# System modules:
use Carp;

# Other modules:
require Mail::Internet;

# Kit modules:
use MIME::ToolUtils qw(:config :msgs);
use MIME::Head;
use MIME::Body;
use MIME::Decoder;

@ISA = qw(Mail::Internet);


#------------------------------
#
# Globals...
#
#------------------------------

# The package version, both in 1.23 style *and* usable by MakeMaker:
( $VERSION ) = '$Revision: 2.5 $ ' =~ /\$Revision:\s+([^\s]+)/;

# Boundary counter:
my $BCount = 0;


#------------------------------

=head2 Constructors and converters

=over 4

=cut

#------------------------------

#------------------------------------------------------------
# new
#------------------------------------------------------------

=item new [SOURCE]

I<Class method.>
Create a new, empty MIME entity.

If SOURCE is an ARRAYREF, it is assumed to be an array of lines
that will be used to create both the header and an in-core body.

Else, if SOURCE is defined, it is assumed to be a filehandle
from which the header and in-core body is to be read. 

B<Note:> in either case, the body will not be I<parsed:> merely read!

=cut

sub new {
    my $class = shift;

    # Create new object:
    my $self = $class->Mail::Internet::new(@_);

    # Add stuff for this class:
    $self->{ME_Parts} = [];         # no parts extracted
    $self->{ME_PartType} = '';
    $self;
}

#------------------------------------------------------------
# build
#------------------------------------------------------------

=item build PARAMHASH

I<Class/instance method.>
A quick-and-easy catch-all way to create an entity.  Use it like this
to build a "normal" single-part entity:

   $ent = build MIME::Entity Type     => "image/gif",
		             Encoding => "base64",
                             Path     => "/path/to/xyz12345.gif",
                             Filename => "saveme.gif";

And like this to build a "multipart" entity:

   $ent = build MIME::Entity Type     => "multipart/mixed",
                             Boundary => "---1234567";

A minimal MIME header will be created.  The params are:

=over

=item Boundary

I<Multipart entities only. Optional.>  
The boundary string.
If you omit this, a random string will be chosen... which is probably safer.

=item Data

I<Single-part entities only. Optional.>  
An alternative to Path (q.v.): the actual data.  If an array reference, 
the array's lines are joined into a private scalar.  The body is 
then opened on that data using MIME::Body::Scalar.

=item Description

I<Optional.>  
The text of the content-description.  
If you don't specify it, the field is not put in the header.

=item Encoding

I<Optional.>  
The content-transfer-encoding.
If you don't specify it, the field is not put in the header... 
which means that the encoding implicitly defaults to C<"7bit"> as per 
RFC-1521.  I<Do yourself a favor: put it in.>

=item Filename

I<Single-part entities only. Optional.>  
The recommended filename.  Overrides any name extracted from C<Path>.
The information is stored both the deprecated (content-type) and
preferred (content-disposition) locations.

=item Path

I<Single-part entities only. Optional.>  
The path to the file to attach.  The body is opened on that file
using MIME::Body::File.

=item Top

I<Optional.>  
Is this a top-level entity?  If so, it must sport a MIME-Version.
The default is true.

=item Type

I<Optional.>  
The content-type. 
If you don't specify it, it defaults to C<"text/plain"> 
as per RFC-1521.  I<Do yourself a favor: put it in.>

=back

=cut

sub build {
    my $self = shift;
    my %params = @_;
    my ($field, $filename, $boundary);


    ### MAKE SELF...

    # Create a new entity, if needed:
    ref($self) or $self = $self->new;


    ### GET INFO...

    # Get sundry fields:
    my $type     = $params{Type} || 'text/plain';
    my $is_multipart = ($type =~ m{^multipart/}i);
    my $encoding = $params{Encoding} || '';
    my $desc     = $params{Description};
    my $top      = exists($params{Top}) ? $params{Top} : 1;

    # Get recommended filename:
    $filename = $params{Filename} || $params{Path} || '';
    $filename =~ s{^.*/}{}g;        # nuke path info    

    # Multipart or not? Do sanity check and fixup:
    if ($is_multipart) {      # multipart...
	
	# Check encoding:
	($encoding =~ /^(|7bit|8bit|binary)$/i) 
	    or die "multipart message with illegal encoding: $encoding!";
	
	# Force boundary:
	$boundary = $params{Boundary} ||
	    ("------------".scalar(time)."-$$-".$BCount++);
    }
    else {                    # single part...

	# Create body:
	if ($params{Path}) {
	    $self->bodyhandle(new MIME::Body::File $params{Path});
	}
	elsif ($params{Data}) {
	    $self->bodyhandle(new MIME::Body::Scalar $params{Data});
	}
	else { 
	    die "can't build entity: no body, and not multipart!";
	}
    }


    ### MAKE HEAD...

    # Create head:
    my $head = new MIME::Head;
    $head->modify(1);

    # Add content-type field:
    $field = new Mail::Field 'Content_type';         # not a typo :-(
    $field->type($type);
    $field->name($filename)      if ($filename ne '');
    $field->boundary($boundary)  if ($boundary ne '');
    $head->add('Content-type', $field->stringify);

    # Add content-disposition field (if not multipart):
    unless ($is_multipart) {
	$field = new Mail::Field 'Content_disposition';  # not a typo :-(
	$field->type('inline');
	$field->filename($filename) if ($filename ne '');
	$head->add('Content-disposition', $field->stringify);
    }

    # Add other fields:
    $head->add('Content-transfer-encoding', $encoding) if $encoding;
    $head->add('Content-description', $desc)           if $desc;
    $head->add('MIME-Version', '1.0')                  if $top;
    
    # Done!
    $self->head($head);
    $self;
}


#------------------------------

=back

=head2 Instance methods

=over 4

=cut

#------------------------------

#------------------------------------------------------------
# add_part
#------------------------------------------------------------

=item add_part

Assuming we are a multipart message, add a body part (a MIME::Entity)
to the array of body parts.  Do B<not> call this for single-part messages;
i.e., don't call it unless the header has a C<"multipart"> content-type.

=cut

sub add_part {
    my ($self, $part) = @_;
    push @{$self->{ME_Parts}}, $part;
}

#------------------------------------------------------------
# all_parts -- PLANNED
#------------------------------------------------------------
#
# =item all_parts
#
# Like C<parts()>, except that for multipart messages, the preamble and
# epilogue parts I<are> returned in the list, as (respectively) the
# first and last elements.
#
# B<WARNING:> if either/both the preamble/epilogue are missing, then
# they will simply not be in the list; i.e., if the preamble is missing,
# the first list element will have a C<packaging> of 'PART', not 'PREAMBLE'.
#
# =cut

sub all_parts {
    my $self = shift;
    my @all = ();
    push @all, $self->{ME_Preamble} if $self->{ME_Preamble};
    push @all, @{$self->{ME_Parts}};
    push @all, $self->{ME_Epilogue} if $self->{ME_Epilogue};
}

#------------------------------------------------------------
# attach
#------------------------------------------------------------

=item attach PARAMHASH

The real quick-and-easy way to create multipart messages.
Basically equivalent to:

    $entity->add_part(ref($entity)->build(PARAMHASH));

Except that it's a lot nicer to look at.

=cut 

sub attach {
    my $self = shift;
    $self->add_part(ref($self)->build(@_, Top=>0));
}

#------------------------------------------------------------
# body
#------------------------------------------------------------

=item body [VALUE]

=over

=item B<If emulating version 1.x:>

Get or set the path to the file containing the body.

If C<VALUE> I<is not> given, the current body file is returned.
If C<VALUE> I<is> given, the body file is set to the new value,
and the previous value is returned.

=item B<Otherwise:>

Get or set the body, as an array of lines.  This should be regarded
as a read-only data structure: changing its contents will have 
unpredictable results (you can, of course, make your own copy,
and work with that).  

Provided for compatibility with Mail::Internet, and it might not 
be as efficient as you'd like.  Also, it's somewhat silly/wrongheaded
for binary bodies, like GIFs and tar files.

=back

Both forms are deprecated for MIME entities: instead, use the bodyhandle()
method to get and use a MIME::Body.  The content-type of the entity
will tell you whether that body is best read as text (via getline())
or raw data (via read()).

=cut

sub body {
    my ($self, $value) = @_;

    if ($CONFIG{EMULATE_VERSION} < 2) {      # version 1.x: body = filename
	usage "deprecated for MIME entities: use bodyhandle() instead";
	return $self->bodyhandle->path($value);
    }
    else {                                   # version 2.x: body = line/lines
	if ($value) {      # setting body line(s)...
	    return $self->bodyhandle(new MIME::Body::Scalar $value);
	}
	else {             # getting body lines...
	    $self->bodyhandle || return [];
	    my $IO = $self->bodyhandle->open("r") || return [];
	    return $IO->getlines;
	}
    }
}

#------------------------------------------------------------
# bodyhandle
#------------------------------------------------------------

=item bodyhandle [VALUE]

Get or set an abstract object representing the body.

If C<VALUE> I<is not> given, the current bodyhandle is returned.
If C<VALUE> I<is> given, the bodyhandle is set to the new value,
and the previous value is returned.

=cut

sub bodyhandle {
    my ($self, $newvalue) = @_;
    my $value = $self->{ME_Bodyhandle};
    $self->{ME_Bodyhandle} = $newvalue if (@_ > 1);
    $value;
}

#------------------------------------------------------------
# dump_skeleton
#------------------------------------------------------------

=item dump_skeleton [FILEHANDLE]

Dump the skeleton of the entity to the given FILEHANDLE, or
to the currently-selected one if none given.  This is really
just useful for debugging purposes.

=cut

sub dump_skeleton {
    my ($self, $fh, $indent) = @_;
    $fh or $fh = select;
    defined($indent) or $indent = 0;
    my $ind = '    ' x $indent;
    my $part;
    no strict 'refs';


    # The content type:
    print $fh $ind, "Content-type: ", 
          ($self->head ? $self->head->mime_type : 'UNKNOWN'), "\n";

    # The name of the file containing the body (if any!):
    if ($CONFIG{EMULATE_VERSION} < 2) {      # version 1.x: body = filename
	print $fh $ind, "Body-file: ", ($self->body || 'NONE'), "\n";
    }
    else {
	my $path = eval { $self->bodyhandle->path };
	print $fh $ind, "Body-file: ", ($path || 'NONE'), "\n";
    }

    # The subject (note: already a newline if 2.x!)
    my $subj = $self->head->get('subject',0);
    defined($subj) or $subj = '';
    chomp($subj);
    print $fh $ind, "Subject: $subj\n" if $subj;

    # The parts:
    my @parts = $self->parts;
    print $fh $ind, "Num-parts: ", int(@parts), "\n" if @parts;
    print $fh $ind, "--\n";
    foreach $part (@parts) {
	$part->dump_skeleton($fh, $indent+1);
    }
}

#------------------------------------------------------------
# head
#------------------------------------------------------------

=item head [VALUE]

Get/set the head. 

If there is no VALUE given, returns the current head.  If none
exists, an empty instance of MIME::Head is created, set, and returned.

B<Note:> This is a patch over a bug in Mail::Internet, which doesn't 
provide a method for setting the head to some given object.

=cut

sub head { 
    my ($self, $value) = @_;
    (@_ > 1) and $self->{'mail_inet_head'} = $value;
    $self->{'mail_inet_head'} ||= new MIME::Head;
}

#------------------------------------------------------------
# is_multipart
#------------------------------------------------------------

=item is_multipart

Does this entity's MIME type indicate that it's a multipart entity?
Returns undef (false) if the answer couldn't be determined, 0 (false)
if it was determined to be false, and true otherwise.

Note that this says nothing about whether or not parts were extracted.

=cut

sub is_multipart {
    my $self = shift;
    $self->head or return undef;        # no head, so no MIME type!
    my ($type, $subtype) = split('/', $self->head->mime_type);
    (($type eq 'multipart') ? 1 : 0);
}

#------------------------------------------------------------
# mime_type
#------------------------------------------------------------

=item mime_type

A purely-for-convenience method.  This simply relays the
request to the associated MIME::Head object.  The following
are identical:

    $x = $entity->mime_type;
    
    $x = $entity->head->mime_type;

If there is no head, returns undef in a scalar context and
the empty array in a list context.

Note that, while parsed entities still have MIME types, they 
do not have MIME encodings, or MIME versions, or fields, etc., etc... 
for those attributes, you still have to go to the I<head> explicitly.

=cut

sub mime_type {
    my $self = shift;
    $self->head or return (wantarray ? () : undef);
    $self->head->mime_type;
}

#------------------------------------------------------------
# packaging -- PLANNED (MAYBE)
#------------------------------------------------------------
# 
# =item packaging OPTVALUE
# 
# Get or set the "packaging" of this entity; that is, where was it 
# when we removed it from its MIME stream?
# 
# If C<OPTVALUE> I<is not> given, the current packaging is returned.
# If C<OPTVALUE> I<is> given, the packaging is set to the new value,
# and the previous value is returned.
# 
# The packaging may be any of:
# 
#     (empty)   - either unknown, or nothing has been extracted yet!
#     ALL       - this entity was extracted from a single-part message
#     PREAMBLE  - this entity was the preamble of a multipart message
#     PART      - this entity was a part of a multipart message
#     EPILOGUE  - this entity was the epilogue of a multipart message
# 
# =cut

sub packaging {
    my ($self, $newvalue) = @_;
    my $value = $self->{ME_Packaging};
    $self->{ME_Packaging} = $newvalue if (@_ > 1);
    $value;
}

#------------------------------------------------------------
# parts
#------------------------------------------------------------

=item parts

Return an array of all sub parts (each of which is a MIME::Entity), 
or the empty array if there are none.  

For single-part messages, the empty array will be returned.
For multipart messages, the preamble and epilogue parts are I<not> in the 
list!  If you want them, use C<all_parts()> instead.

=cut

sub parts {
    my $self = shift;
    @{$self->{ME_Parts}};
}

#------------------------------------------------------------
# print
#------------------------------------------------------------

=item print [FILEHANDLE]

I<Instance method, override.>
Print the entity to the given FILEHANDLE, or to the currently-selected
one if none given.  

B<If a single-part entity,>
the header and the body are both output, with the body being output
according to the encoding specified by the header.

B<If a multipart entity,>
this is invoked recursively on all its parts, with appropriate
boundaries and a preamble generated for you.

See C<print_body()> for an important note on how the body is output.

=cut

sub print {
    my ($self, $fh) = @_;
    $fh or $fh = select;

    # Output the head and its terminating blank line:
    $self->head->print;
    $fh->print("\n");  

    # Output either the body or the parts:
    if ($self->is_multipart) {    # Multipart...
	my $boundary = $self->head->multipart_boundary;     # get boundary

	# Preamble:
	$fh->print("This is a multi-part message in MIME format.\n");
	
	# Parts:
	my $part;
	foreach $part ($self->parts) {
	    $fh->print("\n--$boundary\n");
	    $part->print($fh);
	}
	$fh->print("\n--$boundary--\n\n");
    }
    else {                        # Single part...
	$self->print_body;             # body
    }
    1;
}

#------------------------------------------------------------
# print_body
#------------------------------------------------------------

=item print_body [FILEHANDLE]

I<Instance method, override.>
Print the body of the entity to the given FILEHANDLE, or to the 
currently-selected one if none given.  

B<Important note:> the body is output according to the encoding specified 
by  the header (C<'binary'> if no encoding given).  This means that the
following code:

    $ent = new MIME::Entity ["Subject: Greetings\n",
			     "Content-transfer-encoding: base64\n",
			     "\n",
			     "Hi there!\n", 
			     "Bye there!\n"
			     ];
    $ent->print;   # uses print_body() internally

Prints this:

    Subject: Greetings
    Content-transfer-encoding: base64

    SGkgdGhlcmUhCkJ5ZSB0aGVyZSEK

The body is I<stored> in an unencoded form; however, the idea is that
the transfer encoding is used to determine how it should be I<output.>
This means that the C<print()> method is always guaranteed to get you
a sendmail-ready stream whose body is consistent with its head.

If you want the raw body data to be output, you can either read it from
the bodyhandle yourself, or use:

    $ent->bodyhandle->print;

which uses read() calls to extract the information, and thus will 
work with both text and binary bodies.

=cut

sub print_body {
    my ($self, $fh) = @_;
    $fh or $fh = select;

    # Get the encoding:
    my $encoding = ($self->head->mime_encoding || 'binary');
    my $decoder = new MIME::Decoder $encoding;

    # Output the body:
    my $body = $self->bodyhandle;
    my $IO = $body->open("r") || die "open body: $!";
    $decoder->encode($IO, $fh);      # encode it
    $IO->close;
    1;
}

#------------------------------------------------------------

=back

=head1 NOTES

=head2 Under the hood

A B<MIME::Entity> is composed of the following elements:

=over 4

=item *

A I<head>, which is a reference to a MIME::Head object
containing the header information.

=item *

A I<bodyhandle>, which is a reference a MIME::Body object
containing the decoded body data.
(In pre-2.0 releases, this was accessed via I<body>, 
which was a path to a file containing the decoded body.
Integration with Mail::Internet has forced this to change.)

=item *

A list of zero or more I<parts>, each of which is a MIME::Entity 
object.  The number of parts will only be nonzero if the content-type 
is some subtype of C<"multipart">.

Note that, in 2.0+, a multipart entity does I<not> have a body.
Of course, any/all of its component parts can have bodies.

=back


=head2 Design issues

=over

=item Some things just can't be ignored

In multipart messages, the I<"preamble"> is the portion that precedes
the first encapsulation boundary, and the I<"epilogue"> is the portion
that follows the last encapsulation boundary.

According to RFC-1521:

    There appears to be room for additional information prior to the
    first encapsulation boundary and following the final boundary.  These
    areas should generally be left blank, and implementations must ignore
    anything that appears before the first boundary or after the last one.

    NOTE: These "preamble" and "epilogue" areas are generally not used
    because of the lack of proper typing of these parts and the lack
    of clear semantics for handling these areas at gateways,
    particularly X.400 gateways.  However, rather than leaving the
    preamble area blank, many MIME implementations have found this to
    be a convenient place to insert an explanatory note for recipients
    who read the message with pre-MIME software, since such notes will
    be ignored by MIME-compliant software.

In the world of standards-and-practices, that's the standard.  
Now for the practice: 

I<Some "MIME" mailers may incorrectly put a "part" in the preamble>.
Since we have to parse over the stuff I<anyway>, in the future I
I<may> allow the parser option of creating special MIME::Entity objects 
for the preamble and epilogue, with bogus MIME::Head objects.

For now, though, we're MIME-compliant, so I probably won't change
how we work.

=back


=head1 SEE ALSO

MIME::Decoder,
MIME::Entity,
MIME::Head, 
MIME::Parser.


=head1 AUTHOR

Copyright (c) 1996 by Eryq / eryq@rhine.gsfc.nasa.gov

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 2.5 $ $Date: 1996/10/28 18:35:39 $

=cut


#------------------------------------------------------------
# Execute simple test if run as a script...
#------------------------------------------------------------
{ 
  package main; no strict;
  $INC{'MIME/Entity.pm'} = 1;
  eval join('',<main::DATA>) || die "$@ $main::DATA" unless caller();
}
1;           # end the module
__END__

use MIME::Body;
use MIME::Head;

BEGIN { unshift @INC, "./etc" }

print "\n* New entity...\n";
my $e = new MIME::Entity [
			  "Subject: Greetings\n",
			  "Content-transfer-encoding: 7bit\n",
			  "\n",
			  "Hi there, «François Müller»!\n", 
			  "Bye there!\n"
			  ];
$e->print;

print "\n* Build entity, implicit text/plain (7 bit)...\n";
$e = build MIME::Entity 
    Path     => "./testin/short.txt",
$e->print;

print "\n* Build entity, text/plain (base64)...\n";
$e = build MIME::Entity 
    Description => "A short document",
    Path        => "./testin/short.txt",
    Type        => "text/plain",
    Encoding    => "base64";
$e->print;

print "\n* Build complex entity, with one text and one gif file...\n";
$top = build MIME::Entity Type=>"multipart/mixed";
attach $top  Path=>"./testin/short.txt";

attach $top  Path        =>"./testin/short.txt",
             Encoding    => "quoted-printable";

attach $top  Description => "A short document",
             Path        => "./docs/mime-sm.gif",
             Type        => "image/gif",
             Encoding    => "base64";
    
$top->head->add('from',    "me\@myhost.com");
$top->head->add('to',      "you\@yourhost.com");
$top->head->add('subject', "Hello, nurse!");
$top->print;


#------------------------------------------------------------
1;
