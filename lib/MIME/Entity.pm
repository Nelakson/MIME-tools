package MIME::Entity;


=head1 NAME

MIME::Entity - class for parsed-and-decoded MIME message


=head1 SYNOPSIS

    # Create an entity:
    $top = build MIME::Entity From     => 'me@myhost.com',
                              To       => 'you@yourhost.com',
                              Subject  => "Hello, nurse!",
			      Data     => \@my_message;
     
    # Attach stuff to it:
    $top->attach(Path        => $gif_path,
		 Type        => "image/gif",
		 Encoding    => "base64");
         
    # Sign it:
    $top->sign;
    
    # Output it:
    $top->print(\*STDOUT);


=head1 DESCRIPTION

A subclass of B<Mail::Internet>.

This package provides a class for representing MIME message entities,
as specified in RFC 1521, I<Multipurpose Internet Mail Extensions>.


=head1 EXAMPLES

=head2 Construction examples

Create a document for an ordinary 7-bit ASCII text file (lots of 
stuff is defaulted for us):

    $ent = build MIME::Entity Path=>"english-msg.txt";

Create a document for a text file with 8-bit (Latin-1) characters:

    $ent = build MIME::Entity Path     =>"french-msg.txt",
                              Encoding =>"quoted-printable",
                              From     =>'jean.luc@inria.fr',
                              Subject  =>"C'est bon!";

Create a document for a GIF file (the description is completely optional;
note that we have to specify content-type and encoding since they're
not the default values):

    $ent = build MIME::Entity Description => "A pretty picture",
                              Path        => "./docs/mime-sm.gif",
                              Type        => "image/gif",
                              Encoding    => "base64";

Create a document that you already have the text for, using "Data":

    $ent = build MIME::Entity Type        => "text/plain",
                              Encoding    => "quoted-printable",
                              Data        => ["First line.\n",
                                              "Second line.\n",
                                              "Last line.\n"];

Create a multipart message, with the entire structure given
explicitly:

    # Create the top-level, and set up the mail headers:
    $top = MIME::Entity->build(Type     => "multipart/mixed",
                               From     => 'me@myhost.com',
                               To       => 'you@yourhost.com',
                               Subject  => "Hello, nurse!");
    
    # Attachment #1: a simple text document: 
    $top->attach(Path=>"./testin/short.txt");
    
    # Attachment #2: a GIF file:
    $top->attach(Path        => "./docs/mime-sm.gif",
                 Type        => "image/gif",
                 Encoding    => "base64");
     
    # Attachment #3: text we'll create with text we have on-hand:
    $top->attach(Data => $contents);

Suppose you don't know ahead of time that you'll have attachments?
No problem: you can "attach" to singleparts as well:

    $top = MIME::Entity->build(From     => 'me@myhost.com',
			       To       => 'you@yourhost.com',
			       Subject  => "Hello, nurse!",
			       Data     => \@my_message);
    if ($GIF_path) { 
	$top->attach(Path        => $GIF_path,
	             Type        => 'image/gif',
                     Encoding    => '-SUGGEST');
    }

Copy an entity (headers, parts... everything but external body data):

    my $deepcopy = $top->dup;				  



=head2 Access examples 

    # Get the head, a MIME::Head:
    $head = $ent->head;
    
    # Get the body, as a MIME::Body;
    $bodyh = $ent->bodyhandle;
    
    # Get the actual MIME type, in the header:
    $type = $ent->mime_type;

    # Get the effective MIME type (for dealing with nonstandard encodings):
    $eff_type = $ent->effective_type;
     
    # Get preamble, parts, and epilogue:
    $preamble   = $ent->preamble;          # ref to array of lines
    $num_parts  = $ent->parts;
    $first_part = $ent->parts(0);          # an entity
    $epilogue   = $ent->epilogue;          # ref to array of lines


=head2 Manipulation examples

Muck about with the body data:

    # Read the (unencoded) body data:
    if ($io = $ent->open("r")) {
	while (defined($_ = $io->getline)) { print $_ }
	$io->close;
    }
    
    # Write the (unencoded) body data:
    if ($io = $ent->open("w")) {
	foreach (@lines) { $io->print($_) }
	$io->close;
    }
    
    # Delete the files for any external (on-disk) data:
    $ent->purge;

Muck about with the signature:

    # Sign it (automatically removes any existing signature):
    $top->sign(File=>"$ENV{HOME}/.signature");
        
    # Remove any signature within 15 lines of the end:
    $top->remove_sig(15);

Muck about with the headers:

    # Compute content-lengths for singleparts based on bodies:
    #   (Do this right before you print!)
    $entity->sync_headers(Length=>'COMPUTE');

Muck about with the structure:

    # If a 0- or 1-part multipart, collapse to a singlepart:
    $top->make_singlepart;
    
    # If a singlepart, inflate to a multipart with 1 part:
    $top->make_multipart;


=head2 Output examples

Print to filehandles:

    # Print the entire message:
    $top->print(\*STDOUT);
     
    # Print just the header:
    $top->print_header(\*STDOUT);   
    
    # Print just the (encoded) body... includes parts as well!
    $top->print_body(\*STDOUT);

Stringify... note that C<stringify_xx> can also be written C<xx_as_string>;
the methods are synonymous, and neither form will be deprecated:

    # Stringify the entire message:
    print $top->stringify;                   # or $top->as_string
    
    # Stringify just the header:
    print $top->stringify_header;            # or $top->header_as_string
    
    # Stringify just the (encoded) body... includes parts as well!
    print $top->stringify_body;              # or $top->body_as_string

Debug:

    # Output debugging info:
    $entity->dump_skeleton(\*STDERR);



=head1 PUBLIC INTERFACE

=cut

#------------------------------

# Pragmas:
use vars qw(@ISA $VERSION); 
use strict;

# System modules:
use FileHandle;
use Carp;

# Other modules:
use Mail::Internet 1.28 ();
use Mail::Field    1.05 ();

# Kit modules:
use MIME::ToolUtils qw(:config :msgs :utils);
use MIME::Head;
use MIME::Body;
use MIME::Decoder;
use IO::Scalar;
use IO::Wrap;

@ISA = qw(Mail::Internet);


#------------------------------
#
# Globals...
#
#------------------------------

# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4.115 $, 10;

# Boundary counter:
my $BCount = 0;

# Standard "Content-" MIME fields, for scrub():
my $StandardFields = 'Description|Disposition|Id|Type|Transfer-Encoding';

# Known Mail/MIME fields... these, plus some general forms like 
# "x-*", are recognized by build():
my %KnownField = map {$_=>1} 
qw(
   bcc         cc          comments      date          encrypted 
   from        keywords    message-id    mime-version  organization
   received    references  reply-to      return-path   sender        
   subject     to
   );

# Fallback preamble and epilogue:
my $DefPreamble = [ "This is a multi-part message in MIME format...\n" ];
my $DefEpilogue = [ ];


#==============================
#
# Utilities, private
#

#------------------------------
#
# known_field FIELDNAME
#
# Is this a recognized Mail/MIME field?
#
sub known_field {
    my $field = lc(shift);
    $KnownField{$field} or ($field =~ m{^(content|resent|x)-.});
}

#------------------------------
#
# make_boundary
#
# Return a unique boundary string.
# This is used both internally and by MIME::ParserBase, but it is NOT in
# the public interface!  Do not use it!
#
# We generate one containing a "=_", as RFC1521 suggests.
#
sub make_boundary {
    return "----------=_".scalar(time)."-$$-".$BCount++;
}






#==============================

=head2 Construction

=over 4

=cut


#------------------------------

=item new [SOURCE]

I<Class method.>
Create a new, empty MIME entity.
Basically, this uses the Mail::Internet constructor...

If SOURCE is an ARRAYREF, it is assumed to be an array of lines
that will be used to create both the header and an in-core body.

Else, if SOURCE is defined, it is assumed to be a filehandle
from which the header and in-core body is to be read. 

B<Note:> in either case, the body will not be I<parsed:> merely read!

=cut

sub new {
    my $class = shift;
    my $self = $class->Mail::Internet::new(@_);   # inherited
    $self->{ME_Parts} = [];                       # no parts extracted
    $self;
}


#------------------------------

=item add_part ENTITY, [OFFSET]

I<Instance method.>
Assuming we are a multipart message, add a body part (a MIME::Entity)
to the array of body parts.  Returns the part that was just added.

If OFFSET is positive, the new part is added at that offset from the
beginning of the array of parts.  If it is negative, it counts from
the end of the array.  (An INDEX of -1 will place the new part at the
very end of the array, -2 will place it as the penultimate item in the
array, etc.)  If OFFSET is not given, the new part is added to the end
of the array.

B<Warning:> in general, you only want to attach parts to entities
with a content-type of C<multipart/*>).

I<Thanks to Jason L Tibbitts III for providing support for OFFSET.>

=cut

sub add_part {
    my ($self, $part, $index) = @_;
    defined($index) or $index = -1;

    # Make $index count from the end if negative:
    $index = $#{$self->{ME_Parts}} + 2 + $index if ($index < 0);
    splice(@{$self->{ME_Parts}}, $index, 0, $part);
    $part;
}

#------------------------------

=item attach PARAMHASH

I<Instance method.>
The real quick-and-easy way to create multipart messages.
The PARAMHASH is used to C<build> a new entity; this method is
basically equivalent to:

    $entity->add_part(ref($entity)->build(PARAMHASH, Top=>0));

B<Note:> normally, you attach to multipart entities; however, if you 
attach something to a singlepart (like attaching a GIF to a text
message), the singlepart will be coerced into a multipart automatically.

=cut 

sub attach {
    my $self = shift;
    $self->make_multipart;
    $self->add_part(ref($self)->build(@_, Top=>0));
}

#------------------------------

=item build PARAMHASH

I<Class/instance method.>
A quick-and-easy catch-all way to create an entity.  Use it like this
to build a "normal" single-part entity:

   $ent = build MIME::Entity Type     => "image/gif",
		             Encoding => "base64",
                             Path     => "/path/to/xyz12345.gif",
                             Filename => "saveme.gif",
                             Disposition => "attachment";

And like this to build a "multipart" entity:

   $ent = build MIME::Entity Type     => "multipart/mixed",
                             Boundary => "---1234567";

A minimal MIME header will be created.  If you want to add or modify
any header fields afterwards, you can of course do so via the underlying 
head object... but hey, there's now a prettier syntax!

   $ent = build MIME::Entity Type           =>"multipart/mixed",
                             From           => $myaddr,
                             Subject        => "Hi!",
                             'X-Certified'  => ['SINED','SEELED','DELIVERED'];

Normally, an C<X-Mailer> header field is output which contains this 
toolkit's name and version (plus this module's RCS version).
This will allow any bad MIME we generate to be traced back to us.
You can of course overwrite that header with your own:

   $ent = build MIME::Entity  Type        => "multipart/mixed",
                              'X-Mailer'  => "myprog 1.1";

Or remove it entirely:

   $ent = build MIME::Entity Type       => "multipart/mixed",
                             'X-Mailer' => undef;

OK, enough hype.  The parameters are:

=over 4

=item (FIELDNAME)

Any field you want placed in the message header, taken from the
standard list of header fields (you don't need to worry about case):

    Bcc           Encrypted     Received      Sender         
    Cc            From          References    Subject 
    Comments	  Keywords      Reply-To      To 
    Content-*	  Message-ID    Resent-*      X-*
    Date          MIME-Version  Return-Path   
                  Organization

To give experienced users some veto power, these fields will be set 
I<after> the ones I set... so be careful: I<don't set any MIME fields>
(like C<Content-type>) unless you know what you're doing!

To specify a fieldname that's I<not> in the above list, even one that's
identical to an option below, just give it with a trailing C<":">,
like C<"My-field:">.  When in doubt, that I<always> signals a mail 
field (and it sort of looks like one too).

=item Boundary

I<Multipart entities only. Optional.>  
The boundary string.  As per RFC-1521, it must consist only
of the characters C<[0-9a-zA-Z'()+_,-./:=?]> and space (you'll be
warned, and your boundary will be ignored, if this is not the case).
If you omit this, a random string will be chosen... which is probably 
safer.

=item Charset

I<Optional.>  
The character set.

=item Data

I<Single-part entities only. Optional.>  
An alternative to Path (q.v.): the actual data, either as a scalar
or an array reference (whose elements are joined together to make
the actual scalar).  The body is opened on the data using 
MIME::Body::Scalar.

=item Description

I<Optional.>  
The text of the content-description.  
If you don't specify it, the field is not put in the header.

=item Disposition

I<Optional.>  
The basic content-disposition (C<"attachment"> or C<"inline">).
If you don't specify it, it defaults to "inline" for backwards
compatibility.  I<Thanks to Kurt Freytag for suggesting this feature.>

=item Encoding

I<Optional.>  
The content-transfer-encoding.
If you don't specify it, the field is not put in the header... which means 
that the encoding implicitly defaults to C<"7bit"> as per RFC-1521.  
I<Do yourself a favor: put it in.>
You can also give the special value '-SUGGEST', to have it chosen for you.

=item Filename

I<Single-part entities only. Optional.>  
The recommended filename.  Overrides any name extracted from C<Path>.
The information is stored both the deprecated (content-type) and
preferred (content-disposition) locations.  If you explicitly want to 
I<avoid> a recommended filename (even when Path is used), supply this 
as empty or undef.

=item Path

I<Single-part entities only. Optional.>  
The path to the file to attach.  The body is opened on that file
using MIME::Body::File.

=item Top

I<Optional.>  
Is this a top-level entity?  If so, it must sport a MIME-Version.
The default is true.  (NB: look at how C<attach()> uses it.)

=item Type

I<Optional.>  
The basic content-type (C<"text/plain">, etc.). 
If you don't specify it, it defaults to C<"text/plain"> 
as per RFC-1521.  I<Do yourself a favor: put it in.>

=back

=cut

sub build {
    my ($self, @paramlist) = @_;
    my %params = @paramlist;
    my ($field, $filename, $boundary);

    # Create a new entity, if needed:
    ref($self) or $self = $self->new;


    ### GET INFO...

    # Get sundry field:
    my $type         = $params{Type} || 'text/plain';
    my $charset      = $params{Charset};
    my $is_multipart = ($type =~ m{^multipart/}i);
    my $encoding     = $params{Encoding} || '';
    my $desc         = $params{Description};
    my $top          = exists($params{Top}) ? $params{Top} : 1;
    my $disposition  = $params{Disposition} || 'inline';

    # Get recommended filename, allowing explicit no-value value:
    my ($path_fname) = (($params{Path}||'') =~ m{([^/]+)\Z});
    $filename = (exists($params{Filename}) ? $params{Filename} : $path_fname);
    $filename = undef if (defined($filename) and $filename eq '');
    
    # Type-check sanity:
    if ($type =~ m{^(multipart|message)/}) {
	($encoding =~ /^(|7bit|8bit|binary|-suggest)$/i) 
	    or croak "can't have encoding $encoding for message type $type!";
    }

    # Multipart or not? Do sanity check and fixup:
    if ($is_multipart) {      # multipart...
	
	# Get any supplied boundary, and check it:
	if (defined($boundary = $params{Boundary})) {  # they gave us one...
	    if ($boundary eq '') {
		whine "empty string not a legal boundary: I'm ignoring it";
		$boundary = undef;
	    }
	    elsif ($boundary =~ m{[^0-9a-zA-Z\'\(\)\+\_\,\.\/\:\=\?\- ]}) {
		whine "boundary ignored: illegal characters ($boundary)";
		$boundary = undef;
	    }
	}
	
	# If we have to roll our own boundary, do so:
	defined($boundary) or $boundary = make_boundary();
    }
    else {                    # single part...
	# Create body:
	if ($params{Path}) {
	    $self->bodyhandle(new MIME::Body::File $params{Path});
	}
	elsif (defined($params{Data})) {
	    $self->bodyhandle(new MIME::Body::Scalar $params{Data});
	}
	else { 
	    die "can't build entity: no body, and not multipart!\n";
	}

	# Check whether we need to binmode():   [Steve Kilbane]
	$self->bodyhandle->binmode(1) unless textual_type($type);
    }


    ### MAKE HEAD...

    # Create head:
    my $head = new MIME::Head;
    $self->head($head);
    $head->modify(1);

    # Add content-type field:
    $field = new Mail::Field 'Content_type';         # not a typo :-(
    $field->type($type);
    $field->charset($charset)    if $charset;
    $field->name($filename)      if defined($filename);
    $field->boundary($boundary)  if defined($boundary);
    $head->replace('Content-type', $field->stringify);

    # Now that both body and content-type are available, we can suggest 
    # content-transfer-encoding (if desired);
    $encoding = $self->suggest_encoding if (lc($encoding) eq '-suggest');

    # Add content-disposition field (if not multipart):
    unless ($is_multipart) {
	$field = new Mail::Field 'Content_disposition';  # not a typo :-(
	$field->type($disposition);
	$field->filename($filename) if defined($filename);
	$head->replace('Content-disposition', $field->stringify);
    }

    # Add other MIME fields:
    $head->replace('Content-transfer-encoding', $encoding) if $encoding;
    $head->replace('Content-description', $desc)           if $desc;
    $head->replace('MIME-Version', '1.0')                  if $top;

    # Add the X-Mailer field, if top level (use default value if not given):
    $top and $head->replace('X-Mailer', 
			    "MIME-tools ".(0+$CONFIG{VERSION}).
			    " (Entity "  .(0+$VERSION).")"); 
	
    # Add remaining user-specified fields, if any:
    while (@paramlist) {
	my ($tag, $value) = (shift @paramlist, shift @paramlist);

	# Get fieldname, if that's what it is:
	if    ($tag =~ /^-/)  { $tag = lc($') }    # old style, b.c.
	elsif ($tag =~ /:$/ ) { $tag = lc($`) }    # new style
	elsif (known_field(lc($tag)))     { 1 }    # known field
	else { next; }                             # not a field

	# Clear head, get list of values, and add them:
	$head->delete($tag);
	foreach $value (ref($value) ? @$value : ($value)) {
	    (defined($value) && ($value ne '')) or next;
	    $head->add($tag, $value);
	}
    }
    
    # Done!
    $self;
}

#------------------------------

=item dup

I<Instance method.> 
Duplicate the entity.  Does a deep, recursive copy, I<but beware:>
external data in bodyhandles is I<not> copied to new files!  
Changing the data in one entity's data file, or purging that entity, 
I<will> affect its duplicate.  Entities with in-core data probably need
not worry.

=cut

sub dup {
    my $self = shift;
    local($_);

    # Self (this will also dup the header):
    my $dup = bless $self->SUPER::dup(), ref($self);

    # Any simple inst vars:
    foreach (keys %$self) {$dup->{$_} = $self->{$_} unless ref($self->{$_})};
    
    # Bodyhandle:
    $dup->bodyhandle($self->bodyhandle ? $self->bodyhandle->dup : undef);

    # Preamble and epilogue:
    foreach (qw(ME_Preamble ME_Epilogue)) {
	$dup->{$_} = [@{$self->{$_}}]  if $self->{$_};
    }

    # Parts:
    $dup->{ME_Parts} = [];
    foreach (@{$self->{ME_Parts}}) { push @{$dup->{ME_Parts}}, $_->dup }

    # Done!
    $dup;
}

=back

=cut





#==============================

=head2 Access

=over 4

=cut


#------------------------------

=item body [VALUE]

I<Instance method.>
Get or set the body, as an array of lines.  This should be regarded
as a read-only data structure: changing its contents will have 
unpredictable results (you can, of course, make your own copy,
and work with that).  

Provided for compatibility with Mail::Internet, and it might not 
be as efficient as you'd like.  Also, it's somewhat silly/wrongheaded
for binary bodies, like GIFs and tar files.  Instead, use the bodyhandle()
method to get and use a MIME::Body.  The content-type of the entity
will tell you whether that body is best read as text (via getline())
or raw data (via read()).

=cut

sub body {
    my ($self, $value) = @_;
    if (@_ > 1) {      # setting body line(s)...
	return $self->bodyhandle(new MIME::Body::Scalar $value);
    }
    else {             # getting body lines...
	return ($self->bodyhandle ? [$self->bodyhandle->as_lines] : []);
    }
}

#------------------------------

=item bodyhandle [VALUE]

I<Instance method.>
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

#------------------------------

=item effective_type [MIMETYPE]

I<Instance method.>
Set/get the I<effective> MIME type of this entity.  This is I<usually>
identical to the actual (or defaulted) MIME type, but in some cases 
it differs.  For example, from RFC-2045:

   Any entity with an unrecognized Content-Transfer-Encoding must be
   treated as if it has a Content-Type of "application/octet-stream",
   regardless of what the Content-Type header field actually says.

Why? because if we can't decode the message, then we have to take
the bytes as-is, in their (unrecognized) encoded form.  So the
message ceases to be a "text/foobar" and becomes a bunch of undecipherable
bytes -- in other words, an "application/octet-stream".

Such an entity, if parsed, would have its effective_type() set to
C<"application/octet_stream">, although the mime_type() and the contents 
of the header would remain the same.

If there is no known effective type, the method just returns what 
mime_type() would.

B<Warning:> the effective type is "sticky"; once set, that effective_type()
will always be returned even if the conditions that necessitated setting
the effective type become no longer true.

=cut

sub effective_type {
    my $self = shift;
    $self->{ME_EffType} = shift if @_;
    return ($self->{ME_EffType} ? lc($self->{ME_EffType}) : $self->mime_type);
}


#------------------------------

=item epilogue [LINES]

I<Instance method.>
Get/set the text of the epilogue, as an array of newline-terminated LINES.
Returns a reference to the array of lines, or undef if no epilogue exists.

If there is a epilogue, it is output when printing this entity; otherwise,
a default epilogue is used.  Setting the epilogue to undef (not []!) causes 
it to fallback to the default.

=cut

sub epilogue {
    my ($self, $lines) = @_;
    $self->{ME_Epilogue} = $lines if @_ > 1;
    $self->{ME_Epilogue};
}

#------------------------------

=item head [VALUE]

I<Instance method.>
Get/set the head. 

If there is no VALUE given, returns the current head.  If none
exists, an empty instance of MIME::Head is created, set, and returned.

B<Note:> This is a patch over a problem in Mail::Internet, which doesn't 
provide a method for setting the head to some given object.

=cut

sub head { 
    my ($self, $value) = @_;
    (@_ > 1) and $self->{'mail_inet_head'} = $value;
    $self->{'mail_inet_head'} ||= new MIME::Head;       # KLUDGE!
}

#------------------------------

=item is_multipart

I<Instance method.>
Does this entity's MIME type indicate that it's a multipart entity?
Returns undef (false) if the answer couldn't be determined, 0 (false)
if it was determined to be false, and true otherwise.

Note that this says nothing about whether or not parts were extracted.

=cut

# NOTE: should we use effective_type() instead?
sub is_multipart {
    my $self = shift;
    $self->head or return undef;        # no head, so no MIME type!
    my ($type, $subtype) = split('/', $self->head->mime_type);
    (($type eq 'multipart') ? 1 : 0);
}

#------------------------------

=item mime_type

I<Instance method.>
A purely-for-convenience method.  This simply relays the request to the 
associated MIME::Head object. 
If there is no head, returns undef in a scalar context and
the empty array in a list context.

=cut

sub mime_type {
    my $self = shift;
    $self->head or return (wantarray ? () : undef);
    $self->head->mime_type;
}

#------------------------------

=item open READWRITE

I<Instance method.>
A purely-for-convenience method.  This simply relays the request to the 
associated MIME::Body object (see MIME::Body::open()). 
READWRITE is either 'r' (open for read) or 'w' (open for write).

If there is no body, returns false.

=cut

sub open {
    my $self = shift;
    $self->bodyhandle and $self->bodyhandle->open(@_);
}

#------------------------------

=item parts

=item parts INDEX

=item parts ARRAYREF

I<Instance method.>
Return the MIME::Entity objects which are the sub parts of this
entity (if any).

I<If no argument is given,> returns the array of all sub parts, 
returning the empty array if there are none (e.g., if this is a single 
part message, or a degenerate multipart).  In a scalar context, this 
returns you the number of parts.

I<If an integer INDEX is given,> return the INDEXed part, 
or undef if it doesn't exist.

I<If an ARRAYREF to an array of parts is given,> then this method I<sets> 
the parts to a copy of that array, and returns the parts.

B<Note:> for multipart messages, the preamble and epilogue are I<not> 
considered parts.  If you need them, use the C<preamble()> and C<epilogue()> 
methods.

B<Note:> there are ways of parsing with a MIME::Parser which cause
certain message parts (such as those of type C<message/rfc822>)
to be "reparsed" into pseudo-multipart entities.  You should read the
documentation for those options carefully: it I<is> possible for
a diddled entity to not be multipart, but still have parts attached to it! 

=cut

sub parts {
    my $self = shift;
    ref($_[0]) and return @{$self->{ME_Parts} = [@{$_[0]}]};  # set the parts
    (@_ ? $self->{ME_Parts}[$_[0]] : @{$self->{ME_Parts}});
}
sub part {
    usage "deprecated; please use the identical parts() method instead";
    shift->parts(@_);
}

#------------------------------

=item preamble [LINES]

I<Instance method.>
Get/set the text of the preamble, as an array of newline-terminated LINES.
Returns a reference to the array of lines, or undef if no preamble exists
(e.g., if this is a single-part entity).

If there is a preamble, it is output when printing this entity; otherwise,
a default preamble is used.  Setting the preamble to undef (not []!) causes 
it to fallback to the default.

=cut

sub preamble {
    my ($self, $lines) = @_;
    $self->{ME_Preamble} = $lines if @_ > 1;
    $self->{ME_Preamble};
}





=back

=cut




#==============================

=head2 Manipulation

=over 4

=cut

#------------------------------

=item make_multipart [SUBTYPE]

I<Instance method.>
Force the entity to be a multipart, if it isn't already.
The content headers from the top-level are bumped down to the demoted part.
The actual type will be "multipart/SUBTYPE" (default SUBTYPE is "mixed").

Returns 'DONE'    if we really did inflate a singlepart to a multipart.
Returns 'ALREADY' (and does nothing) if entity is I<already> multipart.

=cut

sub make_multipart {
    my ($self, $subtype) = @_;
    my $tag;
    $subtype ||= 'mixed';

    # Trap for simple case:
    return 'ALREADY' if $self->is_multipart;       # already a multipart?

    # Rip out our guts, and spew them into our future part:
    my $part = bless {%$self}, ref($self);         # part is a shallow copy
    %$self = ();                                   # lobotomize ourselves!
    $self->head($part->head->dup);                 # dup the header
    
    # Remove content headers from top-level, and set it up as a multipart:
    foreach $tag (grep {/^content-/i} $self->head->tags) {
	$self->head->delete($tag);
    }
    $self->head->mime_attr('Content-type'          => "multipart/$subtype");
    $self->head->mime_attr('Content-type.boundary' => make_boundary());

    # Remove NON-content headers from the part:
    foreach $tag (grep {!/^content-/i} $part->head->tags) {
	$part->head->delete($tag);
    }
    
    # Add the part:
    $self->{ME_Parts} = [];   # WARNING: any msg/rfc822 pseudo-parts are lost!
    $self->add_part($part);
    'DONE';
}

#------------------------------

=item make_singlepart

I<Instance method.>
If the entity is a multipart message with one part, this tries hard to
rewrite it as a singlepart, by replacing the content (and content headers)
of the top level with those of the part.  Also crunches 0-part multiparts
into singleparts.

Returns 'DONE'    if we really did collapse a multipart to a singlepart.
Returns 'ALREADY' (and does nothing) if entity is already a singlepart. 
Returns '0'       (and does nothing) if it can't be made into a singlepart.

=cut

sub make_singlepart {
    my $self = shift;

    # Trap for simple cases:
    return 'ALREADY' if !$self->is_multipart;      # already a singlepart?
    return '0' if ($self->parts > 1);              # can this even be done?

    # Do it:
    if ($self->parts == 1) {    # one part
	my $part = $self->parts(0);
	my $tag;

	# Get rid of all our existing content info:
	foreach $tag (grep {/^content-/i} $self->head->tags) {
	    $self->head->delete($tag);
	}
	
	# Populate ourselves with any content info from the part:
	foreach $tag (grep {/^content-/i} $part->head->tags) {
	    foreach ($part->head->get($tag)) { $self->head->add($tag, $_) }
	}

	# Save reconstructed header, replace our guts, and restore header:
	my $new_head = $self->head;
	%$self = %$part;               # shallow copy is ok!
	$self->head($new_head);

	# One more thing: the part *may* have been a multi with 0 or 1 parts!
	return $self->make_singlepart(@_) if $self->is_multipart;
    }
    else {                      # no parts!
	$self->head->mime_attr('Content-type'=>'text/plain');   # simple
    }
    'DONE';
}

#------------------------------

=item purge

I<Instance method.>
Recursively purge (e.g., unlink) all external (e.g., on-disk) body parts 
in this message.  See MIME::Body::purge() for details.

I wouldn't attempt to read those body files after you do this, for
obvious reasons.  As of MIME-tools 4.x, each body's path I<is> undefined
after this operation.  I warned you I might do this; truly I did.

I<Thanks to Jason L. Tibbitts III for suggesting this method.>

=cut

sub purge {
    my $self = shift;
    $self->bodyhandle and $self->bodyhandle->purge;      # purge me
    foreach ($self->parts) { $_->purge }                 # recurse
    1;
}

#------------------------------
#
# _do_remove_sig
#
# Private.  Remove a signature within NLINES lines from the end of BODY.
# The signature must be flagged by a line containing only "-- ".

sub _do_remove_sig {
    my ($body, $nlines) = @_;
    $nlines ||= 10;
    my $i = 0;

    my $line = int(@$body) || return;
    while ($i++ < $nlines and $line--) {
	if ($body->[$line] =~ /\A--[ \040][\r\n]+\Z/) {
	    $#{$body} = $line-1;
	    return;
	}
    }
}

#------------------------------

=item remove_sig [NLINES]

I<Instance method, override.>
Attempts to remove a user's signature from the body of a message. 

It does this by looking for a line matching C</^-- $/> within the last 
C<NLINES> of the message.  If found then that line and all lines after 
it will be removed. If C<NLINES> is not given, a default value of 10 
will be used.  This would be of most use in auto-reply scripts.

For MIME entity, this method is reasonably cautious: it will only
attempt to un-sign a message with a content-type of C<text/*>.

If you send remove_sig() to a multipart entity, it will relay it to 
the first part (the others usually being the "attachments").

B<Warning:> currently slurps the whole message-part into core as an
array of lines, so you probably don't want to use this on extremely 
long messages.

Returns truth on success, false on error.

=cut

sub remove_sig {
    my $self = shift;
    my $nlines = shift;

    # Handle multiparts:
    $self->is_multipart and return $self->{ME_Parts}[0]->remove_sig(@_);

    # Refuse non-textual unless forced:
    textual_type($self->head->mime_type)
	or return error "I won't un-sign a non-text message unless I'm forced";
    
    # Get body data, as an array of newline-terminated lines:
    $self->bodyhandle or return undef;
    my @body = $self->bodyhandle->as_lines;

    # Nuke sig:
    _do_remove_sig(\@body, $nlines);

    # Output data back into body:
    my $io = $self->bodyhandle->open("w");
    foreach (@body) { $io->print($_) };  # body data
    $io->close;

    # Done!
    1;       
}

#------------------------------

=item sign PARAMHASH

I<Instance method, override.>
Append a signature to the message.  The params are:

=over 4

=item Attach

Instead of appending the text, add it to the message as an attachment.
The disposition will be C<inline>, and the description will indicate
that it is a signature.  The default behavior is to append the signature 
to the text of the message (or the text of its first part if multipart).
I<MIME-specific; new in this subclass.>

=item File

Use the contents of this file as the signature.  
Fatal error if it can't be read.
I<As per superclass method.>

=item Force

Sign it even if the content-type isn't C<text/*>.  Useful for
non-standard types like C<x-foobar>, but be careful!
I<MIME-specific; new in this subclass.>

=item Remove

Normally, we attempt to strip out any existing signature.
If true, this gives us the NLINES parameter of the remove_sig call.
If zero but defined, tells us I<not> to remove any existing signature.
If undefined, removal is done with the default of 10 lines.
I<New in this subclass.>

=item Signature

Use this text as the signature.  You can supply it as either
a scalar, or as a ref to an array of newline-terminated scalars.
I<As per superclass method.>

=back

For MIME messages, this method is reasonably cautious: it will only
attempt to sign a message with a content-type of C<text/*>, unless
C<Force> is specified.

If you send this message to a multipart entity, it will relay it to 
the first part (the others usually being the "attachments").

B<Warning:> currently slurps the whole message-part into core as an
array of lines, so you probably don't want to use this on extremely 
long messages.

Returns true on success, false otherwise.

=cut

sub sign {
    my $self = shift;
    my %params = @_;
    my $io;

    # If multipart and not attaching, try to sign our first part:
    if ($self->is_multipart and !$params{Attach}) {
	return $self->parts(0)->sign(@_);
    }

    # Get signature:
    my $sig;
    if (defined($sig = $params{Signature})) {    # scalar or array
	$sig = (ref($sig) ? join('', @$sig) : $sig);
    }
    elsif ($params{File}) {                      # file contents
	open SIG, $params{File} or croak "can't open $params{File}: $!";
	$sig = join('', SIG->getlines);
	close SIG;
    }
    else {
	croak "no signature given!";
    }

    # Add signature to message as appropriate:
    if ($params{Attach}) {      # Attach .sig as new part...
	return $self->attach(Type        => 'text/plain',
			     Description => 'Signature',
			     Disposition => 'inline',
			     Encoding    => '-SUGGEST',
			     Data        => $sig);
    }
    else {                      # Add text of .sig to body data...

	# Refuse non-textual unless forced:
	($self->head->mime_type =~ m{text/}i or $params{Force}) or
	    return error "I won't sign a non-text message unless I'm forced";

	# Get body data, as an array of newline-terminated lines:
	$self->bodyhandle or return undef;
	my @body = $self->bodyhandle->as_lines;
	
	# Nuke any existing sig?
	if (!defined($params{Remove}) || ($params{Remove} > 0)) {
	    _do_remove_sig(\@body, $params{Remove});
	}

	# Output data back into body, followed by signature:
	my $line;
	$io = $self->open("w");
	foreach $line (@body) { $io->print($line) };      # body data
	(($body[-1]||'') =~ /\n\Z/) or $io->print("\n");  # ensure final \n
	$io->print("-- \n$sig");                          # separator + sig
	$io->close;	
	return 1;         # done!
    }
}

#------------------------------

=item suggest_encoding

I<Instance method.>
Based on the effective content type, return a good suggested encoding.

C<text> and C<message> types have their bodies scanned line-by-line
for 8-bit characters and long lines; lack of either means that the
message is 7bit-ok.  Other types are chosen independent of their body:

    Major type:       7bit ok?    Suggested encoding:
    ------------------------------------------------------------
    text              yes         7bit
    text              no          quoted-printable    
    message           yes         7bit
    message           no          binary    
    multipart         *           binary (in case some parts are not ok)
    image, etc...     *           base64

=cut

### TO DO: resolve encodings of nested entities (possibly in sync_headers).

sub suggest_encoding {
    my $self = shift;

    my ($type) = split '/', $self->effective_type;
    if (($type eq 'text') || ($type eq 'message')) {    # scan message body
	$self->bodyhandle || return ($self->parts ? 'binary' : '7bit');
	my ($IO, $unclean);
	if ($IO = $self->bodyhandle->open("r")) {

	    # Scan message for 7bit-cleanliness:
	    while (defined($_ = $IO->getline)) {
		last if ($unclean = ((length($_) > 999) or /[\200-\377]/));
	    }
	    
	    # Return '7bit' if clean; try and encode if not...
	    # Note that encodings are not permitted for messages!
	    return ($unclean 
		    ? (($type eq 'message') ? 'binary' : 'quoted-printable')
		    : '7bit'); 
	}
    }
    else {
	return ($type eq 'multipart') ? 'binary' : 'base64';
    }
}

#------------------------------

=item sync_headers OPTIONS

I<Instance method.>
This method does a variety of activities which ensure that
the MIME headers of an entity "tree" are in-synch with the body parts 
they describe.  It can be as expensive an operation as printing
if it involves pre-encoding the body parts; however, the aim is to
produce fairly clean MIME.  B<You will usually only need to invoke
this if processing and re-sending MIME from an outside source.>

The OPTIONS is a hash, which describes what is to be done.

=over 4


=item Length

One of the "official unofficial" MIME fields is "Content-Length".
Normally, one doesn't care a whit about this field; however, if
you are preparing output destined for HTTP, you may.  The value of
this option dictates what will be done:

B<COMPUTE> means to set a C<Content-Length> field for every non-multipart 
part in the entity, and to blank that field out for every multipart 
part in the entity. 

B<ERASE> means that C<Content-Length> fields will all
be blanked out.  This is fast, painless, and safe.

B<Any false value> (the default) means to take no action.


=item Nonstandard

Any header field beginning with "Content-" is, according to the RFC,
a MIME field.  However, some are non-standard, and may cause problems
with certain MIME readers which interpret them in different ways.

B<ERASE> means that all such fields will be blanked out.  This is
done I<before> the B<Length> option (q.v.) is examined and acted upon.

B<Any false value> (the default) means to take no action.


=back

Returns a true value if everything went okay, a false value otherwise.

=cut

sub sync_headers {
    my $self = shift;    
    my $opts = ((int(@_) % 2 == 0) ? {@_} : shift);
    my $ENCBODY;     # keep it around until done!

    # Get options:
    my $o_nonstandard = ($opts->{Nonstandard} || 0);
    my $o_length      = ($opts->{Length}      || 0);
    
    # Get head:
    my $head = $self->head;
    
    # What to do with "nonstandard" MIME fields?
    if ($o_nonstandard eq 'ERASE') {       # Erase them...
	my $tag;
	foreach $tag ($head->tags()) {
	    if (($tag =~ /\AContent-/i) && 
		($tag !~ /\AContent-$StandardFields\Z/io)) {
		$head->delete($tag);
	    }
	}
    }

    # What to do with the "Content-Length" MIME field?
    if ($o_length eq 'COMPUTE') {        # Compute the content length...
	my $content_length = '';

	# We don't have content-lengths in multiparts...
	if ($self->is_multipart) {           # multipart...
	    $head->delete('Content-length');
	}
	else {                               # singlepart...

	    # Get the encoded body, if we don't have it already:
	    unless ($ENCBODY) {
		$ENCBODY = tmpopen() || die "can't open tmpfile";
		$self->print_body($ENCBODY);    # write encoded body to tmpfile
	    }
	    
	    # Analyse it:
	    $ENCBODY->seek(0,2);                # fast-forward
	    $content_length = $ENCBODY->tell;   # get encoded length
	    $ENCBODY->seek(0,0);                # rewind 	
	    
	    # Remember:   
	    $self->head->replace('Content-length', $content_length);	
	}
    }
    elsif ($o_length eq 'ERASE') {         # Erase the content-length...
	$head->delete('Content-length');
    }

    # Done with everything for us!
    undef($ENCBODY);
 
    # Recurse:
    my $part;
    foreach $part ($self->parts) { $part->sync_headers($opts) or return undef }
    1;
}

#------------------------------

=item tidy_body

I<Instance method, override.>
Currently unimplemented for MIME messages.  Does nothing, returns false.

=cut

sub tidy_body {
    carp "MIME::Entity::tidy_body currently does nothing" if $^W;
    0;
}

=back

=cut





#==============================

=head2 Output 

=over 4

=cut

#------------------------------

=item dump_skeleton [FILEHANDLE]

I<Instance method.>
Dump the skeleton of the entity to the given FILEHANDLE, or
to the currently-selected one if none given.  

Each entity is output with an appropriate indentation level,
the following selection of attributes:

    Content-type: multipart/mixed
    Effective-type: multipart/mixed
    Body-file: NONE
    Subject: Hey there!
    Num-parts: 2

This is really just useful for debugging purposes; I make no guarantees
about the consistency of the output format over time.

=cut

sub dump_skeleton {
    my ($self, $fh, $indent) = @_;
    $fh or $fh = select;
    defined($indent) or $indent = 0;
    my $ind = '    ' x $indent;
    my $part;
    no strict 'refs';


    # The content type:
    print $fh $ind,"Content-type: ",   ($self->mime_type||'UNKNOWN'),"\n";
    print $fh $ind,"Effective-type: ", ($self->effective_type||'UNKNOWN'),"\n";

    # The name of the file containing the body (if any!):
    my $path = ($self->bodyhandle ? $self->bodyhandle->path : undef);
    print $fh $ind, "Body-file: ", ($path || 'NONE'), "\n";

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

#------------------------------

=item print [OUTSTREAM]

I<Instance method, override.>
Print the entity to the given OUTSTREAM, or to the currently-selected
filehandle if none given.  OUTSTREAM can be a filehandle, or any object 
that reponds to a print() message. 

The entity is output as a valid MIME stream!  This means that the 
header is always output first, and the body data (if any) will be 
encoded if the header says that it should be.
For example, your output may look like this:

    Subject: Greetings
    Content-transfer-encoding: base64
     
    SGkgdGhlcmUhCkJ5ZSB0aGVyZSEK

I<If this entity has MIME type "multipart/*",> 
the preamble, parts, and epilogue are all output with appropriate
boundaries separating each.  
Any bodyhandle is ignored:

    Content-type: multipart/mixed; boundary="*----*"
    Content-transfer-encoding: 7bit
    
    [Preamble]
    --*----*
    [Entity: Part 0]
    --*----*
    [Entity: Part 1]
    --*----*--
    [Epilogue]

I<If this entity has a single-part MIME type with no attached parts,>
then we're looking at a normal singlepart entity: the body is output 
according to the encoding specified by the header.  
If no body exists, a warning is output and the body is treated as empty:

    Content-type: image/gif
    Content-transfer-encoding: base64
    
    [Encoded body]

I<If this entity has a single-part MIME type but it also has parts,> 
then we're probably looking at a "re-parsed" singlepart, usually one
of type C<message/*> (you can get entities like this if you set the 
C<parse_nested_messages(NEST)> option on the parser to true).
In this case, the parts are output with single blank lines separating each,
and any bodyhandle is ignored:

    Content-type: message/rfc822
    Content-transfer-encoding: 7bit
    
    [Entity: Part 0]
    
    [Entity: Part 1]

In all cases, when outputting a "part" of the entity, this method 
is invoked recursively.

B<Note:> the output is very likely I<not> going to be identical
to any input you parsed to get this entity.  If you're building
some sort of email handler, it's up to you to save this information.

=cut

sub print {
    my ($self, $out) = @_;
    $out = wraphandle($out || select);             # get a printable output
    
    $self->print_header($out);   # the header
    $out->print("\n");
    $self->print_body($out);     # the "stuff after the header"
}

#------------------------------

=item print_body [OUTSTREAM]

I<Instance method, override.>
Print the body of the entity to the given OUTSTREAM, or to the 
currently-selected filehandle if none given.  OUTSTREAM can be a 
filehandle, or any object that reponds to a print() message. 

The body is output for inclusion in a valid MIME stream; this means 
that the body data will be encoded if the header says that it should be.

B<Note:> by "body", we mean "the stuff following the header".
A printed multipart body includes the printed representations of its subparts.

B<Note:> The body is I<stored> in an un-encoded form; however, the idea is that
the transfer encoding is used to determine how it should be I<output.>
This means that the C<print()> method is always guaranteed to get you
a sendmail-ready stream whose body is consistent with its head.
If you want the I<raw body data> to be output, you can either read it from
the bodyhandle yourself, or use:

    $ent->bodyhandle->print($outstream);

which uses read() calls to extract the information, and thus will 
work with both text and binary bodies.

B<Warning:> Please supply an OUTSTREAM.  This override method differs
from Mail::Internet's behavior, which outputs to the STDOUT if no 
filehandle is given: this may lead to confusion.

=cut

sub print_body {
    my ($self, $out) = @_;
    $out = wraphandle($out || select);             # get a printable output
    my ($type) = split '/', lc($self->mime_type);  # handle by MIME type

    # Multipart...
    if ($type eq 'multipart') {
	my $boundary = $self->head->multipart_boundary; 

	# Preamble:
	$out->print(join('', @{ $self->preamble || $DefPreamble }));

	# Parts:
	my $part;
	foreach $part ($self->parts) {
	    $out->print("\n--$boundary\n");
	    $part->print($out);
	}

	# Epilogue:
	$out->print("\n--$boundary--\n");
	$out->print(join('', @{ $self->epilogue || $DefEpilogue }));
    }

    # Singlepart type with parts...
    #    This makes $ent->print handle message/rfc822 bodies
    #    when parse_nested_messages('NEST') is on [idea by Marc Rouleau].
    elsif ($self->parts) {
	my $need_sep = 0;
	my $part;
	foreach $part ($self->parts) {
	    $out->print("\n\n") if $need_sep++;
	    $part->print($out);
	}	
    }

    # Singlepart type, or no parts: output body...
    else {                     
	$self->bodyhandle ? $self->print_bodyhandle($out)
	                  : whine "missing body; treated as empty";
    }
    1;
}

#------------------------------
#
# print_bodyhandle
#
# Instance method, unpublicized.  Print just the bodyhandle, *encoded*.
#
# WARNING: $self->print_bodyhandle() != $self->bodyhandle->print()!
# The former encodes, and the latter does not! 
#
sub print_bodyhandle {
    my ($self, $out) = @_;
    $out = wraphandle($out || select);             # get a printable output

    # Get the encoding, defaulting to "binary" if unsupported:
    my $encoding = ($self->head->mime_encoding || 'binary');
    my $decoder = best MIME::Decoder $encoding;
    $decoder->head($self->head);      # associate with head, if any

    # Output the body:
    my $IO = $self->open("r")     || die "open body: $!";
    $decoder->encode($IO, $out)   || return error "encoding failed";
    $IO->close;
    1;
}

#------------------------------

=item print_header [OUTSTREAM]

I<Instance method, inherited.>
Output the header to the given OUTSTREAM.  You really should supply 
the OUTSTREAM.

=cut

### Inherited.

#------------------------------

=item stringify

I<Instance method.>
Return the entity as a string, exactly as C<print> would print it: 
the body will be encoded as necessary, and will contain any subparts.  
You can also use C<as_string>.

=cut

sub stringify {
    my $str = '';
    shift->print(new IO::Scalar \$str);
    $str;    
}
sub as_string { shift->stringify };      # silent BC

#------------------------------

=item stringify_body

I<Instance method.>
Return the body as a string, exactly as C<print_body> would print it: 
the body will be encoded as necessary, and will I<not> contain any subparts.  
You can also use C<body_as_string>.

If you want the I<unencoded> body, use C<$ent->body->as_string>.

=cut

sub stringify_body {
    my $str = '';
    shift->print_body(new IO::Scalar \$str);
    $str;    
}
sub body_as_string { shift->stringify_body }

#------------------------------
#
# stringify_bodyhandle
#
# Instance method, unpublicized.  Stringify just the bodyhandle.

sub stringify_bodyhandle {
    my $str = '';
    shift->print_bodyhandle(new IO::Scalar \$str);
    $str;    
}
sub bodyhandle_as_string { shift->stringify_bodyhandle }

#------------------------------

=item stringify_header 

I<Instance method.>
Return the header as a string, exactly as C<print_header> would print it.
You can also use C<header_as_string>.

=cut

sub stringify_header {
    shift->head->stringify;
}
sub header_as_string { shift->stringify_header }



__END__
1;
  
#------------------------------

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

Note that a multipart entity does I<not> have a body.
Of course, any/all of its component parts can have bodies.

=back



=head2 The "two-body problem"

MIME::Entity and Mail::Internet see message bodies differently,
and this can cause confusion and some inconvenience.  Sadly, I can't 
change the behavior of MIME::Entity without breaking lots of code already
out there.  But let's open up the floor for a few questions...

=over 4


=item How are message bodies stored?

I<Mail::Internet:> 
	As an array of lines.

I<MIME::Entity:> 
	As a MIME::Body object, where the data may reside on disk or 
	in-core, may be large, and may be binary (not line-oriented).


=item Do messages generally have bodies?

I<Mail::Internet:> 
	Almost certainly yes.

I<MIME::Entity:>   
	Yes if this is a I<singlepart> message, and NO if it's a 
	I<multipart> message... since for multiparts the message "body" is 
	stored as the parsed collection of "parts" (each of which
        is also a MIME::Entity).


=item If an entity has a body, does it have a soul as well?

The soul does not exist in a corporeal sense, the way the body does; 
it is not a solid [Perl] object.  Rather, it is a virtual object
which is only visible when you print() an entity to a file... in other
words, the "soul" it is all that is left after the body is DESTROY'ed.  


=item What's the best way to get at the body data?

I<Mail::Internet:> 
	Use the body() method.

I<MIME::Entity:> 
	Use the bodyhandle() method, or the brand-new open()
	method.  The open() method returns a filehandle-like object to
	you, which gives you methods like getline() and read().  
	I<Use methods only> for portability; don't make any assumptions
	about what you've been handed.


=item What does the body() method return?

I<Mail::Internet:> 
	The body, as an array of lines.

I<MIME::Entity:>   
	The body, as an array of lines...
	but I<only> for a singlepart messages.  It returns I<nothing> for 
	a multipart message, since multiparts by definition do not have bodies
	of their own.  It's also somewhat inappropriate for non-textual 
        bodies, like GIFs.


=item What does print_body() print?

I<Mail::Internet:> 
	Exactly what body() would return to you.

I<MIME::Entity:> 
	The I<encoded representation> of "all the stuff following the header",
        using the Content-transfer-encoding in the MIME header. This includes
        the encoded representation of any I<parts> as well.
        Put simply, print_body() doesn't just "print the body": it
        prints a flattened representation of the I<entire entity,>
        including subparts.  This is generally what people seem to expect.


=item Assuming I have a singlepart, isn't the data 
      from body() identical to the stuff printed by print_body()?

I<Mail::Internet:> 
	Yes.

I<MIME::Entity:>   
	Not likely.  If the original message held a base64-encoded
        GIF file, the body() data will be the I<actual, decoded, binary
        GIF data>... which is I<not> the same as that base64-encoded
        stream of ASCII output by print_body().


=item Conceptually, what's the difference between what's returned
      by body() and what's printed by print_body()?

I<Mail::Internet:> 
	None.

I<MIME::Entity:> 
	Method body() refers to the I<actual body data> of the entity 
        in question.
        Method print_body() (and stringify_body()) refers to the 
        I<complete printed representation> of that entity.


=item Say I have an entity which might be either singlepart or multipart.
      How do I print out just "the stuff after the header"?

I<Mail::Internet:> 
	Use print_body().

I<MIME::Entity:> 
	Use print_body(). 


=item Why is MIME::Entity so different from Mail::Internet?

Because MIME streams are expected to have non-textual data...
possibly, quite a lot of it, such as a tar file. 

Because MIME messages can consist of multiple parts, which are most-easily 
manipulated as MIME::Entity objects themselves.

Because in the simpler world of Mail::Internet, the data of a message
and its printed representation are I<identical>... and in the MIME
world, they're not.

Because parsing multipart bodies on-the-fly, or formatting multipart 
bodies for output, is a non-trivial task.


=item This is confusing.  Can the two classes be made more compatible?

Not easily; their implementations are necessarily quite different.
Mail::Internet is a simple, efficient way of dealing with a "black box"
mail message... one whose internal data you don't care much about.  
MIME::Entity, in contrast, cares I<very much> about the message contents: 
that's its job!

Here's an example:

Suppose you wanted me to rewrite MIME::Entity so that you could properly
set any body -- even a multipart body -- by giving its lines to body().  
After all, I can just parse the lines you give me, right?

Not quite.  In order to parse that data, I I<need> to have a header
which tells me whether it's singlepart or multipart.  I I<need>
to know the encoding, too.  So MIME::Entity will enforces a sequence 
of events on how you set things up, unlike Mail::Internet -- which 
doesn't care about message contents.

=back



=head2 Design issues

=over 4

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


=head1 AUTHOR

Copyright (c) 1996, 1997 by Eryq / eryq@zeegee.com

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 4.115 $ $Date: 1998/05/01 19:52:15 $

=cut

#------------------------------
1;
