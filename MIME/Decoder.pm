package MIME::Decoder;


=head1 NAME

MIME::Decoder - an object for decoding the body part of a MIME stream


=head1 SYNOPSIS

B<Decoding a data stream.>
Here's a simple filter program to read quoted-printable data from STDIN
(until EOF) and write the decoded data to STDOUT:

    use MIME::Decoder;
    
    $decoder = new MIME::Decoder 'quoted-printable' or die "unsupported";
    $decoder->decode(\*STDIN, \*STDOUT);

B<Encoding a data stream.>
Here's a simple filter program to read binary data from STDIN
(until EOF) and write base64-encoded data to STDOUT:

    use MIME::Decoder;
    
    $decoder = new MIME::Decoder 'base64' or die "unsupported";
    $decoder->encode(\*STDIN, \*STDOUT);

You can B<write and install your own decoders> so that
MIME::Decoder will know about them:

    use MyBase64Decoder;
    
    install MyBase64Decoder 'base64';

You can also B<test if an encoding is supported:> 

    if (MIME::Decoder->supported('x-uuencode')) {
        # we can uuencode!
    }


=head1 DESCRIPTION

This abstract class, and its private concrete subclasses (see below)
provide an OO front end to the actions of...

=over 4

=item *

Decoding a MIME-encoded stream

=item *

Encoding a raw data stream into a MIME-encoded stream.

=back

The constructor for MIME::Decoder takes the name of an encoding
(C<base64>, C<7bit>, etc.), and returns an instance of a I<subclass>
of MIME::Decoder whose C<decode()> method will perform the appropriate
decoding action, and whose C<encode()> method will perform the appropriate
encoding action.



=cut


# Pragmas:
use strict;
use vars qw($VERSION %DecoderFor);

# System modules:
use FileHandle;
use Carp;

# Kit modules:
use MIME::ToolUtils qw(:config :msgs);
use MIME::IO;				

#------------------------------------------------------------
#
# Globals
# 
#------------------------------------------------------------

# The stream decoders:
%DecoderFor = (
    '7bit'      => 'MIME::Decoder::Xbit',
    '8bit'      => 'MIME::Decoder::Xbit',
    'base64'    => 'MIME::Decoder::Base64',
    'binary'    => 'MIME::Decoder::Binary',
    'none'      => 'MIME::Decoder::Binary',
    'quoted-printable' => 'MIME::Decoder::QuotedPrint',
);


# The package version, both in 1.23 style *and* usable by MakeMaker:
( $VERSION ) = '$Revision: 2.9 $ ' =~ /\$Revision:\s+([^\s]+)/;




#------------------------------

=head1 PUBLIC INTERFACE

=head2 Standard interface

If all you are doing is I<using> this class, here's all you'll need...

=over 4

=cut

#------------------------------

#------------------------------------------------------------
# new 
#------------------------------------------------------------

=item new ENCODING

I<Class method>.
Create and return a new decoder object which can handle the 
given ENCODING.

    my $decoder = new MIME::Decoder "7bit";

Returns the undefined value if no known decoders are appropriate.

=cut

sub new {
    my ($class, @args) = @_;
    my ($encoding) = @args;
    my $concrete;

    # Coerce the type to be legit:
    $encoding = lc($encoding || '');

    # Create the new object (if we can):
    ($concrete = $DecoderFor{$encoding}) or return undef;
    my $self = {
	MD_Encoding => lc($encoding)
	};
    bless $self, $concrete;
    $self->init(@args);
}

#------------------------------------------------------------
# decode 
#------------------------------------------------------------

=item decode INSTREAM,OUTSTREAM

Decode the document waiting in the input handle INSTREAM,
writing the decoded information to the output handle OUTSTREAM.

Read the section in this document on I/O handles for more information
about the arguments.  Note that you can still supply old-style
unblessed filehandles for INSTREAM and OUTSTREAM.

=cut

sub decode {
    my ($self, $in, $out) = @_;
    
    # Set up the default input record separator to be CRLF:
    # $in->input_record_separator("\012\015");

    # Coerce old-style filehandles to legit objects:
    $in  = wrap MIME::IO::Handle $in;
    $out = wrap MIME::IO::Handle $out;
    
    # Do it!
    $self->decode_it($in, $out);   # invoke back-end method to do the work
}

#------------------------------------------------------------
# encode 
#------------------------------------------------------------

=item encode INSTREAM,OUTSTREAM

Encode the document waiting in the input filehandle INSTREAM,
writing the encoded information to the output stream OUTSTREAM.

Read the section in this document on I/O handles for more information
about the arguments.  Note that you can still supply old-style
unblessed filehandles for INSTREAM and OUTSTREAM.

=cut

sub encode {
    my ($self, $in, $out) = @_;
    
    # Coerce old-style filehandles to legit objects:
    $in  = wrap MIME::IO::Handle $in;
    $out = wrap MIME::IO::Handle $out;
    
    # Do it!
    $self->encode_it($in, $out);   # invoke back-end method to do the work
}

#------------------------------------------------------------
# encoding
#------------------------------------------------------------

=item encoding

Return the encoding that this object was created to handle,
coerced to all lowercase (e.g., C<"base64">).

=cut

sub encoding {
    $_[0]->{MD_Encoding};
}

#------------------------------------------------------------
# supported
#------------------------------------------------------------

=item supported [ENCODING]

I<Class method>.
With one arg (an ENCODING name), returns truth if that encoding
is currently handled, and falsity otherwise.  The ENCODING will
be automatically coerced to lowercase:

    if (MIME::Decoder->supported('7BIT')) {
        # yes, we can handle it...
    }
    else {
        # drop back six and punt...
    } 

With no args, returns all the available decoders as a hash reference... 
where the key is the encoding name (all lowercase, like '7bit'),
and the associated value is true (it happens to be the name of the class 
that handles the decoding, but you probably shouldn't rely on that).
Hence:

    my $supported = MIME::Decoder->supported;
    if ($supported->{7bit}) {
        # yes, we can handle it...
    }
    elsif ($supported->{8bit}) {
        # yes, we can handle it...
    }

You may safely modify this hash; it will I<not> change the way the 
module performs its lookups.  Only C<install> can do that.

I<Thanks to Achim Bohnet for suggesting this method.>

=cut

sub supported {
    my ($class, $decoder) = @_;
    
    if (defined($decoder)) {     # is this decoder available?
	return $DecoderFor{lc($decoder)};
    }
    else {                       # return 'em all!
	my %safecopy = %DecoderFor;
	return \%safecopy;
    }
}

#------------------------------

=back

=head2 Subclass interface

If you are writing (or installing) a new decoder subclass, there
are some other methods you'll need to know about:

=over 4

=cut

#------------------------------

#------------------------------------------------------------
# decode_it -- private: abstract internal decode method
#------------------------------------------------------------

=item decode_it INSTREAM,OUTSTREAM

I<Abstract instance method>.  
The back-end of the B<decode> method.  It takes an input handle
opened for reading (INSTREAM), and an output handle opened for
writing (OUTSTREAM).

If you are writing your own decoder subclass, you must override this
method in your class.  Your method should read from the input
handle via C<getline()> or C<read()>, decode this input, and print the
decoded data to the output handle via C<print()>.  You may do this
however you see fit, so long as the end result is the same.

Note that unblessed references and globrefs are automatically turned
into I/O handles for you by C<decode()>, so you don't need to worry
about it.

Your method must return either C<undef> (to indicate failure),
or C<1> (to indicate success).

=cut

sub decode_it {
    my $self = shift;
    die "attempted to use abstract 'decode_it' method!";
}

#------------------------------------------------------------
# encode_it -- private: abstract internal encode method
#------------------------------------------------------------

=item encode_it INSTREAM,OUTSTREAM

I<Abstract instance method>.  
The back-end of the B<encode> method.  It takes an input handle
opened for reading (INSTREAM), and an output handle opened for
writing (OUTSTREAM).

If you are writing your own decoder subclass, you must override this
method in your class.  Your method should read from the input
handle via C<getline()> or C<read()>, encode this input, and print the
encoded data to the output handle via C<print()>.  You may do this
however you see fit, so long as the end result is the same.

Note that unblessed references and globrefs are automatically turned
into I/O handles for you by C<encode()>, so you don't need to worry
about it.

Your method must return either C<undef> (to indicate failure),
or C<1> (to indicate success).

=cut

sub encode_it {
    my $self = shift;
    die "attempted to use abstract 'encode_it' method!";
}

#------------------------------------------------------------
# init
#------------------------------------------------------------

=item init ARGS...

I<Instance method>.  Do any necessary initialization of the new instance,
taking whatever arguments were given to C<new()>.
Should return the self object on success, undef on failure.

=cut

sub init {
    $_[0];
}

#------------------------------------------------------------
# install 
#------------------------------------------------------------

=item install ENCODING

I<Class method>.  Install this class so that ENCODING is handled by it.
You should not override this method.

=cut

sub install {
    my ($class, $encoding) = @_;
    $DecoderFor{lc($encoding)} = $class;
}



#------------------------------------------------------------

=back

=head1 BUILT-IN DECODER SUBCLASSES

You don't need to C<"use"> any other Perl modules; the
following are included as part of MIME::Decoder.

=cut


# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

=head2 MIME::Decoder::Base64

The built-in decoder for the C<"base64"> encoding.

The name was chosen to jibe with the pre-existing MIME::Base64
utility package, which this class actually uses to translate each line.

When B<decoding>, the input is read one line at a time.
The input accumulates in an internal buffer, which is decoded in
multiple-of-4-sized chunks (plus a possible "leftover" input chunk,
of course).

When B<encoding>, the input is read 45 bytes at a time: this ensures
that the output lines are not too long.   We chose 45 since it is
a multiple of 3 and produces lines under 76 characters, as RFC-1521 
specifies.

I<Thanks to Phil Abercrombie for locating one idiotic bug in this
module, which led me to discover another.>

=cut

package MIME::Decoder::Base64;

use vars qw(@ISA);
use MIME::Base64;

@ISA = qw(MIME::Decoder);

# How many bytes to encode at a time (must be a multiple of 3, and
# less than (76 * 0.75)!
my $EncodeChunkLength = 45;


#------------------------------------------------------------
# decode_it
#------------------------------------------------------------
sub decode_it {
    my ($self, $in, $out) = @_;
    my $buffer = '';
    my ($len_4xN, $encoded);

    # Get lines until done:
    while (defined($_ = $in->getline)) {
	s{[^A-Za-z0-9+/]}{}g;         # get rid of non-base64 chars

	# Concat any new input onto any leftover from the last round:
	$buffer .= $_;
	
    	# Extract substring with highest multiple of 4 bytes:
	#   0 means not enough to work with... get more data!
	($len_4xN = ((length($buffer) >> 2) << 2)) or next;
	$encoded = substr($buffer, 0, $len_4xN);
	$buffer  = substr($buffer, $len_4xN);

	# NOW, we can decode it!
	$out->print(decode_base64($encoded));
    }
    
    # No more input remains.  Dispose of anything left in buffer:
    if (length($buffer)) {

	# Pad to 4-byte multiple:
	$buffer .= "===";            # need no more than 3 pad chars
	$encoded = substr($buffer, 0, ((length($buffer) >> 2) << 2));

	# Decode it!
	$out->print(decode_base64($encoded));
    }
    1;
}

#------------------------------------------------------------
# encode_it
#------------------------------------------------------------
sub encode_it {
    my ($self, $in, $out) = @_;
    my $encoded;

    my $nread;
    my $buf = '';
    while ($nread = $in->read($buf, $EncodeChunkLength)) {
	$encoded = encode_base64($buf);
	$encoded .= "\n" unless ($encoded =~ /\n\Z/);     # ensure newline!
	$out->print($encoded);
    }
    1;
}


# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

=head2 MIME::Decoder::Binary

The built-in decoder for a C<"binary"> encoding (in other words,
no encoding).  

The C<"binary"> decoder is a special case, since it's ill-advised
to read the input line-by-line: after all, an uncompressed image file might
conceivably have loooooooooong stretches of bytes without a C<"\n"> among
them, and we don't want to risk blowing out our core.  So, we 
read-and-write fixed-size chunks.

Both the B<encoder> and B<decoder> do a simple pass-through of the data
from input to output.

=cut

package MIME::Decoder::Binary;

use vars qw(@ISA);

@ISA = qw(MIME::Decoder);

#------------------------------------------------------------
# decode_it
#------------------------------------------------------------
sub decode_it {
    my ($self, $in, $out) = @_;

    my ($buf, $nread) = ('', 0);
    while ($nread = $in->read($buf, 4096)) {
	$out->print($buf);
    }
    defined($nread) or return undef;      # check for error
    1;
}
#------------------------------------------------------------
# encode_it
#------------------------------------------------------------
sub encode_it {
    my ($self, $in, $out) = @_;

    my ($buf, $nread) = ('', 0);
    while ($nread = $in->read($buf, 4096)) {
	$out->print($buf);
    }
    defined($nread) or return undef;      # check for error
    1;
}




# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 

=head2 MIME::Decoder::QuotedPrint

The built-in decoder the for C<"quoted-printable"> encoding.

The name was chosen to jibe with the pre-existing MIME::QuotedPrint
utility package, which this class actually uses to translate each line.

The B<decoder> does a line-by-line translation from input to output.

The B<encoder> does a line-by-line translation, breaking lines
so that they fall under the standard 76-character limit for this
encoding.  

B<Note:> just like MIME::QuotedPrint, we currently use the 
native C<"\n"> for line breaks, and not C<CRLF>.  This may
need to change in future versions.

=cut

package MIME::Decoder::QuotedPrint;

use vars qw(@ISA);
use MIME::QuotedPrint;

@ISA = qw(MIME::Decoder);

#------------------------------------------------------------
# encode_qp_really
#------------------------------------------------------------
# Sadly, the one in MIME::QuotedPrint is slightly broken.  :-(
# So we roll our own.  This is actually identical to the one in 
# MIME::QuotedPrint, except that it attempts to break lines slightly 
# earlier, allowing lines which happen to end in an escaped character 
# to be broken properly.
#
sub encode_qp_really {
    my $res = shift;
    $res =~ s/([^ \t\n!-<>-~])/sprintf("=%02X", ord($1))/eg;  # rule #2,#3
    $res =~ s/([ \t]+)$/
      join('', map { sprintf("=%02X", ord($_)) }
	           split('', $1)
      )/egm;                        # rule #3 (encode whitespace at eol)

    # rule #5 (lines must be shorter than 76 chars, but we are not allowed
    # to break =XX escapes.  This makes things complicated.)
    ### [Eryq's note]: the bug fix is the {70} below, which was {74} in the
    ### original code.
    my $brokenlines = "";
    $brokenlines .= "$1=\n" while $res =~ s/^(.{70}([^=]{2})?)//;
    # unnessesary to make a break at the last char
    $brokenlines =~ s/=\n$// unless length $res; 

    "$brokenlines$res";
}

#------------------------------------------------------------
# decode_it
#------------------------------------------------------------
sub decode_it {
    my ($self, $in, $out) = @_;

    while (defined($_ = $in->getline)) {
	$out->print(decode_qp($_));
    }
    1;
}
#------------------------------------------------------------
# encode_it
#------------------------------------------------------------
sub encode_it {
    my ($self, $in, $out) = @_;

    while (defined($_ = $in->getline)) {	
	$out->print(encode_qp_really($_));
    }
    1;
}




# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

=head2 MIME::Decoder::Xbit

The built-in decoder for both C<"7bit"> and C<"8bit"> encodings,
which guarantee short lines (a maximum of 1000 characters per line) 
of US-ASCII data compatible with RFC-821.

The B<decoder> does a line-by-line pass-through from input to output,
leaving the data unchanged I<except> that an end-of-line sequence of
CRLF is converted to a newline "\n".

The B<encoder> does a line-by-line pass-through from input to output,
splitting long lines if necessary.  If created as a 7-bit encoder, any
8-bit characters are mapped to zero or more 7-bit characters: note
that this is a potentially I<lossy> encoding if you hand it anything
but 7-bit input: therefore, don't use it on binary files (GIFs) and
the like; use it only when it "doesn't matter" if extra newlines are
inserted and 8-bit characters are squished.

There are several possible ways to use this class to encode arbitrary 
8-bit text as 7-bit text:

=over 4

=item Don't use this class.

Really.  Use a more-appropriate encoding, like quoted-printable.

=item APPROX

Approximate the appearance of the Latin-1 character via Internet
conventions; e.g., C<"\c,">, C<"\n~">, etc.  This is the default
behavior of this class.

=item CLEARBIT8

Just clear the 8th bit.  Yuck.  Sort of a sledgehammer approach.
Not recommended at all.

=item ENTITY

Output as an HTML-style entity; e.g., C<"&>C<#189;">.
This sounds like a good idea, until you see some French text which
is actually encoded this way... yuck.  You're better off with
quoted-printable.

=item STRIP

Strip out any 8-bit characters.  Nice if you're I<really> sure that any
such characters in your input are mistakes to be deleted, but it'll
transform non-English documents into an abbreviated mess.

=back

=cut

package MIME::Decoder::Xbit;

use vars qw(@ISA);

@ISA = qw(MIME::Decoder);


#------------------------------------------------------------
# encode_8bit 
#------------------------------------------------------------
# We just read a line of the file that we're trying to 7-bit encode.  
# Clean out any 8-bit characters.

sub encode_8bit {
    my ($self, $line) = @_;
    my $opt = ($self->{MD_Xbit_Encode8} || 'APPROX');
    if ($opt eq    'CLEARBIT8') {                # just clear 8th bit
	$line =~ tr[\200-\377][\000-\177];
    }
    elsif ($opt eq 'STRIP') {                    # just remove offending chars
	$line =~ s/[\200-\377]//g;
    }
    elsif ($opt eq 'ENTITY') {                   # output HTML-style entity
	$line =~ s/[\200-\377]/'&#'.ord($&).';'/ge;
    }
    else {        # APPROX                       # output ASCII approximation
	require MIME::Latin1;
	$line = MIME::Latin1::latin1_to_ascii($line);
    }
    $line;
}

#------------------------------------------------------------
# decode_it
#------------------------------------------------------------
sub decode_it {
    my ($self, $in, $out) = @_;
    
    while (defined($_ = $in->getline)) {
	s/\015\012$/\n/;
	$out->print($_);
    }
    1;
}

#------------------------------------------------------------
# encode_it
#------------------------------------------------------------
sub encode_it {
    my ($self, $in, $out) = @_;
    
    my ($line, $lines);
    my $seven_bit = ($self->encoding eq '7bit');
    while (defined($line = $in->getline)) {

	# First, make it 8-bit clean:
	$line = $self->encode_8bit($line) if $seven_bit;  

	# Split long lines:
	$lines = '';
	while (length($line) > 990) {
	    $lines .= substr($line, 0, 990);
	    $line = substr($line, 990);
	    $lines .= "\n" if (defined($line) && (length($line) > 0));
	}
	$lines .= $line;

	# Output!
	$out->print($lines);
    }
    1;
}

#------------------------------------------------------------
# encode_8bit_by
#------------------------------------------------------------
sub encode_8bit_by {
    my ($self, $opt) = @_;
    $self->{MD_Xbit_Encode8} = $opt if (@_ > 1);
    $opt;
}




# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

=head1 NOTES

=head2 Input/Output handles

As of MIME-tools 2.0, this class has to play nice with the new MIME::Body
class... which means that input and output routines cannot just assume that 
they are dealing with filehandles.  

Therefore, all that MIME::Decoder and its subclasses require (and, thus, 
all that they can assume) is that INSTREAMs and OUTSTREAMs are objects 
which respond to the messages defined in B<MIME::IO> (basically, a 
subset of those defined by IO::Handle).

For backwards compatibilty, if you supply a scalar filehandle name
(like C<"STDOUT">) or an unblessed glob reference (like C<\*STDOUT>)
where an INSTREAM or OUTSTREAM is expected, this package will 
automatically wrap it in an object that fits the I/O handle criteria.

I<Thanks to Achim Bohnet for suggesting this more-generic I/O model.>


=head2 Writing a decoder

If you're experimenting with your own encodings, you'll probably want
to write a decoder.  Here are the basics:

=over 4

=item 1.

Create a module, like "MyDecoder::", for your decoder.
Declare it to be a subclass of MIME::Decoder.

=item 2.

Create the following instance methods in your class, as described above:

    decode_it
    encode_it
    init

=item 3.

In your application program, activate your decoder for one or
more encodings like this:

    require MyDecoder;

    install MyDecoder "7bit";        # use MyDecoder to decode "7bit"    
    install MyDecoder "x-foo";       # also, use MyDecoder to decode "x-foo"

=back

To illustrate, here's a custom decoder class for the C<quoted-printable> 
encoding:

    package MyQPDecoder;

    @ISA = qw(MIME::Decoder);    
    use MIME::Decoder;
    use MIME::QuotedPrint;
    
    # decode_it - the private decoding method
    sub decode_it {
        my ($self, $in, $out) = @_;
        
        while (defined($_ = $in->getline())) {
            my $decoded = decode_qp($_);
	    $out->print($decoded);
        }
        1;
    }
    
    # encode_it - the private encoding method
    sub encode_it {
        my ($self, $in, $out) = @_;
        
        my ($buf, $nread) = ('', 0); 
        while ($in->read($buf, 60)) {
            my $encoded = encode_qp($buf);
	    $out->print($encoded);
        }
        1;
    }

That's it.

The task was pretty simple because the C<"quoted-printable"> 
encoding can easily be converted line-by-line... as can
even C<"7bit"> and C<"8bit"> (since all these encodings guarantee 
short lines, with a max of 1000 characters).
The good news is: it is very likely that it will be similarly-easy to 
write a MIME::Decoder for any future standard encodings.

The C<"binary"> decoder, however, really required block reads and writes:
see L<"MIME::Decoder::Binary"> for details.


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

$Revision: 2.9 $ $Date: 1997/01/03 21:06:09 $

=cut


#------------------------------------------------------------
# Execute simple test if run as a script...
#------------------------------------------------------------
{ 
  package main; no strict;
  eval join('',<main::DATA>) || die "$@ $main::DATA" unless caller();
}
1;           # end the module
__END__

BEGIN { 
  unshift @INC, ".","./etc" 
}

use MIME::Decoder;
use MIME::ToolUtils qw(:msgs);
    

MIME::ToolUtils->debugging(1);

debug "Cool: quoted-printable is supported...";
if ($ARGV[0] =~ /-e(.*)/) {
    $decoder = new MIME::Decoder $1;
    debug "Waiting to encode data on STDIN...";
    $decoder->encode(\*STDIN, \*STDOUT);
}
elsif ($ARGV[0] =~ /-d(.*)/) {
    $decoder = new MIME::Decoder $1;
    debug "Waiting to decode data on STDIN...";
    $decoder->decode(\*STDIN, \*STDOUT);
}
else {
    die "usage: script -[de]DECODER"
}

1;
