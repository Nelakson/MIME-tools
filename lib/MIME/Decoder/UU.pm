package MIME::Decoder::UU;


=head1 NAME

MIME::Decoder::UU - decode a "uuencoded" stream


=head1 SYNOPSIS

A generic decoder object; see L<MIME::Decoder> for usage.


=head1 DESCRIPTION

A MIME::Decoder subclass for a nonstandard encoding whereby
data are uuencoded.  Common non-standard MIME encodings for this:

    x-uu
    x-uuencode


=head1 AUTHOR

Eryq (F<eryq@zeegee.com>), ZeeGee Software Inc (F<http://www.zeegee.com>).

UU-decoding code lifted from "uuexplode", a Perl script by an
unknown author...

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 5.202 $ $Date: 2000/06/05 13:37:56 $

=cut


require 5.002;
use vars qw(@ISA $VERSION);
use MIME::Decoder;
use MIME::Tools qw(whine);

@ISA = qw(MIME::Decoder);

# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5.202 $, 10;


#------------------------------
#
# decode_it IN, OUT
#
sub decode_it {
    my ($self, $in, $out) = @_;
    my ($mode, $file);

    # Find beginning...
    while (defined($_ = $in->getline)) {
	last if ($mode, $file) = /^begin\s*(\d*)\s*(\S*)/; 
    }
    die("uu decoding: no begin found\n") if !defined($_);      # hit eof!
    
    # Decode:
    while (defined($_ = $in->getline)) {
	last if /^end/;
	next if /[a-z]/;
	next unless int((((ord() - 32) & 077) + 2) / 3) == int(length() / 4);
	$out->print(unpack('u', $_));
    }
    ### chmod oct($mode), $file;    # sheeyeah... right...
    whine "file incomplete, no end found\n" if !defined($_); # eof
    1;
}

#------------------------------
#
# encode_it IN, OUT
#
sub encode_it {
    my ($self, $in, $out) = @_;
    my $buf = '';

    my $fname = (($self->head && 
		  $self->head->mime_attr('content-disposition.filename')) ||
		 '');
    $out->print("begin 644 $fname\n");
    while ($in->read($buf, 45)) { $out->print(pack('u', $buf)) }
    $out->print("end\n");
    1;
}

#------------------------------
1;
