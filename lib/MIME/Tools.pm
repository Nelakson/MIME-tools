package MIME::Tools;

# Because the POD documenation is pretty extensive, it follows
# the __END__ statement below...

use strict;
use vars qw(@ISA %CONFIG @EXPORT_OK %EXPORT_TAGS $VERSION
	    $LOG $Tmpopen);

use Exporter;
use FileHandle;
use Carp;
use MIME::Tools::ToolkitLogger;

@ISA = qw(Exporter);


#------------------------------
#
# GLOBALS...
#
#------------------------------

### Exporting (importing should only be done by modules in this toolkit!):
%EXPORT_TAGS = (
    'config'  => [qw( %CONFIG )],
    'msgs'    => [qw( $LOG )],
    );
Exporter::export_ok_tags('config', 'msgs');

### The TOOLKIT version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 6.110 $, 10;


### Configuration (do NOT alter this directly)...
### All legal CONFIG vars *must* be in here, even if only to be set to undef:
%CONFIG =
    (
     DEBUGGING       => 0,
     QUIET           => 0,
     );


### Toolkit-wide logging:
BEGIN {
    $LOG = new MIME::Tools::ToolkitLogger;
}


#------------------------------
#
# CONFIGURATION... (see below)
#
#------------------------------

sub debugging {
    my ($class, $value) = @_;
    $CONFIG{'DEBUGGING'} = $value   if (@_ > 1);
    $CONFIG{'DEBUGGING'};
}

sub quiet {
    my ($class, $value) = @_;
    $CONFIG{'QUIET'} = $value   if (@_ > 1);
    $CONFIG{'QUIET'};
}

sub version {
    my ($class, $value) = @_;
    $VERSION;
}

### Configuration for MIME::Tools::Utils
$Tmpopen = sub { IO::File->new_tmpfile; }; 

#------------------------------
1;
package MIME::ToolUtils;
@MIME::ToolUtils::ISA = qw(MIME::Tools);
__END__


=head1 NAME

MIME-tools - modules for parsing (and creating!) MIME entities


=head1 SYNOPSIS

For each of access, the MIME-tools manual has been split up 
into several sections:

   MIME::
     Tools::  
  
       primer      Don't know what MIME is?  Learn the basics here.    
       overview    A quick tour of the toolkit and what it can do.
      
       changes     Change log for the toolkit.
       config      How to configure the toolkit.
       diag        Diagnostics used by the toolkit, for troubleshooting.
       faq         I try to answer all questions here.
       tips        Friendly words of wisdom before you begin coding.
       traps       Common pitfalls to avoid.
       tricks      Cool ways to do useful things.      


E.g., "perldoc MIME::Tools::overview".



=head1 DESCRIPTION

MIME-tools is a collection of Perl5 MIME:: modules for parsing, decoding,
I<and generating> single- or multipart (even nested multipart) MIME
messages.  (Yes, kids, that means you can send messages with attached
GIF files).


=head1 REQUIREMENTS

You will need the following installed on your system:

	File::Path
	File::Spec
	IPC::Open2              (optional)
	IO::Scalar, ...         from the IO-stringy distribution
	MIME::Base64
	MIME::QuotedPrint
	Net::SMTP
	Mail::Internet, ...     from the MailTools distribution.
        Unicode::Map
        Unicode::String

See the Makefile.PL in your distribution for the most-comprehensive
list of prerequisite modules and their version numbers.



=head1 TERMS AND CONDITIONS

Eryq (F<eryq@zeegee.com>), ZeeGee Software Inc (F<http://www.zeegee.com>).

Copyright (c) 1998, 1999 by ZeeGee Software Inc (www.zeegee.com).

All rights reserved.  This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.
See the COPYING file in the distribution for details.



=head1 SUPPORT

Please email me directly with questions/problems (see AUTHOR below).

If you want to be placed on an email distribution list (not a mailing list!)
for MIME-tools, and receive bug reports, patches, and updates as to when new
MIME-tools releases are planned, just email me and say so.  If your project
is using MIME-tools, it might not be a bad idea to find out about those
bugs I<before> they become problems...


=head1 VERSION

$Revision: 6.110 $



=head1 CHANGES

See L<MIME::Tools::changes> for the full change log.



=head1 AUTHOR

=head2 Primary maintainer

MIME-tools was created by:

    ___  _ _ _   _  ___ _
   / _ \| '_| | | |/ _ ' /    Eryq, (eryq@zeegee.com)
  |  __/| | | |_| | |_| |     President, ZeeGee Software Inc.
   \___||_|  \__, |\__, |__   http://www.zeegee.com/
             |___/    |___/

Released as MIME-parser (1.0): April 1996.
Released as MIME-tools (2.0): October 1996.
Released as MIME-tools (4.0): December 1997.
Released as MIME-tools (5.0): May 2000.
Released as MIME-tools (6.0): June 2003.


=head2 Acknowledgments

B<This kit would not have been possible> but for the direct
contributions of the following:

    Gisle Aas             The MIME encoding/decoding modules.
    Laurent Amon          Bug reports and suggestions.
    Graham Barr           The new MailTools.
    Achim Bohnet          Numerous good suggestions, including the I/O model.
    Kent Boortz           Initial code for RFC-1522-decoding of MIME headers.
    Andreas Koenig        Numerous good ideas, tons of beta testing,
                            and help with CPAN-friendly packaging.
    Igor Starovoitov      Bug reports and suggestions.
    Jason L Tibbitts III  Bug reports, suggestions, patches.

Not to mention the Accidental Beta Test Team, whose bug reports (and
comments) have been invaluable in improving the whole:

    Phil Abercrombie
    Mike Blazer
    Brandon Browning
    Kurt Freytag
    Steve Kilbane
    Jake Morrison
    Rolf Nelson
    Joel Noble
    Michael W. Normandin
    Tim Pierce
    Andrew Pimlott
    Dragomir R. Radev
    Nickolay Saukh
    Russell Sutherland
    Larry Virden
    Zyx

Please forgive me if I've accidentally left you out.
Better yet, email me, and I'll put you in.


=head1 SEE ALSO

At the time of this writing ($Date: 2003/06/27 17:54:33 $),
the MIME-tools homepage was
F<http://www.zeegee.com/code/perl/MIME-tools>.
Check there for updates and support.

See L</SYNOPSIS> for related documentation in this toolkit.

Users of this toolkit may also wish to see 
L<Mail::Header> and L<Mail::Internet>.

The MIME format is documented in RFCs 2045-2049.

The MIME header format is an outgrowth of the mail header format
documented in RFC 822.

Enjoy.  Yell if it breaks.

=cut


