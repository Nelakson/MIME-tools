package MIME::Decoder::Gzip64;


=head1 NAME

MIME::Decoder::Gzip64 - decode a "base64" gzip stream


=head1 SYNOPSIS

A generic decoder object; see L<MIME::Decoder> for usage.


=head1 DESCRIPTION

A MIME::Decoder::Base64 subclass for a nonstandard encoding whereby
data are gzipped, then the gzipped file is base64-encoded.
Common non-standard MIME encodings for this:

    x-gzip64


=head1 AUTHOR

Copyright (c) 1996, 1997 by Eryq / eryq@zeegee.com

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 4.103 $ $Date: 1998/01/10 04:24:07 $

=cut


require 5.002;
use vars qw(@ISA $VERSION);
use MIME::Decoder;
use MIME::Base64;
use MIME::Decoder::Base64;
use MIME::ToolUtils qw(tmpopen whine);
use IO::Wrap;

@ISA = qw(MIME::Decoder::Base64);

# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4.103 $, 10;

#------------------------------
#
# decode_it IN, OUT
#
sub decode_it {
    my ($self, $in, $out) = @_;

    # Open a temp file (assume the worst, that this is a big stream):
    my $tmp = wraphandle(tmpopen() || die "can't get temp file");

    # Stage 1: decode the base64'd stream into zipped data:
    $self->SUPER::decode_it($in, $tmp) 
	or die "base64 decoding failed!";
    
    # Stage 2: un-zip the zipped data:
    $tmp->seek(0, 0); 
    $self->filter($tmp, $out, "gzip -d -") 
	or die "gzip decoding failed!";
    1;
}

#------------------------------
#
# encode_it IN, OUT
#
sub encode_it {
    my ($self, $in, $out) = @_;
    whine "Encoding ", $self->encoding, " is not standard MIME!"; 
    
    # Open a temp file (assume the worst, that this is a big stream):
    my $tmp = wraphandle(tmpopen() || die "can't get temp file");
  
    # Stage 1: zip the raw data:
    $self->filter($in, $tmp, "gzip -") 
	or die "gzip encoding failed!";
    
    # Stage 2: encode the zipped data via base64:
    $tmp->seek(0, 0);    
    $self->SUPER::encode_it($tmp, $out) 
	or die "base64 encoding failed!";
    1;
}

#------------------------------
1;

