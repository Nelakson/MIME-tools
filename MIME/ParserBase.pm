package MIME::ParserBase;


=head1 NAME

MIME::ParserBase - abstract class for parsing MIME mail


=head1 SYNOPSIS

This is an I<abstract> class; however, here's how one of its 
I<concrete subclasses> is used:

    use MIME::Parser;
    
    # Create a new parser object:
    my $parser = new MIME::Parser;
    
    # Parse an input stream:
    $entity = $parser->read(\*STDIN) or die "couldn't parse MIME stream";
    
    # Congratulations: you now have a (possibly multipart) MIME entity!
    $entity->dump_skeleton;          # for debugging 

There are also some convenience methods:

    # Parse already-split input (as "deliver" would give it to you):
    $entity = $parser->parse_two("msg.head", "msg.body")
          || die "couldn't parse MIME files";

In case a parse fails, it's nice to know who sent it to us.  So...

    # Parse an input stream:
    $entity = $parser->read(\*STDIN);
    if (!$entity) {           # oops!
	my $decapitated = $parser->last_head;    # last top-level head
    }

You can also alter the behavior of the parser:    

    # Parse contained "message/rfc822" objects as nested MIME streams:
    $parser->parse_nested_messages(1);


=head1 DESCRIPTION

Where it all begins.  

This is the class that contains all the knowledge for I<parsing> MIME
streams.  It's an abstract class, containing no methods governing
the I<output> of the parsed entities: such methods belong in the
concrete subclasses.

You can inherit from this class to create your own subclasses 
that parse MIME streams into MIME::Entity objects.  One such subclass, 
B<MIME::Parser>, is already provided in this kit.


=head1 PUBLIC INTERFACE

=over 4

=cut

#------------------------------------------------------------

require 5.001;         # sorry, but I need the new FileHandle:: methods!

# Pragmas:
use strict;
use vars (qw($VERSION $CAT $CRLF));

# Built-in modules:
BEGIN {
require POSIX if ($] < 5.002);  # I dunno; supposedly, 5.001m needs this...
}
use FileHandle ();
use Carp;

# Kit modules:
use MIME::ToolUtils qw(:config :msgs);
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
( $VERSION ) = '$Revision: 1.1 $ ' =~ /\$Revision:\s+([^\s]+)/;

# How to catenate:
$CAT = '/bin/cat';

# The CRLF sequence:
$CRLF = "\015\012";



#------------------------------------------------------------
#
# UTILITIES
#
#------------------------------------------------------------

#------------------------------------------------------------
# textlike -- private utility: does HEAD indicate a textlike document?
#------------------------------------------------------------
sub textlike {
    my $head = shift;
    my ($type, $subtype) = split('/', $head->mime_type);
    return (($type eq 'text') || ($type eq 'message'));
}


#------------------------------------------------------------
#
# PUBLIC INTERFACE
#
#------------------------------------------------------------

#------------------------------------------------------------
# new
#------------------------------------------------------------

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
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->init(@_);
}

#------------------------------------------------------------
# init
#------------------------------------------------------------

=item init ARGS...

I<Instance method.>
Initiallize the new parser object, with any args passed to C<new()>.

If you override this in a subclass, make sure you call the inherited
method to init your parents!

    package MyParser;
    @ISA = qw(MIME::Parser);
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
    $self->interface(ENTITY_CLASS => 'MIME::Entity');
    $self->interface(HEAD_CLASS   => 'MIME::Head');
    $self;
}

#------------------------------------------------------------
# interface
#------------------------------------------------------------

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

#------------------------------------------------------------
# last_head
#------------------------------------------------------------

=item last_head

Return the top-level MIME header of the last stream we attempted to parse.
This is useful for replying to people who sent us bad MIME messages.

    # Parse an input stream:
    $entity = $parser->read(\*STDIN);
    if (!$entity) {           # oops!
	my $decapitated = $parser->last_head;    # last top-level head
    }

=cut

sub last_head {
    my $self = shift;
    $self->{MPB_LastHead};
}

#------------------------------------------------------------
# parse_nested_messages
#------------------------------------------------------------

=item parse_nested_messages OPTION

Some MIME messages will contain a part of type C<message/rfc822>:
literally, the text of an embedded mail message.  The normal behavior 
is to save such a message just as if it were a C<text/plain> 
document.  However, you can change this: before parsing, invoke 
this method with the OPTION you want:

B<If OPTION is false,> the normal behavior will be used.

B<If OPTION is true,> the body of the C<message/rfc822> part
is decoded (after all, it might be encoded!) into a temporary file, 
which is then rewound and parsed by this parser, creating an 
entity object.  What happens then is determined by the OPTION:

=over

=item NEST or 1

The contained message becomes a "part" of the C<message/rfc822> entity,
as though the C<message/rfc822> were a special kind of C<multipart> entity.
This is the default behavior if the generic true value of "1" is given.

=item REPLACE

The contained message replaces the C<message/rfc822> entity, as though
the C<message/rfc822> "envelope" never existed.  Notice that, with 
this option, all the header information in the C<message/rfc822>
header is lost, so this option is I<not> recommended.

=back

I<Thanks to Andreas Koenig for suggesting this method.>

=cut

sub parse_nested_messages {
    my ($self, $option) = @_;
    $self->{MPB_RFC822} = $option if (@_ > 1);
    $self->{MPB_RFC822};
}

#------------------------------------------------------------
# parse_preamble -- dispose of a multipart message's preamble
#------------------------------------------------------------
# NOTES
#    The boundary is mandatory!
#
#    We watch out for illegal zero-part messages.
#
# RETURNS
#    What we ended on (DELIM), or undef for error.
#
sub parse_preamble {
    my ($self, $inner_bound, $in) = @_;

    # Get possible delimiters:
    my ($delim, $close) = ("--$inner_bound", "--$inner_bound--");

    # Parse preamble:
    debug "skip until\n\tdelim <$delim>\n\tclose <$close>";
    while (<$in>) {
	s/\r?\n$//o;        # chomps both \r and \r\n
	
	debug "preamble: <$_>";
	($_ eq $delim) and return 'DELIM';
	($_ eq $close) and return error "multipart message has no parts";
    }
    error "unexpected eof in preamble" if eof($in);
}

#------------------------------------------------------------
# parse_epilogue -- dispose of a multipart message's epilogue
#------------------------------------------------------------
# NOTES
#    The boundary in this case is optional; it is only defined if
#    the multipart message we are parsing is itself part of 
#    an outer multipart message.
#
# RETURNS
#    What we ended on (DELIM, CLOSE, EOF), or undef for error.
#
sub parse_epilogue {
    my ($self, $outer_bound, $in) = @_;

    # If there's a boundary, get possible delimiters (for efficiency):
    my ($delim, $close) = ("--$outer_bound", "--$outer_bound--") 
	if defined($outer_bound);

    # Parse epilogue:
    debug "skip until\n\tdelim <", $delim||'', ">\n\tclose <",$close||'', ">";
    while (<$in>) {
	s/\r?\n$//o;        # chomps both \r and \r\n

	debug "epilogue: <$_>";
	if (defined($outer_bound)) {    # if there's a boundary, look for it:
	    ($_ eq $delim) and return 'DELIM';
	    ($_ eq $close) and return 'CLOSE';
	}
    }
    return 'EOF';       # the only way to get here!
}

#------------------------------------------------------------
# parse_to_bound -- parse up to (and including) the boundary, and dump output
#------------------------------------------------------------
# NOTES
#    Follows the RFC-1521 specification, that the CRLF
#    immediately preceding the boundary is part of the boundary,
#    NOT part of the input!
#
# RETURNS
#    'DELIM' or 'CLOSE' on success (to indicate the type of boundary
#    encountered, and undef on failure.
#
sub parse_to_bound {
    my ($self, $bound, $in, $out) = @_;    
    my $eol;                 # EOL sequence of current line
    my $held_eol = '';       # EOL sequence of previous line

    # Set up strings for faster checking:
    my $delim = "--$bound";
    my $close = "--$bound--";

    # Read:
    while (<$in>) {

	# Complicated chomp, to REMOVE AND REMEMBER end-of-line sequence:
	($eol) = ($_ =~ m/($CRLF|\n)$/o);
	if ($eol eq $CRLF) { chop; chop } else { chop };
	
	# Now, look at what we've got:
	($_ eq $delim) and return 'DELIM';   # done!
	($_ eq $close) and return 'CLOSE';   # done!
	print $out $held_eol, $_;            # print EOL from *last* line
	$held_eol = $eol;                    # hold EOL from *this* line
    }

    # Yow!
    return error "unexpected EOF while waiting for $bound !";
}

#------------------------------------------------------------
# parse_part -- the real back-end engine
#------------------------------------------------------------
# DESCRIPTION
#    See the documentation up top for the overview of the algorithm.
#
# RETURNS
#    The array ($entity, $state), or the empty array to indicate failure.
#    The following states are legal:
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
    my $entity = $self->interface('ENTITY_CLASS')->new;

    # Parse and save the (possibly empty) header, up to and including the
    #    blank line that terminates it:
    my $head = $self->interface('HEAD_CLASS')->new;
    debug "created head $head";
    $head->read($in) or return error "couldn't parse head!";

    # Attach it to the entity; also, if this is the top-level head, save it:
    $entity->head($head);
    $self->{MPB_LastHead} or $self->{MPB_LastHead} = $head;

    # Handle, according to the MIME type:
    my ($type, $subtype) = split('/', $head->mime_type);
    if ($type eq 'multipart') {   # a multi-part MIME stream...
	
	# Get the boundaries for the parts:
	my $inner_bound = $head->multipart_boundary;
	defined($inner_bound) or return error "no multipart boundary!";
	
	# Parse preamble:
	debug "parsing preamble...";
	($state = $self->parse_preamble($inner_bound, $in))
	    or return ();
		    
	# Parse parts:	
	my $partno = 0;
	my $part;
	while (1) {
	    ++$partno;
	    debug "parsing part $partno...";

	    # Parse the next part:
	    ($part, $state) = $self->parse_part($inner_bound, $in)
		or return ();
	    ($state eq 'EOF') and return error "unexpected EOF before close";

	    # Add it to the entity:
	    $entity->add_part($part);
	    last if ($state eq 'CLOSE');        # done!
	}
	
	# Parse epilogue:
	debug "parsing epilogue...";
	($state = $self->parse_epilogue($outer_bound, $in)) 
	    or return ();
    }
    else {                        # a single part MIME stream...
	debug "decoding single part...";

	# Get a content-decoder to decode this part's encoding:
	my $encoding = $head->mime_encoding || 'binary';
	my $decoder = new MIME::Decoder $encoding;
	if (!$decoder) {
	    warn "unrecognized encoding '$encoding': using 'binary'";
	    $decoder = new MIME::Decoder 'binary';
	}

	# Obtain a filehandle for reading the encoded information:
	#    We have two different approaches, based on whether or not we 
	#    have to contend with boundaries.
	my $encoded;             # filehandle for encoded data
	my $rawlength = undef;   # length of the encoded data, if known
	if (defined($outer_bound)) {     # BOUNDARIES...

	    # Open a temp file to dump the encoded info to, and do so:
	    $encoded = FileHandle->new_tmpfile;
	    binmode($encoded);                # extract the part AS IS
	    $state = $self->parse_to_bound($outer_bound, $in, $encoded)
		or return ();
	    
	    # Flush and rewind it, so we can read it:
	    $encoded->flush;
	    $rawlength = $encoded->tell;       # where were we?
	    $encoded->seek(0, 0);
	}
	else {                           # NO BOUNDARIES!
	    
	    # The rest of the MIME stream becomes our temp file!
	    $encoded = $in;
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
	    my $body = $self->new_body_for($head);
	    $body->binmode unless textlike($head);    # no binmode if text!
	    $IO = $body->open("w") or return error "body not opened: $!"; 
	    
	    # Decode and save the body (using the decoder):
	    my $decoded_ok = $decoder->decode($encoded, $IO);
	    $IO->close;
	    $decoded_ok or return error "decoding failed";
	    
	    # Success!  Remember where we put stuff:
	    $entity->bodyhandle($body);
	}
	else {                    # EMBEDDED MESSAGE...
	    debug "reparsing enclosed message!";

	    # Open a tmpfile for the bodyhandle:
	    my $tmpbody = FileHandle->new_tmpfile;
	    
	    # Decode and save the body (using the decoder):
	    my $decoded_ok = $decoder->decode($encoded, $tmpbody);
	    $decoded_ok or return error "decoding failed";

	    # Rewind this stream, AND RE-PARSE IT!
	    $tmpbody->seek(0,0);
	    my ($subentity) = $self->parse_part(undef, $tmpbody);
	    
	    # Stuff it somewhere, based on the option:
	    if ($self->parse_nested_messages eq 'REPLACE') {
		$entity = $subentity;
	    }
	    else {          # "NEST" or generic 1:
		$entity->add_part($subentity);
	    }
	}
    }
    
    # Done (we hope!):
    return ($entity, $state);
}

#------------------------------------------------------------
# parse_two
#------------------------------------------------------------

=item parse_two HEADFILE BODYFILE

Convenience front-end onto C<read()>, intended for programs 
running under mail-handlers like B<deliver>, which splits the incoming
mail message into a header file and a body file.

Simply give this method the paths to the respective files.  
I<These must be pathnames:> Perl "open-able" expressions won't
work, since the pathnames are shell-quoted for safety.

B<WARNING:> it is assumed that, once the files are cat'ed together,
there will be a blank line separating the head part and the body part.

=cut

sub parse_two {
    my ($self, $headfile, $bodyfile) = @_;
    my @result;

    # Shell-quote the filenames:
    my $safe_headfile = shell_quote($headfile);
    my $safe_bodyfile = shell_quote($bodyfile);

    # Catenate the files, and open a stream on them:
    open(CAT, qq{$CAT $safe_headfile $safe_bodyfile |}) or
	return error("couldn't open $CAT pipe: $!");
    @result = $self->read(\*CAT);
    close (CAT);
    @result;
}

#------------------------------------------------------------
# read 
#------------------------------------------------------------

=item read FILEHANDLE

Takes a MIME-stream and splits it into its component entities,
each of which is decoded and placed in a separate file in the splitter's
output_dir().  

The stream should be given as a FileHandle, or at least a glob ref 
to a readable FILEHANDLE; e.g., C<\*STDIN>.

Returns a MIME::Entity, which may be a single entity, or an 
arbitrarily-nested multipart entity.  Returns undef on failure.

=cut

sub read {
    my ($self, $in) = @_;

    # Clear last head:
    $self->{MPB_LastHead} = undef;
    
    # Parse:
    my ($entity) = $self->parse_part(undef, $in);
    $entity;
}

#------------------------------------------------------------
# shell_quote -- private utility: make string safe for shell
#------------------------------------------------------------
sub shell_quote {
    my $str = shift;
    $str =~ s/\$/\\\$/g;
    $str =~ s/\`/\\`/g;
    $str =~ s/\"/\\"/g;
    return "\"$str\"";        # wrap in double-quotes
}




#------------------------------------------------------------

=back

=head1 WRITING SUBCLASSES

All you have to do to write a subclass is to provide the following methods:

=over

=cut

#------------------------------------------------------------



#------------------------------------------------------------
# new_body_for
#------------------------------------------------------------

=item new_body_for HEAD

I<Abstract method.>
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







#------------------------------------------------------------

=back

You are of course free to override any other methods as you see
fit, like C<new>.



=head1 NOTES

B<This is an abstract class.>
If you actually want to parse a MIME stream, use one of the children
of this class, like the backwards-compatible MIME::Parser.

=head2 Under the hood

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


=head2 Questionable practices

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

=back


=head1 WARNINGS

=over

=item binmode

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

$Revision: 1.1 $ $Date: 1996/10/18 06:52:28 $

=cut

#------------------------------------------------------------
1;

