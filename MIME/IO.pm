package MIME::IO;

=head1 NAME

MIME::IO - a small package for turning things into IO handles

=head1 DESCRIPTION

As of MIME-tools 2.0, input and output routines cannot just assume that 
they are dealing with filehandles.  In an effort to come up with a nice,
OO way of encapsulating input/output streams, I decided to use a minimal
subset of Graham Barr's B<IO::Handle> interface (which is itself derived
from the FileHandle interface).

Therefore, all that MIME::Body, MIME::Decoder, and the other classes
require (and, thus, all that they can assume) is that they are manipulating
an object which responds to the following small, well-defined set of 
messages:

=over 4

=item close

I<Instance method.>
This should close the input/output stream.

=item getline

I<Instance method.>
This should get a single line from the input stream, and return it
(or undef on end of file).  The returned line should end
with the newline (unless, of course, this is the last line of a
file which is not terminated by a newline).  

=item getlines

I<Instance method.>
This should get the entire input stream as an array of lines,
which each line is terminated by the C<"\n"> (except, maybe,
the last one).

=item print ARGS...

I<Instance method.>
This should output the ARGS to the stream.

=item read BUFFER,NBYTES

I<Instance method.>
This should get NBYTES from the input stream, placing them in BUFFER.
It should return the number of bytes actually read, undef on error,
and 0 on end of file.

=back


By popular demand, I have also added the following to the built-in classes,
but I do not use them anywhere in the parsing/generating code so it's
safe for you to omit them from your class:

=over

=item seek POS,WHENCE

I<Instance method, FOR READ-OPENED STREAMS ONLY.>
Seek to the given POSition in the stream.  The WHENCE has the same
meaning as in the Perl built-in C<seek()>.

=item tell

I<Instance method, FOR READ-OPENED STREAMS ONLY.>
Tell the given position in the stream.

=back


I<Thanks to Achim Bohnet for suggesting this more-generic I/O model.>
I<Thanks to Jason L Tibbitts III for suggesting the seek/tell interface.>

=head1 BUILT-IN SUBCLASSES

=cut


use vars qw($VERSION);

# The package version, both in 1.23 style *and* usable by MakeMaker:
( $VERSION ) = '$Revision: 1.7 $ ' =~ /\$Revision:\s+([^\s]+)/;


#============================================================
#============================================================

package MIME::IO::Handle;

=head2 MIME::IO::Handle

=over 4

=item B<DESCRIPTION>

An I/O interface object wrapped around a raw filehandle.
If you hand this class' C<wrap()> constructor an argument, it is 
expected to be one of the following:

=over 4

=item *

B<A raw scalar filehandle name,> like C<"STDOUT"> or C<"Class::HANDLE">.
In this case, the filehandle name is wrapped in a MIME::IO object, 
which is returned.

=item *

B<A raw filehandle glob,> like C<\*STDOUT>.
In this case, the filehandle glob is wrapped in a MIME::IO object, 
which is returned.

=item *

B<A blessed FileHandle object.>
In this case, the FileHandle is wrapped in a MIME::IO object if and only
if your FileHandle class does not support the C<read()> method.

=item *

B<Any other kind of blessed object,> which is assumed to be already
conformant to the I/O object interface.
In this case, you just get back that object.

=back

Like this:

      my $IO = wrap MIME::IO::Handle \*STDOUT;

B<All this class does> is to provide a simple means for the MIME::
classes to wrap raw filehandles inside a class which responds to 
the above messages (by passing the messages on to the actual filehandle
in the form of the standard function calls).

The bottom line: what you get back is an object which is guaranteed 
to support the methods defined above.

This interface is used by many of the MIME-tool classes, for backwards 
compatibility with earlier versions of MIME-parser: if you supply a 
raw filehandle where an INSTREAM or OUTSTREAM is expected, most MIME
packages will automatically wrap that raw filehandle in a MIME::IO 
object, which fits the I/O handle criteria.

=item B<NOTES>

Clearly, when wrapping a raw external filehandle (like \*STDOUT), 
I didn't want to close the file descriptor when this object is
destructed... since the user might not appreciate that.  Hence,
there's no DESTROY method in this class.

When wrapping a FileHandle object, however, I believe that Perl will 
invoke the FileHandle::DESTROY when the last reference goes away,
so in that case, the filehandle is closed if the wrapped FileHandle
really was the last reference to it.

=back

=cut

no strict 'refs';

use FileHandle;
use Carp;

#------------------------------
# new
#------------------------------
sub new {
    my ($class, $raw) = @_;
    bless \$raw, $class;
}

#------------------------------
# wrap - coerce a filehandle into a blessed object that obeys our interface
#------------------------------
sub wrap {
    my ($class, $stream) = @_;
    if (!ref($stream) || (ref($stream) eq 'GLOB')) {
	return $class->new($stream);	
    }
    elsif ((ref($stream) eq 'FileHandle') && !defined(&FileHandle::read)) {
	return $class->new($stream);	
    }
    $stream;           # already okay!
}

#------------------------------
# I/O routines...
#------------------------------
sub close {
    my $self = shift;
    return close($$self);
}
sub getline {
    my $self = shift;
    my $fh = $$self;
    return scalar(<$fh>);
}
sub getlines {
    my $self = shift;
    wantarray or croak("Can't call getlines in scalar context!");
    my $fh = $$self;
    <$fh>;
}
sub print {
    my $self = shift;
    print { $$self } @_;
}
sub read {
    my $self = shift;
    return read($$self, $_[0], $_[1]);
}

sub seek {
    my $self = shift;
    return seek($$self, $_[0], $_[1]);
}
sub tell {
    my $self = shift;
    return tell($$self);
}




#============================================================
#============================================================

package MIME::IO::Scalar;

=head2 MIME::IO::Scalar

=over 4

=item DESCRIPTION

An I/O interface object wrapped around a scalar.  
This is to implement things that look like filehandles, but
which keep all of their data in-core.

Use it like this:

    $IO = new MIME::IO::Scalar \$scalar;
    $IO->print("Some data\n");
    $IO->print("Some more data\n");
    $IO->close;    # ...$scalar now holds "Some data\nSome more data\n"

=back

=cut

use strict;
use Carp;

#------------------------------
# new DATA
#------------------------------
sub new {
    my ($class, $sref) = @_;
    my $self = bless {}, $class;
    $self->{Sref} = $sref;
    $self->{Index} = 0;
    $self;
}

#------------------------------
# close
#------------------------------
sub close {
    1;
}

#------------------------------
# getline
#------------------------------
sub getline {
    my $self = shift;

    # Return undef right away if at EOF:
    return undef if ($self->{Index} >= length(${$self->{Sref}}));

    # Get next line:
    pos(${$self->{Sref}}) = $self->{Index}; # start matching at this point
    ${$self->{Sref}} =~ m/(.*)(\n|\Z)/g;    # match up to newline or EOS
    my $line = $&;                          # save it
    $self->{Index} += length($line);     # everybody remember where we parked!
    return $line; 
}

#------------------------------
# getlines
#------------------------------
sub getlines {
    my $self = shift;
    wantarray or croak("Can't call getlines in scalar context!");

    # Get all lines:
    my ($line, @lines);
    while (defined($line = $self->getline)) {
	push @lines, $line;
    }
    @lines;
}

#------------------------------
# print ARGS...
#------------------------------
sub print {
    my $self = shift;
    ${$self->{Sref}} .= join('', @_);
#   $self->{Index} = length(${$self->{Sref}});
    1;
}

#------------------------------
# read BUF,NBYTES
#------------------------------
sub read {
    my ($self, $buf, $n) = @_;
    my $read = substr(${$self->{Sref}}, $self->{Index}, $n);
    $self->{Index} += length($read);
    $_[1] = $read;
    return length($read);
}

#------------------------------
# seek POS,WHENCE
#------------------------------
# Warning: you may only seek when reading!

sub seek {
    my ($self, $pos, $whence) = @_;
    my $eofpos = length(${$self->{Sref}});

    # Seek:
    if    ($whence == 0) { $self->{Index} = $pos }
    elsif ($whence == 1) { $self->{Index} += $pos }
    elsif ($whence == 2) { $self->{Index} = $eofpos + $pos}
    else                 { die "bad seek whence ($whence)" }

    # Fixup:
    if ($self->{Index} < 0)       { $self->{Index} = 0 }
    if ($self->{Index} > $eofpos) { $self->{Index} = $eofpos }
    1;
}

#------------------------------
# tell
#------------------------------
sub tell {
    my $self = shift;
    $self->{Index};
}




=head1 NOTES

I know, I know: three-level-nesting of packages is evil when
those packages are not "private".  Sure, I could have made
this two modules, C<MIME::IOHandle> and C<MIME::IOScalar>...
but it just seemed more sensible to mimic the IO:: hierarchy,
one level down (under MIME::).


=head1 AUTHOR

Copyright (c) 1996 by Eryq / eryq@rhine.gsfc.nasa.gov

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 1.7 $ $Date: 1997/01/13 00:23:06 $


=cut

#------------------------------------------------------------
1;


