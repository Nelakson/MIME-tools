package MIME::Decoder::Base64;


=head1 NAME

MIME::Decoder::Base64 - encode/decode a "base64" stream


=head1 SYNOPSIS

A generic decoder object; see L<MIME::Decoder> for usage.


=head1 DESCRIPTION

A L<MIME::Decoder> subclass for the C<"base64"> encoding.
The name was chosen to jibe with the pre-existing MIME::Base64
utility package, which this class actually uses to translate each chunk.

=over 4

=item *

When B<decoding>, the input is read one line at a time.
The input accumulates in an internal buffer, which is decoded in
multiple-of-4-sized chunks (plus a possible "leftover" input chunk,
of course).

=item *

When B<encoding>, the input is read 45 bytes at a time: this ensures
that the output lines are not too long.   We chose 45 since it is
a multiple of 3 and produces lines under 76 characters, as RFC-1521 
specifies.

=back


=head1 AUTHOR

Copyright (c) 1996 by Eryq / eryq@zeegee.com

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 4.104 $ $Date: 1998/01/10 04:24:44 $

=cut

use vars qw(@ISA $VERSION);
use MIME::Decoder;
use MIME::Base64 2.04;    

@ISA = qw(MIME::Decoder);

# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4.104 $, 10;

# How many bytes to encode at a time (must be a multiple of 3, and
# less than (76 * 0.75)!
my $EncodeChunkLength = 45;

#------------------------------
#
# decode_it IN, OUT
#
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

#------------------------------
#
# encode_it IN, OUT
#
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

#------------------------------
1;

