package MIME::Latin1;

=head1 NAME

MIME::Latin1 - translate ISO-8859-1 into 7-bit approximations

=head1 SYNOPSIS

    use MIME::Latin1 qw(latin1_to_ascii);
    
    $dirty = "Fran\347ois";
    print latin1_to_ascii($dirty);      # prints out "Fran\c,ois"

=head1 DESCRIPTION

This is a small package used by the C<"7bit"> encoder/decoder for
handling the case where a user wants to 7bit-encode a document
that contains 8-bit (presumably Latin-1) characters.

=head1 PUBLIC INTERFACE 

=over

=cut

use strict;
use vars qw(@Map @ISA @EXPORT_OK $VERSION);

require Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw(latin1_to_ascii);


# The package version, both in 1.23 style *and* usable by MakeMaker:
( $VERSION ) = '$Revision: 1.1 $ ' =~ /\$Revision:\s+([^\s]+)/;

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
 '-:'   , #  ÷   247   division sign
 'o/'   , #  ø   248   small o, slash
 "u`"   , #  ù   249   small u, grave accent
 "u'"   , #  ú   250   small u, acute accent
 "u^"   , #  û   251   small u, circumflex accent
 'u"'   , #  ü   252   small u, dieresis or umlaut mark
 "y'"   , #  ý   253   small y, acute accent
 "th"   , #  þ   254   small thorn, Icelandic
 'y"'   , #  ÿ   255   small y, dieresis or umlaut mark
);

=item latin1_to_ascii STRING,[OPTS]

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
tweaked by the OPTS string:

B<If no OPTS string is given,> only 8-bit characters are affected,
and their output is of the form C<\xy>:

      \<<Fran\c,ois Mu\"ller\>>   c:\usr\games

B<If the OPTS string contains 'NOSLASH',> then the leading C<"\">
is not output, and the output is more compact:

      <<Franc,ois Mu"ller>>       c:\usr\games

B<If the OPTS string contains 'ENCODE',> then not only is the leading C<"\">
output, but any other occurences of C<"\"> are escaped as well by turning
them into C<"\\">.  This produces output which may easily be parsed
and turned back into the original 8-bit characters, so in a way it is
its own full-fledged encoding... and given that C<"\"> is a rare-enough
character, not much uglier that the normal output: 

      \<<Fran\c,ois Mu\"ller\>>   c:\\usr\\games

=cut

sub latin1_to_ascii {
    my ($str, $opts) = @_;

    # Extract options:
    $opts ||= '';
    my $o_encode  = ($opts =~ /\bENCODE\b/i);
    my $o_noslash = ($opts =~ /\bNOSLASH\b/i) && !$o_encode;
    my $slash = ($o_noslash ? '' : '\\');

    # Encode:
    $str =~ s/\\/\\\\/g if $o_encode;
    $str =~ s/[\240-\377]/$slash.$Map[ord($&)-0240]||''/eg;
    $str;
}

=back

=head1 AUTHOR

Copyright (c) 1996 by Eryq / eryq@rhine.gsfc.nasa.gov

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 1.1 $ $Date: 1996/10/17 15:22:24 $

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


    
use MIME::Latin1 qw(latin1_to_ascii);


$dirty = "\253Fran\347ois M\374ller\273 c:\\usr\\games";
print "\n";

print "Option: default:\n";
print latin1_to_ascii($dirty), "\n\n";

print "Option: ENCODE:\n";
print latin1_to_ascii($dirty, 'ENCODE'), "\n\n";

print "Option: NOSLASH:\n";
print latin1_to_ascii($dirty, 'NOSLASH'), "\n\n";



#------------------------------------------------------------
1;
