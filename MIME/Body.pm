package MIME::Body;


=head1 NAME

MIME::Body - the body of a MIME message


=head1 SYNOPSIS

Here's how a typical body object is created and used:

   # Create new body:
   $body = new MIME::Body::File "/path/to/file";
   
   # Write data to the body:
   $IO = $body->open("w")      || die "open body: $!";
   $IO->print($message);
   $IO->close                  || die "close I/O handle: $!";
   
   # Read data from the body:
   $IO = $body->open("r")      || die "open body: $!";
   while (defined($_ = $IO->getline)) {
       # do stuff
   }
   $IO->close                  || die "close I/O handle: $!";

For example, this subclass stores the data in a disk file, which
is only opened when needed:

   $body = new MIME::Body::File "/path/to/file";

While I<this> subclass stores the data in an in-core scalar:

   $body = new MIME::Body::Scalar \$scalar;

In any case, once a MIME::Body has been created, you use the same
mechanisms for reading from or writing to it, no matter what the subclass
is.


=head1 DESCRIPTION

MIME messages can be very long (e.g., tar files, MPEGs, etc.) or very
short (short textual notes, as in ordinary mail).  Long messages
are best stored in files, while short ones are perhaps best stored
in core.

This class is an attempt to define a common interface for objects
which contain that message data, regardless of how the data is
physically stored.  It works this way:

=over

=item *

B<A "body" knows where the data is.>  You can ask to "open" this data
source for I<reading> or I<writing>, and you will get back an "I/O handle".

=item *

B<An "I/O handle" knows how to read/write the data.>
It is an object that is basically like an IO::Handle
or a FileHandle: it can be any class, so long as it supports a small,
standard set of methods for reading from or writing to the underlying
data source.

=back

The lifespan of a "body" usually looks like this:

=over

=item 1.

Body object is created by a MIME::Parser during parsing.
It's at this point that the actual MIME::Body subclass is chosen,
and new() is invoked.  (For example: if the body data is going to 
a file, then it is at this point that the class MIME::Body::File,
and the filename, is chosen).

=item 2.

Data is written (usually by the MIME parser) like this:

a. Body is opened for writing, via C<open("w")>.
   This will trash any previous contents, and return an 
   "I/O handle" opened for writing.

b. Data is written to the I/O handle, via print().

c. I/O handle is closed, via close().

=item 3. 

Data is read (usually by the user application) like this: 

a. Body is opened for reading by a user application, via C<open("r")>.
   This will return an "I/O handle" opened for reading.

b. Data is read from the I/O handle, via read(), getline(), or getlines().

c. I/O handle is closed, via close().

=item 4. 

Body object is destructed.

=back

You can write your own subclasses, as long as they follow the
interface described below.  Implementers of subclasses should assume
that steps 2 and 3 may be repeated any number of times, and in
different orders (e.g., 1-2-2-3-2-3-3-3-3-3-2-4).

Users should be aware that unless they know for certain what they
have, they should not assume that the body has an underlying
filehandle.


=head1 DEFINING YOUR OWN SUBCLASSES

So you're not happy with files, scalars, and arrays?
No problem: just define your own MIME::Body subclass, and make a subclass
of MIME::Parser or MIME::ParserBase which returns an instance of your
body class whenever appropriate in the C<new_body_for(head)> method.

I<Things to make you go hmm:> there's nothing stopping you from
writing a single class that is both a "body" class and an "I/O handle"
class for that body.  Look at B<MIME::Body::Scalar> for an example.


=head2 Writing a "body" class

Your "body" class must inherit from MIME::Body (or some subclass of it),
and it must either provide or inherit the following methods:

=over

=item init ARGS...

I<Instance method.>
This is called automatically by C<new()>, with the arguments given
to C<new()>.  The arguments are optional, and entirely up to your class.

=item open MODE

I<Instance method.>
This should do whatever is necessary to open the body for either
writing (if MODE is "w") or reading (if mode is "r").
Return an "I/O handle" on success, false on error.

=item binmode [ONOFF]

I<Instance method.>
With argument, flags whether or not open() should return an I/O handle
which has binmode() activated.  With no argument, just returns the
current value.  The inherited action should be fine.

=item path

I<Instance method.>
Oh, the joys of encapsulation.
If you're storing the body data in a new disk file, you'll want to
give applications the ability to get at that file, if only for cleanup.
This method should return the path to the file, or undef 
if there is none (e.g., if the data is in core).  The default 
inherited method just returns undef.

=back


=head2 Writing/using an "I/O handle" class

Your "body" class' C<open()> method must return an "I/O handle" object, 
which can be any object that supports a small set of standard methods for 
reading/writing data.  

See the documentation on the B<MIME::IO> class for details on 
what is expected of an I/O handle.
Note that the B<IO::Handle> class already conforms to this interface,
as does B<MIME::IO>.


=head1 NOTES

=head2 Design issues

One reason I didn't just use FileHandle or IO::Handle objects for message
bodies was that I wanted a "body" object to be a form of completely
encapsulated program-persistent storage; that is, I wanted users
to be able to write code like this...

   # Get body handle from this MIME message, and read its data:
   $body = $entity->bodyhandle;
   $IO = $body->open("r");
   while (defined($_ = $IO->getline)) {
       print STDOUT $_;
   }
   $IO->close;

...without requiring that they know anything more about how the
$body object is actually storing its data (disk file, scalar variable,
array variable, or whatever).

Storing the body of each MIME message in a persistently-open
IO::Handle was a possibility, but it seemed like a bad idea,
considering that a single multipart MIME message could easily suck up
all the available file descriptors.  This risk increases if the user
application is processing more than one MIME entity at a time.


=head1 SUBCLASSES

=cut


# Pragmas:
use strict;

# System modules:
use Carp;


#------------------------------
# new
#------------------------------
sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->init(@_);
    $self;
}
#------------------------------
# binmode
#------------------------------
sub binmode {
    my ($self, $onoff) = @_;
    $self->{MB_Binmode} = $onoff if (@_ > 1);
    $self->{MB_Binmode};
}
#------------------------------
# path
#------------------------------
sub path {
    undef;
}



# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

=head2 MIME::Body::File;

A body class that stores the data in a disk file.  
The I/O handle is a wrapped filehandle.
Invoke the constructor as:

    $body = new MIME::Body::File "/path/to/file";

In this case, the C<path()> method would return the given path.

You can even use this class to pipe the data through shell commands
on input and/or output.  For example, here's an easy way to store the
data in compressed format without having to explicitly do the compression
yourself:

    $body = new MIME::Body::File "/tmp/somefile.gz";
    $body->writer("| gzip > /tmp/somefile.gz");
    $body->reader("zcat /tmp/somefile.gz |");
    ...
    $IO = $body->open("w")  || die "open failed: $!";
    $IO->print("I'll automatically be stored compressed!\n");
    $IO->close              || die "close failed: $!"; 

Notice the semantics of the "path" in this case: it names the file 
that is created to hold the data, even though that file can't be 
used directly.

B<Note:> All of the usual caveats related to shell commands apply!
To make sure you won't accidentally do something you'll regret, 
use taint-checking (B<perl -T>) in your application.

=cut

package MIME::Body::File;

# Pragmas:
use vars qw(@ISA);
use strict;

# System modules:
require FileHandle;

# Kit modules:
use MIME::IO;

@ISA = qw(MIME::Body);


#------------------------------
# init PATH
#------------------------------
sub init {
    my ($self, $path) = @_;
    $self->{Path}   = $path;
    $self->{Reader} = "<$path";
    $self->{Writer} = ">$path";
    $self;
}
#------------------------------
# open MODE
#------------------------------
sub open {
    my ($self, $mode) = @_;
    my $IO;
    if ($mode eq 'w') {          # writing
	$IO = FileHandle->new($self->writer) || die "open $self->{Writer}: $!";
    }
    elsif ($mode eq 'r') {       # reading
	$IO = FileHandle->new($self->reader) || die "open $self->{Reader}: $!";
    }
    else {  
	die "bad mode: '$mode'";
    }
    binmode($IO) if $self->binmode;        # set binary read/write mode
    return (wrap MIME::IO::Handle $IO);    # wrap if old FileHandle class
}
#------------------------------
# path PATH - get/set the path
#------------------------------
sub path {
    my $self = shift;
    $self->{Path} = shift if (@_);
    $self->{Path};
}
#------------------------------
# reader -- get/set the reader
#------------------------------
sub reader {
    my $self = shift;
    $self->{Reader} = shift if (@_);
    $self->{Reader};
}
#------------------------------
# writer -- get/set the writer
#------------------------------
sub writer {
    my $self = shift;
    $self->{Writer} = shift if (@_);
    $self->{Writer};
}




# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

=head2 MIME::Body::Scalar;

A body class that stores the data in-core, in a simple scalar.
Invoke the constructor as:

    $body = new MIME::Body::Scalar \$scalar;

A single scalar argument sets the body to that value, exactly as though
you'd opened for the body for writing, written the value, 
and closed the body again:
    
    $body = new MIME::Body::Scalar "Line 1\nLine 2\nLine 3";

A single array reference sets the body to the result of joining all the
elements of that array together:

    $body = new MIME::Body::Scalar ["Line 1\n",
                                    "Line 2\n",
                                    "Line 3"];

Uses B<MIME::IO::Scalar> as the I/O handle.

=cut

package MIME::Body::Scalar;

use vars qw(@ISA);
use strict;

use Carp;
require FileHandle;

use MIME::IO;

@ISA = qw(MIME::Body);


#------------------------------
# init PATH
#------------------------------
sub init {
    my ($self, $data) = @_;
    if (ref($data) && (ref($data) eq 'ARRAY')) {
	$data = join('',@$data);
    }
    $self->{Data} = (defined($data) ? $data : '');
    $self;
}
#------------------------------
# open MODE
#------------------------------
sub open {
    my ($self, $mode) = @_;
    $self->{Data} = '' if ($mode eq 'w');        # writing
    return new MIME::IO::Scalar \($self->{Data});
}


#------------------------------------------------------------

=head1 AUTHOR

Copyright (c) 1996 by Eryq / eryq@rhine.gsfc.nasa.gov  

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.

Thanks to Achim Bohnet for suggesting that MIME::Parser not be restricted
to the use of FileHandles.


=head1 VERSION

$Revision: 1.9 $ $Date: 1996/10/28 06:51:47 $

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


# Pick up other MIME stuff, just in case...
BEGIN { unshift @INC, ".", "./etc" }


my $body;
my $data;


# Test scalar handles:
$body = new MIME::Body::Scalar;
#
dump_body($body, "Scalar");

# Test file handles:
$body = new MIME::Body::File "somefile.gz";
#
dump_body($body, "File");

# Test compressed handles:
$body = new MIME::Body::File "somefile.gz";
$body->writer("| gzip > somefile.gz");
$body->reader("zcat somefile.gz |");
#
dump_body($body, "Compressed");
unlink "somefile.gz";

sub dump_body {
    my $body = shift;
    my $test = shift;
    my $IO;

    print "-" x 30, "\n";
    print $test, "...\n";
    print "-" x 30, "\n\n";

    print "* Writing data: \n";
    $IO = $body->open("w") || die "open: $!";
    $IO->print("First line\n", "Second line\n");
    $IO->print("Third line!");    
    $IO->close     || die "close: $!";

    print "* Reading all at once: \n";
    $IO = $body->open("r");
    my $nread = $IO->read($data, 2048);
    $IO->close;
    print "Data ($nread bytes) = <<<$data>>>\n\n";
    
    print "* Reading 10 bytes at a time: \n";
    $IO = $body->open("r");
    while (($nread = $IO->read($data, 10)) > 0) {
	print "Chunk ($nread bytes): <$data>\n";
    }
    $IO->close;
    print "\n\n";

    print "* Reading line by line: \n";
    $IO = $body->open("r");
    while (defined($_ = $IO->getline)) {
	print "Line: <$_>";
    }
    $IO->close;
    print "\n\n";

    print "* Reading all lines: \n";
    $IO = $body->open("r");
    my @lines = $IO->getlines;
    $IO->close;
    print "All = <<<", @lines, ">>>\n\n";
}


# So we know everything went well...
exit 0;

#------------------------------------------------------------
1;



