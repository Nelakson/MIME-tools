package MIME::Parser;


=head1 NAME

MIME::Parser - split MIME mail into decoded components


=head1 SYNOPSIS

    # Create a new parser object:
    my $parser = new MIME::Parser;
        
    # Set up output directory for files:
    $parser->output_dir("$ENV{HOME}/mimemail");
    
    # Set up the prefix for files with auto-generated names:
    $parser->output_prefix("part");
    
    # If content length is <= 20000 bytes, store each msg as in-core scalar;
    # Else, write to a disk file (the default action):
    $parser->output_to_core(20000);
         
    # Parse an input stream:
    $entity = $parser->read(\*STDIN) or die "couldn't parse MIME stream";
    
    # Congratulations: you now have a (possibly multipart) MIME entity!
    $entity->dump_skeleton;          # for debugging 

Shortcuts:
    
    # Create a new parser object, and set some properties:
    my $parser = new MIME::Parser output_dir     => "$ENV{HOME}/mimemail",
                                  output_prefix  => "part",
                                  output_to_core => 20000;


=head1 DESCRIPTION

A subclass of MIME::ParserBase, providing one useful way to parse MIME
streams and obtain MIME::Entity objects.  This particular parser class
outputs the different parts as files on disk, in the directory of your
choice.

If you don't like the way files are named... it's object-oriented 
and subclassable.  If you want to do something I<really> different,
perhaps you want to subclass MIME::ParserBase instead.


=head1 PUBLIC INTERFACE

=over 4

=cut

#------------------------------

require 5.001;         # sorry, but I need the new FileHandle:: methods!

# Pragmas:
use strict;
use vars (qw(@ISA $VERSION));

# Built-in modules:
use Carp;
use FileHandle ();
				
# Kit modules:
use MIME::ParserBase;
use MIME::ToolUtils qw(:config :msgs);
use MIME::Head;
use MIME::Body;
use MIME::Entity;
use MIME::Decoder;

# Inheritance:
@ISA = qw(MIME::ParserBase);


#------------------------------
#
# Globals
#
#------------------------------

# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4.102 $, 10;

# Count of fake filenames generated:
my $G_output_path = 0;



#------------------------------
#
# PUBLIC INTERFACE
#
#------------------------------

#------------------------------

=item init PARAMHASM

Initiallize a new MIME::Parser object.  This is automatically sent to
a new object; the PARAMHASH can contain the following...

=over 4

=item output_dir

The value is passed to L<output_dir()>.

=item output_prefix

The value is passed to L<output_prefix()>.

=item output_to_core

The value is passed to L<output_to_core()>.

=back

For example:

   $p = new MIME::Parser output_dir => "/tmp/mime",
                         output_to_core => 'ALL';

=cut

sub init {
    my $self = shift;
    my %params = @_;

    # Inherited:
    $self->MIME::ParserBase::init(@_);      # parent's init
    $self->{MP_Prefix} = 'msg';

    # Handle our stuff:
    my $m;
    foreach $m (qw(output_dir output_prefix output_to_core)) {
	$self->$m($params{$m}) if (defined($params{$m}));
    }
    $self; 
}

#------------------------------

=item evil_filename FILENAME

I<Instance method.>
Is this an evil filename?  It is if it contains any C<"/"> characters,
or if it's C<".">, C<"..">, or empty.

Override this method in a subclass if you just want to change which 
externally-provided filenames are allowed, and which are not.  Like this:

     package MIME::MyParser;
     
     use MIME::Parser;
     @ISA = qw(MIME::Parser);
     
     sub evil_filename {
         my ($self, $name) = @_;
         return ($name !~ /^[a-z\d][a-z\d\._-]*$/i);   # only simple names ok
     }

B<Note:> This method used to be a lot stricter, but it unnecessailry
inconvenienced users on non-ASCII systems.  That has been changed in 4.x.

I<Thanks to Andrew Pimlott for finding a real dumb bug in the original
version.  Thanks to Nickolay Saukh for noting that evil is in the 
eye of the beholder.>

=cut

sub evil_filename {
    my ($self, $name) = @_;
    return (!defined($name) or ($name eq '') or ($name =~ m{/|^(\.+)\Z}));
}

#------------------------------

=item new_body_for HEAD

I<Instance method.>
Based on the HEAD of a part we are parsing, return a new
body object (any desirable subclass of MIME::Body) for
receiving that part's data.

The default behavior is to examine the HEAD for a recommended
filename (generating a random one if none is available), 
and create a new MIME::Body::File on that filename in 
the parser's current C<output_dir()>.

If you use the C<output_to_core> method (q.v.) before parsing, 
you can force this method to output some or all or a message's 
parts to in-core data structures, based on their size.

If you want the parser to do something else entirely, you should 
override this method in a subclass.

=cut

sub new_body_for {
    my ($self, $head) = @_;

    # Get the path to the output file, defaulting to DEPRECATED hook function:
    my $outpath = ($self->{MP_OutPathHook} 
		   ? &{$self->{MP_OutPathHook}}($self,$head) 
		   : $self->output_path($head));

    # If the message is short, write it to an in-core scalar.
    # Otherwise, write it to a disk file.
    # Note that, at this point, we haven't begun decoding the part
    # yet, so our knowledge is limited to the "Content-length" field.

    # Get the content length:
    my $contlen = $head->get('Content-length',0);
    defined($contlen) and $contlen = sprintf("%d", $contlen);

    # If known and small and desired, output to core: else, output to file:
    my $incore;
    my $cutoff = $self->output_to_core;
    if    ($cutoff eq 'NONE') { $incore = 0 }    # everything to files!
    elsif ($cutoff eq 'ALL')  { $incore = 1 }    # everything to core!
    else {                                       # cutoff names the cutoff!
	$incore = (defined($contlen) && ($contlen <= $cutoff));
    }

    # Return:
    if ($incore) {
	debug "outputting body to core";
	return (new MIME::Body::Scalar);
    }
    else {
	debug "outputting body to disk file";
	return (new MIME::Body::File $outpath);
    }
}

#------------------------------

=item output_dir [DIRECTORY]

I<Instance method.>
Get/set the output directory for the parsing operation.
This is the directory where the extracted and decoded body parts will go.
The default is C<".">.

If C<DIRECTORY> I<is not> given, the current output directory is returned.
If C<DIRECTORY> I<is> given, the output directory is set to the new value,
and the previous value is returned.

B<Note:> this is used by the C<output_path()> method in this class.
It should also be used by subclasses, but if a subclass decides to 
output parts in some completely different manner, this method may 
of course be completely ignored.

=cut

sub output_dir {
    my ($self, $dir) = @_;

    if (@_ > 1) {     # arg given...
	$dir = '.' if (!defined($dir) || ($dir eq ''));   # coerce empty to "."
	$dir = '/.' if ($dir eq '/');   # coerce "/" so "$dir/$filename" works
	$dir =~ s|/$||;                 # be nice: get rid of any trailing "/"
	$self->{MP_Dir} = $dir;
    }
    $self->{MP_Dir};
}

#------------------------------

=item output_path HEAD

I<Instance method.>
Given a MIME head for a file to be extracted, come up with a good
output pathname for the extracted file.

The "directory" portion of the returned path will be the C<output_dir()>, 
and the "filename" portion will be determined as follows:

=over 4

=item *

If the MIME header contains a recommended filename, and it is
I<not> judged to be "evil" (evil filenames are ones which contain
things like "/" or ".." or non-ASCII characters), then that 
filename will be used.

=item *

If the MIME header contains a recommended filename, but it I<is>
judged to be "evil", then a warning is issued and we pretend that
there was no recommended filename.  In which case...

=item *

If the MIME header does not specify a recommended filename, then
a simple temporary file name, starting with the C<output_prefix()>, 
will be used.

=back

B<Note:> If you don't like the behavior of this function, you 
can define your own subclass of MIME::Parser and override it there:

     package MIME::MyParser;
     
     require 5.002;                # for SUPER
     use package MIME::Parser;
     
     @MIME::MyParser::ISA = ('MIME::Parser');
     
     sub output_path {
         my ($self, $head) = @_;
         
         # Your code here; FOR EXAMPLE...
         if (i_have_a_preference) {
	     return my_custom_path;
         }
	 else {                      # return the default path:
             return $self->SUPER::output_path($head);
         }
     }
     1;

B<Note:> Nickolay Saukh pointed out that, given the subjective nature of
what is "evil", this function really shouldn't I<warn> about an evil
filename, but maybe just issue a I<debug> message.  I considered that, 
but then I thought: if debugging were off, people wouldn't know why 
(or even if) a given filename had been ignored.  In mail robots
that depend on externally-provided filenames, this could cause 
hard-to-diagnose problems.  So, the message is still a warning, but 
now B<it's only output if $^W is true.>

I<Thanks to Laurent Amon for pointing out problems with the original
implementation, and for making some good suggestions.  Thanks also to
Achim Bohnet for pointing out that there should be a hookless, OO way of 
overriding the output_path.>

=cut

sub output_path {
    my ($self, $head) = @_;

    # Get the output filename:
    my $outname = $head->recommended_filename;
    if (defined($outname) && $self->evil_filename($outname)) {
	whine "Provided filename '$outname' is regarded as evil by\n",
	      "this parser... I'm ignoring it and supplying my own.";
	$outname = undef;
    }
    if (!defined($outname)) {      # evil or missing; make our OWN filename:
	debug "no filename recommended: synthesizing our own";
	++$G_output_path;
	$head->print(\*STDERR) if ($CONFIG{DEBUGGING});
	$outname = ($self->output_prefix . "-$$-$G_output_path.doc");
    }
    
    # Compose the full path from the output directory and filename:
    my $outdir = $self->output_dir;
    $outdir = '.' if (!defined($outdir) || ($outdir eq ''));  # just to be safe
    return "$outdir/$outname";  
}

#------------------------------
#
# output_path_hook SUBREF
# 
# Instance method: DEPRECATED.
# Install a different function to generate the output filename
# for extracted message data.
#
sub output_path_hook {
    my ($self, $subr) = @_;
    usage "deprecated ages ago, and soon to be removed: STOP USING IT.";
    $self->{MP_OutPathHook} = $subr;
}

#------------------------------

=item output_prefix [PREFIX]

I<Instance method.>
Get/set the output prefix for the parsing operation.
This is a short string that all filenames for extracted and decoded 
body parts will begin with.  The default is F<"msg">.

If C<PREFIX> I<is not> given, the current output prefix is returned.
If C<PREFIX> I<is> given, the output directory is set to the new value,
and the previous value is returned.

=cut

sub output_prefix {
    my ($self, $prefix) = @_;
    $self->{MP_Prefix} = $prefix if (@_ > 1);
    $self->{MP_Prefix};
}


#------------------------------

=item output_to_core [CUTOFF]

I<Instance method.>
Normally, instances of this class output all their decoded body
data to disk files (via MIME::Body::File).  However, you can change 
this behaviour by invoking this method before parsing:

B<If CUTOFF is an integer,> then we examine the C<Content-length> of 
each entity being parsed.  If the content-length is known to be
CUTOFF or below, the body data will go to an in-core data structure;
If the content-length is unknown or if it exceeds CUTOFF, then
the body data will go to a disk file.

B<If the CUTOFF is the string "NONE",> then all body data goes to disk 
files regardless of the content-length.  This is the default behaviour.

B<If the CUTOFF is the string "ALL",> then all body data goes to 
in-core data structures regardless of the content-length.  
B<This is very risky> (what if someone emails you an MPEG or a tar 
file, hmmm?) but people seem to want this bit of noose-shaped rope,
so I'm providing it.

Without argument, returns the current cutoff: "ALL", "NONE" (the default), 
or a number.

See the C<new_body_for()> method for more details.

=cut

sub output_to_core {
    my ($self, $cutoff) = @_;
    $self->{MP_Cutoff} = $cutoff if (@_ > 1);
    return (defined($self->{MP_Cutoff}) ? uc($self->{MP_Cutoff}) : 'NONE');
}

#------------------------------
1;
__END__

=back

=head1 WRITING SUBCLASSES

Authors of subclasses can consider overriding the following methods.
They are listed in approximate order of most-to-least impact.

=over 4

=item new_body_for

Override this if you want to change the I<entire> mechanism for choosing 
the output destination.  You may want to use information in the MIME
header to determine how files are named, and whether or not their data
goes to a disk file or to an in-core scalar.
(You have the MIME header object at your disposal.)

=item output_path

Override this if you want to completely change how the output path
(containing both the directory and filename) is determined for those
parts being output to disk files.  
(You have the MIME header object at your disposal.)

=item evil_filename

Override this if you want to change the test that determines whether
or not a filename obtained from the header is permissible.

=item output_prefix

Override this if you want to change the mechanism for getting/setting
the desired output prefix (used in naming files when no other names
are suggested).

=item output_dir

Override this if you want to change the mechanism for getting/setting
the desired output directory (where extracted and decoded files are placed).

=back


=head1 AUTHOR

Copyright (c) 1997 by Eryq / eryq@zeegee.com

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 4.102 $ $Date: 1997/12/14 03:04:10 $

=cut

#------------------------------
1;



