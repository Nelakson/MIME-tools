package MIME::IO;


=head1 NAME

MIME::IO - DEPRECATED package for turning things into IO handles


=head1 SYNOPSIS

I<Deprecated.>


=head1 WARNING

I<As of MIME-tools 4.0, these routines are done by IO:: modules.
This module will be going away soon.>


=head1 DESCRIPTION

As of MIME-tools 2.0, input and output routines cannot just assume that 
they are dealing with filehandles.  In an effort to come up with a nice,
OO way of encapsulating input/output streams, I decided to use a minimal
subset of Graham Barr's B<IO::Handle> interface.

Therefore, all that MIME::Body, MIME::Decoder, and the other classes
require (and, thus, all that they can assume) is that they are manipulating
an object which responds to the following small, well-defined set of 
messages:

   close
   getline
   getlines
   print ARGS...
   read BUFFER,NBYTES

Now with 5.004 on the shelves, tiehandle() makes this unnecessary.
Oh, well.   I<:-)>

=cut

use strict;
use vars qw($VERSION);

# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4.103 $, 10;


#============================================================
package MIME::IO::Handle;
#============================================================

=head2 MIME::IO::Handle

Obsoleted by IO::Wrap. The code:

    use MIME::IO;
    my $IO = wrap MIME::IO::Handle \*STDOUT;

can now be written more properly as:

    use IO::Wrap;
    my $IO = wraphandle \*STDOUT;

=cut

use IO::Wrap;
use MIME::ToolUtils;
sub wrap {
    my ($class, $raw) = @_;
    whine "MIME::IO::Handle is obsolete; please use IO::Wrap instead";
    wraphandle($raw);
}

#============================================================
package MIME::IO::Scalar;
#============================================================

=head2 MIME::IO::Scalar

Obsoleted by IO::Scalar.  The code:

    use MIME::IO;
    $IO = new MIME::IO::Scalar \$scalar;
    $IO->print("Some data\n");
    $IO->print("Some more data\n");
    $IO->close;    # ...$scalar now holds "Some data\nSome more data\n"

can now be written more properly as:

    use IO::Scalar;
    $IO = new IO::Scalar \$scalar;
    ...

=cut

use IO::Scalar;
@MIME::IO::Scalar::ISA = qw(IO::Scalar);


#------------------------------------------------------------

=head1 AUTHOR

Copyright (c) 1996, 1997 by Eryq / eryq@zeegee.com

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 4.103 $ $Date: 1998/01/10 06:01:33 $


=cut

1;


