package MIME::Latin1;

=head1 NAME

MIME::Latin1 - DEPRECATED package to translate ISO-8859-1 
               into 7-bit approximations


=head1 SYNOPSIS

    use MIME::Latin1 qw(latin1_to_ascii);
    
    $dirty = "Fran\347ois";
    print latin1_to_ascii($dirty);      # prints out "Fran\c,ois"


=head1 DESCRIPTION

I<This module is so deprecated, it's not funny.>  
File this under "seemed like a good idea at the time"... I'm still
including it with the distribution so that existing code won't
break too badly, but it will be detached from the main MIME code
base, and ultimately may vanish (at least from MIME::).

This is a small package used by the C<"7bit"> encoder/decoder for
handling the case where a user wants to 7bit-encode a document
that contains 8-bit (presumably Latin-1) characters.  It provides
a mapping whereby every 8 bit character is mapped to a unique
sequence of two 7-bit characters that approximates the appearance
or pronunciation of the Latin-1 character.  For example:

    This...                   maps to...
    --------------------------------------------------
    A c with a cedilla        c,
    A C with a cedilla        C,
    An "AE" ligature          AE
    An "ae" ligature          ae
    Yen sign                  Y-

I call each of these 7-bit 2-character encodings I<mnemonic encodings>, 
since they (hopefully) are visually reminiscent of the 8-bit
characters they are meant to represent.


=head1 PUBLIC INTERFACE 

=over 4

=cut

use strict;
use vars qw(@Map %InvMap @ISA @EXPORT_OK $VERSION);

require Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw(latin1_to_ascii ascii_to_latin1);


# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4.102 $, 10;

# The map:
@Map = (
          #  char decimal description
          #------------------------------------------------------------

 "  "   , #      160   non-breaking space
 "!!"   , #  ¡   161   inverted exclamation
 "c/"   , #  ¢   162   cent sign
 "L-"   , #  £   163   pound sterling
 "ox"   , #  ¤   164   general currency sign
 "Y-"   , #  ¥   165   yen sign
 "||"   , #  ¦   166   broken vertical bar
 "so"   , #  §   167   section sign

 '""'   , #  ¨   168   umlaut (dieresis)
 "co"   , #  ©   169   copyright
 "-a"   , #  ª   170   feminine ordinal
 "<<"   , #  «   171   left angle quote, guillemotleft
 "-,"   , #  ¬   172   not sign
 "--"   , #  ­   173   soft hyphen
 "ro"   , #  ®   174   registered trademark
 "^-"   , #  ¯   175   macron accent

 "^*"   , #  °   176   degree sign
 "+-"   , #  ±   177   plus or minus
 "^2"   , #  ²   178   superscript two
 "^3"   , #  ³   179   superscript three
 "' "   , #  ´   180   acute accent
 "/u"   , #  µ   181   micro sign
 "P!"   , #  ¶   182   paragraph sign
 "^."   , #  ·   183   middle dot

 ",,"   , #  ¸   184   cedilla
 "^1"   , #  ¹   185   superscript one
 "_o"   , #  º   186   masculine ordinal
 ">>"   , #  »   187   right angle quote, guillemotright
 "14"   , #  ¼   188   fraction one-fourth
 "12"   , #  ½   189   fraction one-half
 "34"   , #  ¾   190   fraction three-fourths
 "??"   , #  ¿   191   inverted question mark

 "A`"   , #  À   192   capital A, grave accent
 "A'"   , #  Á   193   capital A, acute accent
 "A^"   , #  Â   194   capital A, circumflex accent
 "A~"   , #  Ã   195   capital A, tilde
 'A"'   , #  Ä   196   capital A, dieresis or umlaut mark
 'A*'   , #  Å   197   capital A, ring
 'AE'   , #  Æ   198   capital AE diphthong (ligature)
 'C,'   , #  Ç   199   capital C, cedilla

 "E`"   , #  È   200   capital E, grave accent
 "E'"   , #  É   201   capital E, acute accent
 'E^'   , #  Ê   202   capital E, circumflex accent
 'E"'   , #  Ë   203   capital E, dieresis or umlaut mark
 "I`"   , #  Ì   204   capital I, grave accent
 "I'"   , #  Í   205   capital I, acute accent
 "I^"   , #  Î   206   capital I, circumflex accent
 'I"'   , #  Ï   207   capital I, dieresis or umlaut mark

 'D-'   , #  Ð   208   capital Eth, Icelandic
 'N~'   , #  Ñ   209   capital N, tilde
 "O`"   , #  Ò   210   capital O, grave accent
 "O'"   , #  Ó   211   capital O, acute accent
 "O^"   , #  Ô   212   capital O, circumflex accent
 "O~"   , #  Õ   213   capital O, tilde
 'O"'   , #  Ö   214   capital O, dieresis or umlaut mark
 'xx'   , #  ×   215   multiply sign

 'O/'   , #  Ø   216   capital O, slash
 'U`'   , #  Ù   217   capital U, grave accent
 "U'"   , #  Ú   218   capital U, acute accent
 "U^"   , #  Û   219   capital U, circumflex accent
 'U"'   , #  Ü   220   capital U, dieresis or umlaut mark
 "Y'"   , #  Ý   221   capital Y, acute accent
 "P|"   , #  Þ   222   capital THORN, Icelandic
 "ss"   , #  ß   223   small sharp s, German (sz ligature)

 "a`"   , #  à   224   small a, grave accent
 "a'"   , #  á   225   small a, acute accent
 "a^"   , #  â   226   small a, circumflex accent
 "a~"   , #  ã   227   small a, tilde
 'a"'   , #  ä   228   small a, dieresis or umlaut mark
 'a*'   , #  å   229   small a, ring
 'ae'   , #  æ   230   small ae diphthong (ligature)
 'c,'   , #  ç   231   small c, cedilla

 "e`"   , #  è   232   small e, grave accent
 "e'"   , #  é   233   small e, acute accent
 "e^"   , #  ê   234   small e, circumflex accent
 'e"'   , #  ë   235   small e, dieresis or umlaut mark
 "i`"   , #  ì   236   small i, grave accent
 "i'"   , #  í   237   small i, acute accent
 "i^"   , #  î   238   small i, circumflex accent
 'i"'   , #  ï   239   small i, dieresis or umlaut mark

 'd-'   , #  ð   240   small eth, Icelandic
 'n~'   , #  ñ   241   small n, tilde
 "o`"   , #  ò   242   small o, grave accent
 "o'"   , #  ó   243   small o, acute accent
 "o^"   , #  ô   244   small o, circumflex accent
 "o~"   , #  õ   245   small o, tilde
 'o"'   , #  ö   246   small o, dieresis or umlaut mark
 '//'   , #  ÷   247   division sign (formerly -:)

 'o/'   , #  ø   248   small o, slash
 "u`"   , #  ù   249   small u, grave accent
 "u'"   , #  ú   250   small u, acute accent
 "u^"   , #  û   251   small u, circumflex accent
 'u"'   , #  ü   252   small u, dieresis or umlaut mark
 "y'"   , #  ý   253   small y, acute accent
 "th"   , #  þ   254   small thorn, Icelandic
 'y"'   , #  ÿ   255   small y, dieresis or umlaut mark
);

# Inverse mapping:
%InvMap = ();


=item latin1_to_ascii STRING,[OPTS]

I<Function.>
Map the Latin-1 characters in the string to sequences of the form:

     \xy

Where C<xy> is a two-character sequence that visually approximates
the Latin-1 character.  For example:

     c cedilla      => \c,
     n tilde        => \n~
     AE ligature    => \AE
     small o slash  => \o/

The sequences are taken almost exactly from the Sun character composition
sequences for generating these characters.  The translation may be further
tweaked by the (optional) OPTS string:

=over 4

=item READABLE

I<Currently the default.>  
Only 8-bit characters are affected, and their output is of the form C<\xy>:

      \<<Fran\c,ois M\u"ller\>>   c:\usr\games

=item NOSLASH

Exactly like READABLE, except the leading C<"\"> is not inserted,
making the output more compact:

      <<Franc,ois Mu"ller>>       c:\usr\games

=item ENCODE

Not only is the leading C<"\"> output, but any other occurences of C<"\"> 
are escaped as well by turning them into C<"\\">.  Unlike the other options,
this produces output which may easily be parsed and turned back into the 
original 8-bit characters, so in a way it is its own full-fledged encoding... 
and given that C<"\"> is a rare-enough character, not much uglier that the 
normal output: 

      \<<Fran\c,ois M\u"ller\>>   c:\\usr\\games

You may use C<ascii_to_latin1> to decode this.

=back

B<Note:> as of 3.12, the options string must, if defined,
be one of the above options.  Composite options like "ENCODE|NOSLASH"
will no longer be supported (most will be self-contradictory anyway).

=cut

sub latin1_to_ascii {
    my ($str, $opts) = @_;

    # Extract options:
    $opts ||= 'READABLE';
    ($opts =~ /^(ENCODE|NOSLASH|READABLE)$/) or 
	die "unsupported Latin-1 encoding ($opts): please see documentation";
    my $slash = (($opts eq 'NOSLASH') ? '' : '\\');
    
    # Encode:
    $str =~ s/\\/\\\\/g if ($opts eq 'ENCODE');
    $str =~ s/[\200-\237]/$slash.lcfirst(sprintf("%02X", ord($&)))/eg;
    $str =~ s/[\240-\377]/$slash.$Map[ord($&)-0240]||'\??'/eg;
    $str;
}


=item ascii_to_latin1 STRING

I<Function.>
Map the Latin-1 escapes in the string (sequences of the form C<\xy>)
back into actual 8-bit characters.  

   # Assume $enc holds the actual text...    \<<Fran\c,ois \\ M\u"ller\>>
   print ascii_to_latin1($enc);

Unrecognized sequences are turned into '?' characters.

B<Note:> I<you must have specified the "ENCODE" option when encoding 
in order to decode!>

=cut

sub ascii_to_latin1 {
    my $str = shift;

    # Build inverse map, if not there already:
    unless (%InvMap) {
	my $i = 0240;
	foreach ($i = 0240; $i <= 0377; $i++) { 
	    $InvMap{$Map[$i-0240]} = pack("C", $i);
	}
	$InvMap{'\\'} = '\\';
    }

    # Decode:
    $str =~ s{\\([89a-f][0-9A-F])}{pack("C", hex(uc($1)))}ge;
    $str =~ s{\\(\\|[^\\].)}{$InvMap{$1}||'?'}eg;
    $str;
}


=back

=head1 NOTES

=over 4

=item Hex encoding

Characters in the octal range \200-\237 (hexadecimal \x80-\x9F) 
currently do not have mnemonic Latin-1 equivalents, and therefore 
are represented by the hex sequences "80" through "9F", where 
the second hex digit is B<upcased.>  That is:

   80  81  82  83  84  85  86  87  88  89  8A  8B  8C  8D  8E  8F
   90  91  92  93  94  95  96  97  98  99  9A  9B  9C  9D  9E  9F

To allow this scheme to work properly for I<all> 8-bit-on characters, 
the general rule is: 
I<the first hex digit is DOWNcased, and the second hex digit is UPcased.>
Hence, these are all decodable sequences:

   a0  a1  a2  a3  a4  a5  a6  a7  a8  a9  aA  aB  aC  aD  aE  aF   

This "downcase-upcase" style is so we don't conflict with mnemonically-encoded 
ligatures like "ae" and "AE", the latter of which could reasonably 
have been represented as "Ae".

Note that we must never have a mnemonic encoding that could be mistaken for
a hex sequence from "80" to "fF", since the ambiguity would make it impossible
to decode.  (However, "12", "34", "Ff", etc. are perfectly fine.)

I<Thanks to Rolf Nelson for reporting the "gap" in the encoding.>


=item Other restrictions

B<The first character of a 2-character encoding can not be a "\">.  
This is because "\\" represents an encoded "\": to allow "\\x"
would introduce an ambiguity for the decoder.


=item Going backwards

Since the mappings may fluctuate over time as I get more input, 
anyone writing a translator would be well-advised to use ascii_to_latin1()
to perform the reverse mapping.  I will strive for backwards-compatibility
in that code.


=item Got a problem?

If you have better suggestions for some of the character representations,
please contact me.

=back


=head1 AUTHOR

Copyright (c) 1996, 1997 by Eryq / eryq@zeegee.com

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 4.102 $ $Date: 1997/12/14 08:51:50 $

=cut



#------------------------------------------------------------
# Execute simple test if run as a script.
#------------------------------------------------------------
{ 
  package main; no strict;
  eval join('',<main::DATA>) || die "$@ $main::DATA" unless caller();
}
1;           # end the module
__END__


    
use MIME::Latin1 qw(latin1_to_ascii ascii_to_latin1);


$raw ="\253Fran\347ois \\ M\374ller\273 c:\\usr\\games \x80\x8A\x98\x9F\\\\";
print "\n";

print "* Raw:\n";
print $raw, "\n\n";

print "* Option: default:\n";
print latin1_to_ascii($raw), "\n\n";

print "* Option: NOSLASH:\n";
print latin1_to_ascii($raw, 'NOSLASH'), "\n\n";

print "* Option: ENCODE:\n";
print latin1_to_ascii($raw, 'ENCODE'), "\n\n";

print "* The result of decoding option ENCODE:\n";
my $refried = ascii_to_latin1(latin1_to_ascii($raw, 'ENCODE'));
die "conversion back to ASCII failed" if ($raw ne $refried);
print $refried, "\n\n";

print "*** Pipe this through 'less' to see the unseeable.\n";

#------------------------------------------------------------
1;
