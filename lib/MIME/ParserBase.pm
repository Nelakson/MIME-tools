package MIME::ParserBase;


=head1 NAME

MIME::ParserBase - abstract class for parsing MIME streams


=head1 SYNOPSIS

This is an I<abstract> class; however, here's how one of its 
I<concrete subclasses> is used:
    
    # Create a new parser object:
    my $parser = new MIME::Parser;
    
    # Parse an input stream:
    $entity = $parser->read(\*STDIN) or die "couldn't parse MIME stream";
    
    # Congratulations: you now have a (possibly multipart) MIME entity!
    $entity->dump_skeleton;          # for debugging 

There are also some convenience methods:

    # Parse an in-core MIME message:
    $entity = $parser->parse_data($message)                 or die "parse";
    
    # Parse an MIME message in a file:
    $entity = $parser->parse_in("/some/file.msg")           or die "parse";
    
    # Parse an MIME message out of a pipeline:
    $entity = $parser->parse_in("gunzip - < file.msg.gz |") or die "parse";
      
    # Parse already-split input (as "deliver" would give it to you):
    $entity = $parser->parse_two("msg.head", "msg.body")    or die "parse";

In case a parse fails, it's nice to know who sent it to us.  So...

    # Parse an input stream:
    if (!($entity = $parser->read(\*STDIN))) {   # oops!
	$decapitated = $parser->last_head;          # get last top-level head
    }

You can also alter the behavior of the parser:    

    # Parse contained "message/rfc822" objects as nested MIME streams:
    $parser->parse_nested_messages('REPLACE');
     
    # Automatically attempt to RFC-1522-decode the MIME headers:
    $parser->decode_headers(1);

Cute stuff... 

    # Convert a Mail::Internet object to a MIME::Entity:
    @lines = (@{$mail->header}, "\n", @{$mail->body});
    $entity = $parser->parse_data(\@lines);


=head1 DESCRIPTION

Where it all begins.  

This is the class that contains all the knowledge for I<parsing> MIME
streams.  It's an abstract class, containing no methods governing
the I<output> of the parsed entities: such methods belong in the
concrete subclasses.

You can inherit from this class to create your own subclasses 
that parse MIME streams into MIME::Entity objects.  One such subclass, 
B<MIME::Parser>, is already provided in this kit.  I strongly suggest
you base your application classes off of MIME::Parser instead of this class.


=head1 PUBLIC INTERFACE

=head2 Construction, and setting options

=over 4

=cut

#------------------------------

require 5.001;         # sorry, but I need the new FileHandle:: methods!

# Pragmas:
use strict;
use vars (qw($VERSION $CAT $CRLF));

# Built-in modules:
use FileHandle ();
use Carp;
use IO::Wrap;
use IO::Scalar;
use IO::ScalarArray;

# Kit modules:
use MIME::Tools;
use MIME::ToolUtils qw(:config :msgs :utils);
use MIME::Head;
use MIME::Body;
use MIME::Entity;
use MIME::Decoder;



#------------------------------
#
# Globals
#
#------------------------------

# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4.109 $, 10;

# How to catenate:
$CAT = '/bin/cat';

# The CRLF sequence:
$CRLF = "\015\012";



#------------------------------
#
# PUBLIC INTERFACE
#
#------------------------------

#------------------------------

=item new ARGS...

I<Class method.>
Create a new parser object.  Passes any subsequent arguments
onto the C<init()> method.

Once you create a parser object, you can then set up various parameters
before doing the actual parsing.  Here's an example using one of our
concrete subclasses:

    my $parser = new MIME::Parser;
    $parser->output_dir("/tmp");
    $parser->output_prefix("msg1");
    my $entity = $parser->read(\*STDIN);

=cut

sub new {
    my $self = bless {}, shift;
    $self->init(@_);
}

#------------------------------

=item decode_headers ONOFF

I<Instance method.>
If set true, then the parser will attempt to decode the MIME headers
as per RFC-1522 the moment it sees them.  This will probably be of
most use to those of you who expect some international mail,
especially mail from individuals with 8-bit characters in their names.

If set false, no attempt at decoding will be done.

With no argument, just returns the current setting.

B<Warning:> some folks already have code which assumes that no decoding
is done, and since this is pretty new and radical stuff, I have
initially made "off" the default setting for backwards compatibility in 2.05.
However, I will possibly change this in future releases, so I<please:>
if you want a particular setting, declare it when you create your parser
object.

=cut

sub decode_headers {
    my ($self, $onoff) = @_;
    $self->{MPB_DecodeHeaders} = $onoff if (@_ > 1);
    $self->{MPB_DecodeHeaders};
}

#------------------------------

=item interface ROLE,[VALUE]

I<Instance method.>
During parsing, the parser normally creates instances of certain classes, 
like MIME::Entity.  However, you may want to create a parser subclass
that uses your own experimental head, entity, etc. classes (for example,
your "head" class may provide some additional MIME-field-oriented methods).

If so, then this is the method that your subclass should invoke during 
init.  Use it like this:

    package MyParser;
    @ISA = qw(MIME::Parser);
    ...
    sub init {
	my $self = shift;
	$self->SUPER::init(@_);        # do my parent's init
        $self->interface(ENTITY_CLASS => 'MIME::MyEntity');
	$self->interface(HEAD_CLASS   => 'MIME::MyHead');
	$self;                         # return
    }

With no VALUE, returns the VALUE currently associated with that ROLE.

=cut

sub interface {
    my ($self, $role, $value) = @_;
    $self->{MPB_Interface}{$role} = $value if (defined($value));
    $self->{MPB_Interface}{$role};
}

#------------------------------

=item last_head

I<Instance method.>
Return the top-level MIME header of the last stream we attempted to parse.
This is useful for replying to people who sent us bad MIME messages.

    # Parse an input stream:
    $entity = $parser->read(\*STDIN);
    if (!$entity) {           # oops!
	my $decapitated = $parser->last_head;    # last top-level head
    }

=cut

sub last_head {
    shift->{MPB_LastHead};
}

#------------------------------

=item parse_nested_messages OPTION

I<Instance method.>
Some MIME messages will contain a part of type C<message/rfc822>:
literally, the text of an embedded mail/news/whatever message.  
The normal behavior is to save such a message just as if it were a 
C<text/plain> document, without attempting to decode it.  However, you can 
change this: before parsing, invoke this method with the OPTION you want:

B<If OPTION is false,> the normal behavior will be used.

B<If OPTION is true,> the body of the C<message/rfc822> part
is decoded (after all, it might be encoded!) into a temporary filehandle, 
which is then rewound and parsed by this parser, creating an 
entity object.  What happens then is determined by the OPTION:

=over 4

=item NEST or 1

The contained message becomes a "part" of the C<message/rfc822> entity,
as though the C<message/rfc822> were a special kind of C<multipart> entity.
However, the C<message/rfc822> header (and the content-type) I<is retained.>

B<Warning:> since it is not legal MIME for anything but C<multipart>
to have a "part", the C<message/rfc822> message I<will appear to 
have no content> if you simply C<print()> it out.  You will have to have to 
get at the reparsed body manually, by the C<MIME::Entity::parts()> method.

IMHO, this option is probably only useful if you're I<processing> messages,
but I<not> saving or re-sending them.  In such cases, it is best to I<not>
use "parse nested" at all.

=item REPLACE

The contained message replaces the C<message/rfc822> entity, as though
the C<message/rfc822> "envelope" never existed.  

B<Warning:> notice that, with this option, all the header information 
in the C<message/rfc822> header is lost.  This might seriously bother
you if you're dealing with a top-level message, and you've just lost
the sender's address and the subject line.  C<:-/>.

=back

I<Thanks to Andreas Koenig for suggesting this method.>

=cut

sub parse_nested_messages {
    my ($self, $option) = @_;
    $self->{MPB_ParseNested} = $option if (@_ > 1);
    $self->{MPB_ParseNested};
}

#------------------------------
#
# parse_preamble INNERBOUND, IN, ENTITY
#
# Dispose of a multipart message's preamble
# Note: The boundary is mandatory!
# Note: We watch out for illegal zero-part messages.
#
# Returns what we ended on (DELIM), or undef for error.
#
sub parse_preamble {
    my ($self, $inner_bound, $in, $ent) = @_;

    # Get possible delimiters:
    my ($delim, $close) = ("--$inner_bound", "--$inner_bound--");

    # Parse preamble:
    ### debug "skip until\n\tdelim ($delim)\n\tclose ($close)";
    my @saved;
    $ent->preamble(\@saved);
    while (defined($_ = $in->getline)) {
	s/\r?\n$//o;        # chomps both \r and \r\n
	($_ eq $delim) and return 'DELIM';
	($_ eq $close) and return error "multipart message has no parts";

	# A real line, and *not* a kind of inner bound... save it:
	push @saved, "$_\n" if $self->{MPB_SaveBookends};
    }
    return error "Unexpected EOF in preamble.\n".
	         "Message looks illegal: I couldn't find the boundary...\n".
		  qq{BOUND = "$inner_bound"\n}.
		 "...as --BOUND or --BOUND-- on any line of this message!";
}

#------------------------------
#
# parse_epilogue OUTERBOUND, IN, ENTITY 
#
# Dispose of a multipart message's epilogue.
#
# The boundary in this case is optional; it is only defined if
# the multipart message we are parsing is itself part of 
# an outer multipart message.
#
# Returns what we ended on (DELIM, CLOSE, EOF), or undef for error.
#
sub parse_epilogue {
    my ($self, $outer_bound, $in, $ent) = @_;

    # If there's a boundary, get possible delimiters (for efficiency):
    my ($delim, $close) = ("--$outer_bound", "--$outer_bound--") 
	if defined($outer_bound);

    # Parse epilogue:
    ### debug "skip until\n\tdelim <",$delim||'',">\n\tclose <",$close||'',">";
    my @saved;
    $ent->epilogue(\@saved);
    while (defined($_ = $in->getline)) {
	s/\r?\n$//o;        # chomps both \r and \r\n

	# If there's a boundary, look for it:
	if (defined($outer_bound)) {    
	    ($_ eq $delim) and return 'DELIM';
	    ($_ eq $close) and return 'CLOSE';
	}

	# A real line, and *not* a kind of outer bound... save it:
	push @saved, "$_\n" if $self->{MPB_SaveBookends};
    }
    ### debug "EOF: epilogue is ", length(join '', @saved), " bytes";
    return 'EOF';       # the only way to get here!
}

#------------------------------
#
# parse_to_bound BOUND, IN, OUT 
#
# Parse up to (and including) the boundary, and dump output.
# Follows the RFC-1521 specification, that the CRLF immediately preceding 
# the boundary is part of the boundary, NOT part of the input!
#
# Returns 'DELIM' or 'CLOSE' on success (to indicate the type of boundary
# encountered, and undef on failure.
#
# NOTE: while parsing, we take care to remember the EXACT end-of-line
# sequence.  This is because we *may* be handling 'binary' encoded data, and 
# in that case we can't just massage \r\n into \n!  Don't worry... if the
# data is styled as '7bit' or '8bit', the "decoder" will massage the CRLF
# for us.  For now, we're just trying to chop up the data stream.
#
sub parse_to_bound {
    my ($self, $bound, $in, $out) = @_;    

    # Set up strings for faster checking:
    my ($delim, $close) = ("--$bound", "--$bound--");

    # Read:
    my $eol;                                 # EOL sequence of current line
    my $held_eol = '';                       # EOL sequence of previous line
    while (defined($_ = $in->getline)) {

	# Complicated chomp, to REMOVE AND REMEMBER end-of-line sequence:
	($_, $eol) = m/^(.*?)($CRLF|\n)?\Z/o;    # break into line and eol
	
	# Now, look at what we've got:
	($_ eq $delim) and return 'DELIM';   # done!
	($_ eq $close) and return 'CLOSE';   # done!
	print $out $held_eol, $_;            # print EOL from *last* line
	$held_eol = $eol;                    # hold EOL from *this* line
    }

    # Yow!
    return error "Unexpected EOF.\n".
	         "Message looks illegal: I couldn't find the boundary...\n".
	         qq{BOUND = "$bound"\n}.
		 "...as --BOUND or --BOUND-- on any line of this message!";
}

#------------------------------
#
# parse_part OUTERBOUND, IN
#
# The real back-end engine.
# See the documentation up top for the overview of the algorithm.
#
# Returns the array ($entity, $state), or the empty array to indicate failure.
# The following states are legal:
#
#        "EOF"   -- stopped on end of file
#        "DELIM" -- stopped on "--boundary"
#        "CLOSE" -- stopped on "--boundary--"
#         undef  -- stopped on error
#
sub parse_part {
    my ($self, $outer_bound, $in) = @_;
    my $state = 'OK';

    # Create a new entity:
    my $ent = $self->interface('ENTITY_CLASS')->new;

    # Parse and save the (possibly empty) header, up to and including the
    #    blank line that terminates it:
    my $head = $self->interface('HEAD_CLASS')->new;
    debug "created head $head";

    # Read the header off.
    # We localize IO inside here, so that we can support the IO:: interface
    my ($headline, @headlines);
    while (defined($headline = $in->getline)) {
	$headline =~ s/\r?\n$/\n/;       # folds \r\n into \n
	last if ($headline eq "\n");     # blank line ends head
	push @headlines, $headline;
    }
    $head->extract(\@headlines) or return error "couldn't parse head!";

    # If desired, auto-decode the header as per RFC-1522.  
    #    This shouldn't affect non-encoded headers; however, it will decode
    #    headers with international characters.  WARNING: currently, the
    #    character-set information is LOST after decoding.
    if ($self->{MPB_DecodeHeaders}) {
	debug "auto-decoding the header";
	$head->decode;
    }

    # Attach it to the entity; also, if this is the top-level head, save it:
    $ent->head($head);
    $self->{MPB_LastHead} or $self->{MPB_LastHead} = $head;

    # Handle, according to the MIME type:
    my ($type, $subtype) = split('/', $head->mime_type);
    if ($type eq 'multipart') {   # a multi-part MIME stream...
	
	# If this was a type "multipart/digest", then the RFCs say we
	# should default the parts to have type "message/rfc822".
	# Thanks to Carsten Heyl for suggesting this...
	my $retype = (($subtype eq 'digest') ? 'message/rfc822' : '');

	# Get the boundaries for the parts:
	my $inner_bound = $head->multipart_boundary;
	defined($inner_bound) or return error "no multipart boundary!";

	# Check for unparseable boundaries...
	return error "can't parse: CR or LF in multipart boundary!!" 
	    if ($inner_bound =~ /[\r\n]/);

	# Parse preamble; kill final newline (since terminated by a boundary):
	debug "parsing preamble...";
	($state = $self->parse_preamble($inner_bound,$in,$ent)) or return ();
	chomp($ent->preamble->[-1]) if @{$ent->preamble};

	# Parse parts: 
	my $partno = 0;
	my $part;
	while (1) {
	    ++$partno;
	    debug "parsing part $partno...";

	    # Parse the next part:
	    ($part, $state) = $self->parse_part($inner_bound,$in) or return ();
	    ($state eq 'EOF') and return error "unexpected EOF before close";

	    # Tweak the content-type if the parent is multipart/digest:
	    $part->head->mime_type($retype) if $retype;

	    # Add the part to the entity:
	    $ent->add_part($part);
	    last if ($state eq 'CLOSE');        # done!
	}
	
	# Parse epilogue; and kill final newline if terminated by a boundary:
	debug "parsing epilogue...";
	($state = $self->parse_epilogue($outer_bound,$in,$ent)) or return ();
	chomp($ent->epilogue->[-1]) if (@{$ent->epilogue} and $state ne 'EOF');
    }
    else {                        # a single part MIME stream...
	debug "decoding single part...";

	# Get a content-decoder to decode this part's encoding:
	my $encoding = $head->mime_encoding || 'binary';
	my $decoder = new MIME::Decoder $encoding;
	if (!$decoder) {
	    whine "Unsupported encoding '$encoding': using 'binary'... \n".
		  "The entity will have an effective MIME type of \n".
		  "application/octet-stream, as per RFC-2045.";
	    $ent->effective_type('application/octet-stream');
	    $decoder = new MIME::Decoder 'binary';
	}

	# Obtain a filehandle for reading the encoded information:
	#    We have two different approaches, based on whether or not we 
	#    have to contend with boundaries.
	my $ENCODED;             # filehandle for encoded data
	my $rawlength = undef;   # length of the encoded data, if known
	if (defined($outer_bound)) {     # BOUNDARIES...

	    # Open a temp file to dump the encoded info to, and do so:
	    $ENCODED = tmpopen() or die "couldn't open tmpfile!";
	    binmode($ENCODED);                # extract the part AS IS
	    $state = $self->parse_to_bound($outer_bound,$in,$ENCODED) 
		or return ();
	    
	    # Flush and rewind it, so we can read it:
	    $ENCODED->flush;
	    $rawlength = $ENCODED->tell;       # where were we?
	    $ENCODED->seek(0, 0);
	}
	else {                           # NO BOUNDARIES!
	    
	    # The rest of the MIME stream becomes our temp file!
	    $ENCODED = $in;
	    #                       # do NOT binmode()... might be a user FH!
	    $state = 'EOF';         # it will be, if we return okay
	}


	# NOW COMES THE FUN PART...
	# Is this an embedded message that we'll have to re-parse?
	my $IO;
	my $reparse = (("$type/$subtype" eq "message/rfc822") &&
		       $self->parse_nested_messages);
	if (!$reparse) {          # NORMAL PART...

	    # Open a new bodyhandle for outputting the data:
	    my $body = $self->new_body_for($head) || return error "no body!";
	    $body->binmode(1) unless textual_type($head->mime_type);

	    # Decode and save the body (using the decoder):
	    ($IO = $body->open("w")) or return error "body not opened: $!"; 
	    my $decoded_ok = $decoder->decode($ENCODED, $IO);
	    $IO->close;
	    $decoded_ok or return error "decoding failed";
	    
	    # Success!  Remember where we put stuff:
	    $ent->bodyhandle($body);
	}
	else {                    # EMBEDDED RFC822 MESSAGE... REPARSE!
	    debug "reparsing enclosed message!";

	    # Open a tmpfile for the bodyhandle:
	    my $DECODED = tmpopen() || die "couldn't open tmpfile!";
	    
	    # Decode and save the body (using the decoder):
	    $decoder->decode($ENCODED, $DECODED) or return error "not decoded";

	    # Rewind this stream, AND RE-PARSE IT!
	    $DECODED->seek(0,0);
	    my ($subentity) = $self->parse_part(undef, $DECODED);
	    
	    # Stuff it somewhere, based on the option:
	    if ($self->parse_nested_messages eq 'REPLACE') {
		$ent = $subentity;      # "REPLACE"
	    }
	    else {                      # "NEST" or generic 1:
		# KLUDGE... in the future, may need to coerce entity 
		# to "multipart" type, or just make a fake MP.
		$ent->bodyhandle(undef);       # we reparsed, so discard it
		$ent->add_part($subentity);
	    }
	}
    }

    # Done (we hope!):
    return ($ent, $state);
}



=back

=head2 Parsing messages

=over 4

=cut

#------------------------------

=item parse_data DATA

I<Instance method.>
Parse a MIME message that's already in-core.  You may supply the DATA 
in any of a number of ways...

=over 4

=item *

B<A scalar> which holds the message.

=item *

B<A ref to a scalar> which holds the message.  This is an efficiency hack.

=item *

B<A ref to an array of scalars.>  They are treated as a stream
which (conceptually) consists of simply concatenating the scalars.

=back

Returns a MIME::Entity, which may be a single entity, or an 
arbitrarily-nested multipart entity.  Returns undef on failure.

B<Note:> where the parsed body parts are stored (e.g., in-core vs. on-disk)
is not determined by this class, but by the subclass you use to do the 
actual parsing (e.g., MIME::Parser).  For efficiency, if you know you'll 
be parsing a small amount of data, it is probably best to tell the parser 
to store the parsed parts in core.  For example, here's a short test 
program, using MIME::Parser:

        use MIME::Parser;
        
        my $msg = <<EOF;
    Content-type: text/html
    Content-transfer-encoding: 7bit

    <H1>Hello, world!</H1>;

    EOF
        $parser = new MIME::Parser;
        $parser->output_to_core('ALL');
        $entity = $parser->parse_data($msg);
        $entity->print(\*STDOUT);

=cut

sub parse_data {
    my ($self, $data) = @_;

    # Get data as a scalar:    
    my $io;
  switch: while(1) {
      (!ref($data)) and do {
	  $io = new IO::Scalar \$data; last switch;
      };
      (ref($data) eq 'SCALAR') and do {
	  $io = new IO::Scalar $data; last switch;
      };
      (ref($data) eq 'ARRAY') and do {
	  $io = new IO::ScalarArray $data; last switch;
      };
      croak "parse_data: wrong argument ref type: ", ref($data);
  }
    
    # Parse!
    return $self->read($io);
}

#------------------------------

=item parse_in EXPR

I<Instance method.>
Convenience front-end onto C<read()>.
Simply give this method any expression that may be sent as the second
argument to open() to open a filehandle for reading. 

Returns the parsed entity, or undef on error.

=cut

sub parse_in {
    my ($self, $expr) = @_;
    my $ent;

    # Catenate the files, and open a stream on them:
    open OPEN, $expr or return error("couldn't open $expr: $!");
    $ent = $self->read(\*OPEN);
    close OPEN;
    $ent;
}

#------------------------------

=item parse_two HEADFILE, BODYFILE

I<Instance method.>
Convenience front-end onto C<parse_in()>, intended for programs 
running under mail-handlers like B<deliver>, which splits the incoming
mail message into a header file and a body file.
Simply give this method the paths to the respective files.  

B<Warning:> it is assumed that, once the files are cat'ed together,
there will be a blank line separating the head part and the body part.

B<Warning:> new implementation slurps files into line array
for portability, instead of using 'cat'.  May be an issue if 
your messages are large.

Returns the parsed entity, or undef on error.

=cut

sub parse_two {
    my ($self, $headfile, $bodyfile) = @_;
    my @lines;
    foreach ($headfile, $bodyfile) {
	open IN, "<$_" or die "open $_: $!";
	push @lines, <IN>;
	close IN;
    }
    return $self->parse_data(\@lines);
}

#------------------------------

=item read INSTREAM

I<Instance method.>
Takes a MIME-stream and splits it into its component entities,
each of which is decoded and placed in a separate file in the splitter's
output_dir().  

The INSTREAM can be given as a readable FileHandle, 
a globref'd filehandle (like C<\*STDIN>),
or as I<any> blessed object conforming to the IO:: interface.

Returns a MIME::Entity, which may be a single entity, or an 
arbitrarily-nested multipart entity.  Returns undef on failure.

=cut

sub read {
    my $self = shift;
    my $in   = wraphandle(shift);    # coerce old-style filehandles to objects

    $self->{MPB_LastHead} = undef;                 # clear last head
    my ($entity) = $self->parse_part(undef, $in);  # parse!
    $entity;
}

#------------------------------

=back

=head1 WRITING SUBCLASSES

All you have to do to write a subclass is to provide or override
the following methods:

=over 4

=cut

#------------------------------

=item init ARGS...

I<Instance method, private.>
Initiallize the new parser object, with any args passed to C<new()>.

You don't I<need> to override this in your subclass.
If you override it, however, make sure you call the inherited
method to init your parents!

    package MyParser;
    @ISA = qw(MIME::ParserBase);
    ...
    sub init {
	my $self = shift;
	$self->SUPER::init(@_);        # do my parent's init
	
	# ...my init stuff goes here...	
	
	$self;                         # return
    }

Should return the self object on success, and undef on failure.

=cut

sub init {
    my $self = shift;
    $self->{MPB_Interface} = {};
    $self->{MPB_SaveBookends} = 1;      # save preamble and epilogue
    $self->interface(ENTITY_CLASS => 'MIME::Entity');
    $self->interface(HEAD_CLASS   => 'MIME::Head');
    $self->decode_headers(0);
    $self;
}

#------------------------------

=item new_body_for HEAD

I<Abstract instance method.>
Based on the HEAD of a part we are parsing, return a new
body object (any desirable subclass of MIME::Body) for
receiving that part's data (both will be put into the
"entity" object for that part).

If you want the parser to do something other than write 
its parts out to files, you should override this method 
in a subclass.  For an example, see B<MIME::Parser>.

B<Note:> the reason that we don't use the "interface" mechanism
for this is that your choice of (1) which body class to use, and (2) how 
its C<new()> method is invoked, may be very much based on the 
information in the header.

=cut

sub new_body_for {
    my ($self, $head) = @_;
    confess "abstract method: must override this in some subclass";
}


#------------------------------
1;
__END__

=back

You are of course free to override any other methods as you see
fit, like C<new>.


=head1 NOTES

B<This is an abstract class.>
If you actually want to parse a MIME stream, use one of the children
of this class, like the backwards-compatible MIME::Parser.


=head1 WARNINGS

=over 4

=item Multipart messages are always read line-by-line 

Multipart document parts are read line-by-line, so that the
encapsulation boundaries may easily be detected.  However, bad MIME
composition agents (for example, naive CGI scripts) might return
multipart documents where the parts are, say, unencoded bitmap
files... and, consequently, where such "lines" might be 
veeeeeeeeery long indeed.

A better solution for this case would be to set up some form of 
state machine for input processing.  This will be left for future versions.


=item Multipart parts read into temp files before decoding

In my original implementation, the MIME::Decoder classes had to be aware
of encapsulation boundaries in multipart MIME documents.
While this decode-while-parsing approach obviated the need for 
temporary files, it resulted in inflexible and complex decoder
implementations.

The revised implementation uses a temporary file (a la C<tmpfile()>)
during parsing to hold the I<encoded> portion of the current MIME 
document or part.  This file is deleted automatically after the
current part is decoded and the data is written to the "body stream"
object; you'll never see it, and should never need to worry about it.

Some folks have asked for the ability to bypass this temp-file
mechanism, I suppose because they assume it would slow down their application.
I considered accomodating this wish, but the temp-file
approach solves a lot of thorny problems in parsing, and it also
protects against hidden bugs in user applications (what if you've
directed the encoded part into a scalar, and someone unexpectedly
sends you a 6 MB tar file?).  Finally, I'm just not conviced that 
the temp-file use adds significant overhead.


=item Fuzzing of CRLF and newline on input

RFC-1521 dictates that MIME streams have lines terminated by CRLF
(C<"\r\n">).  However, it is extremely likely that folks will want to 
parse MIME streams where each line ends in the local newline 
character C<"\n"> instead. 

An attempt has been made to allow the parser to handle both CRLF 
and newline-terminated input.


=item Fuzzing of CRLF and newline on output

The C<"7bit"> and C<"8bit"> decoders will decode both
a C<"\n"> and a C<"\r\n"> end-of-line sequence into a C<"\n">.

The C<"binary"> decoder (default if no encoding specified) 
still outputs stuff verbatim... so a MIME message with CRLFs 
and no explicit encoding will be output as a text file 
that, on many systems, will have an annoying ^M at the end of
each line... I<but this is as it should be>.


=item Inability to handle multipart boundaries that contain newlines

First, let's get something straight: I<this is an evil, EVIL practice,>
and is incompatible with RFC-1521... hence, it's not valid MIME.

If your mailer creates multipart boundary strings that contain
newlines I<when they appear in the message body,> give it two weeks notice 
and find another one.  If your mail robot receives MIME mail like this, 
regard it as syntactically incorrect MIME, which it is.

Why do I say that?  Well, in RFC-1521, the syntax of a boundary is 
given quite clearly:

      boundary := 0*69<bchars> bcharsnospace
        
      bchars := bcharsnospace / " "
      
      bcharsnospace :=    DIGIT / ALPHA / "'" / "(" / ")" / "+" /"_"
                   / "," / "-" / "." / "/" / ":" / "=" / "?"

All of which means that a valid boundary string I<cannot> have 
newlines in it, and any newlines in such a string in the message header
are expected to be solely the result of I<folding> the string (i.e.,
inserting to-be-removed newlines for readability and line-shortening 
I<only>).

Yet, there is at least one brain-damaged user agent out there 
that composes mail like this:

      MIME-Version: 1.0
      Content-type: multipart/mixed; boundary="----ABC-
       123----"
      Subject: Hi... I'm a dork!
      
      This is a multipart MIME message (yeah, right...)
      
      ----ABC-
       123----
      
      Hi there! 

We have I<got> to discourage practices like this (and the recent file
upload idiocy where binary files that are part of a multipart MIME
message aren't base64-encoded) if we want MIME to stay relatively 
simple, and MIME parsers to be relatively robust. 

I<Thanks to Andreas Koenig for bringing a baaaaaaaaad user agent to
my attention.>


=item Untested "binmode" calls

New, untested binmode() calls were added in module version 1.11... 
if binmode() is I<not> a NOOP on your system, please pay careful attention 
to your output, and report I<any> anomalies.  
I<It is possible that "make test" will fail on such systems,> 
since some of the tests involve checking the sizes of the output files.
That doesn't necessarily indicate a problem.

B<If anyone> wants to test out this package's handling of both binary
and textual email on a system where binmode() is not a NOOP, I would be 
most grateful.  If stuff breaks, send me the pieces (including the 
original email that broke it, and at the very least a description
of how the output was screwed up).

=back



=head1 UNDER THE HOOD

RFC-1521 gives us the following BNF grammar for the body of a
multipart MIME message:

      multipart-body  := preamble 1*encapsulation close-delimiter epilogue

      encapsulation   := delimiter body-part CRLF

      delimiter       := "--" boundary CRLF 
                                   ; taken from Content-Type field.
                                   ; There must be no space between "--" 
                                   ; and boundary.

      close-delimiter := "--" boundary "--" CRLF 
                                   ; Again, no space by "--"

      preamble        := discard-text   
                                   ; to be ignored upon receipt.

      epilogue        := discard-text   
                                   ; to be ignored upon receipt.

      discard-text    := *(*text CRLF)

      body-part       := <"message" as defined in RFC 822, with all 
                          header fields optional, and with the specified 
                          delimiter not occurring anywhere in the message 
                          body, either on a line by itself or as a substring 
                          anywhere.  Note that the semantics of a part 
                          differ from the semantics of a message, as 
                          described in the text.>

From this we glean the following algorithm for parsing a MIME stream:

    PROCEDURE parse
    INPUT
        A FILEHANDLE for the stream.
        An optional end-of-stream OUTER_BOUND (for a nested multipart message).
    
    RETURNS
        The (possibly-multipart) ENTITY that was parsed.
        A STATE indicating how we left things: "END" or "ERROR".
    
    BEGIN   
        LET OUTER_DELIM = "--OUTER_BOUND".
        LET OUTER_CLOSE = "--OUTER_BOUND--".
    
        LET ENTITY = a new MIME entity object.
        LET STATE  = "OK".
    
        Parse the (possibly empty) header, up to and including the
        blank line that terminates it.   Store it in the ENTITY.
    
        IF the MIME type is "multipart":
            LET INNER_BOUND = get multipart "boundary" from header.
            LET INNER_DELIM = "--INNER_BOUND".
            LET INNER_CLOSE = "--INNER_BOUND--".
    
            Parse preamble:
                REPEAT:
                    Read (and discard) next line
                UNTIL (line is INNER_DELIM) OR we hit EOF (error).
    
            Parse parts:
                REPEAT:
                    LET (PART, STATE) = parse(FILEHANDLE, INNER_BOUND).
                    Add PART to ENTITY.
                UNTIL (STATE != "DELIM").
    
            Parse epilogue:
                REPEAT (to parse epilogue): 
                    Read (and discard) next line
                UNTIL (line is OUTER_DELIM or OUTER_CLOSE) OR we hit EOF
                LET STATE = "EOF", "DELIM", or "CLOSE" accordingly.
     
        ELSE (if the MIME type is not "multipart"):
            Open output destination (e.g., a file)
    
            DO:
                Read, decode, and output data from FILEHANDLE
            UNTIL (line is OUTER_DELIM or OUTER_CLOSE) OR we hit EOF.
            LET STATE = "EOF", "DELIM", or "CLOSE" accordingly.
    
        ENDIF
    
        RETURN (ENTITY, STATE).
    END

For reasons discussed in MIME::Entity, we can't just discard the 
"discard text": some mailers actually put data in the preamble.



=head1 AUTHOR

Copyright (c) 1996, 1997 by Eryq / eryq@zeegee.com

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.



=head1 VERSION

$Revision: 4.109 $ $Date: 1998/02/12 03:11:27 $

=cut




