package MIME::Parser;


=head1 NAME

MIME::Parser - split MIME mail into decoded components


=head1 SYNOPSIS

    use MIME::Parser;
    
    # Create a new parser object:
    my $parser = new MIME::Parser;
        
    # Set up output directory for files:
    $parser->output_dir("$ENV{HOME}/mimemail");
    
    # Set up the prefix for files with auto-generated names:
    $parser->output_prefix("part");
    
    # If content length is this or below, write to in-core scalar;
    # Else, write to a disk file (the default action):
    $parser->output_to_core(20000);
         
    # Parse an input stream:
    $entity = $parser->read(\*STDIN) or die "couldn't parse MIME stream";
    
    # Congratulations: you now have a (possibly multipart) MIME entity!
    $entity->dump_skeleton;          # for debugging 


=head1 DESCRIPTION

A subclass of MIME::ParserHead, providing one useful way to parse MIME
streams and obtain MIME::Entity objects.  This particular parser class
outputs the different parts as files on disk, in the directory of your
choice.

If you don't like the way files are named... it's object-oriented 
and subclassable.  If you want to do something I<really> different,
perhaps you want to subclass MIME::ParserBase instead.


=head1 WARNINGS

The organization of the C<output_path()> code changed in version 1.11
of this module.  If you are upgrading from a previous version, and
you use inheritance to override the C<output_path()> method, please
take a moment to familiarize yourself with the new code.  
Everything I<should> still work, but you never know...

=head1 PUBLIC INTERFACE

=over 4

=cut

#------------------------------------------------------------

require 5.001;         # sorry, but I need the new FileHandle:: methods!

# Pragmas:
use strict;
use vars (qw(@ISA $VERSION));

# Built-in modules:
use Carp;
use FileHandle ();
BEGIN {
require POSIX if ($] < 5.002);  # I dunno; supposedly, 5.001m needs this...
}
				
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
( $VERSION ) = '$Revision: 2.4 $ ' =~ /\$Revision:\s+([^\s]+)/;

# Count of fake filenames generated:
my $G_output_path = 0;



#------------------------------------------------------------
#
# PUBLIC INTERFACE
#
#------------------------------------------------------------

#------------------------------------------------------------
# init
#------------------------------------------------------------
# Init the object.

sub init {
    my $self = shift;
    $self->MIME::ParserBase::init(@_);      # parent's init
    $self->{MP_Prefix} = 'msg';
    $self;
}

#------------------------------------------------------------
# new_body_for
#------------------------------------------------------------

=item new_body_for HEAD

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


    # Get the path to the output file.
    #    If there's a hook function installed, use it:
    #    this is for backwards compatibility with MIME-parser 1.x:
    my $outpath;
    if ($self->{MP_OutputPathHook}) {
	$outpath = &{$self->{MP_OutputPathHook}}($self, $head);
    }
    else {
	$outpath = $self->output_path($head);
    }

    # If the message is short, write it to an in-core scalar.
    # Otherwise, write it to a disk file.
    # Note that, at this point, we haven't begun decoding the part
    # yet, so our knowledge is limited to the "Content-length" field.

    # Get the content length:
    my $contlen = $head->get('Content-length',0);
    defined($contlen) and $contlen = sprintf("%d", $contlen);

    # If known and small and desired, output to core: else, output to file:
    my $incore;
    my $cutoff = $self->output_to_core();
    if ($cutoff eq 'NONE') {           # everything to files!
	$incore = 0;
    }
    elsif ($cutoff eq 'ALL') {         # everything to core!
	$incore = 1;
    }
    else {                             # cutoff names the cutoff!
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

#------------------------------------------------------------
# output_to_core
#------------------------------------------------------------

=item output_to_core [CUTOFF]

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
    return (defined($self->{MP_Cutoff}) ? 
	    uc($self->{MP_Cutoff}) : 'NONE');
}

#------------------------------------------------------------
# output_dir
#------------------------------------------------------------

=item output_dir [DIRECTORY]

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

#------------------------------------------------------------
# evil_filename
#------------------------------------------------------------

=item evil_filename FILENAME

I<Instance method.>
Is this an evil filename?  It is if it contains path info or
non-ASCII characters.  Returns true or false.

B<Note:> Override this method in a subclass if you just want to change 
which externally-provided filenames are allowed, and which are not.

I<Thanks to Andrew Pimlott for finding a real dumb bug. :-)>

=cut

sub evil_filename {
    my ($self, $name) = @_;
    evil_name($name);
}

#------------------------------------------------------------
# evil_name (private; deprecated)
#------------------------------------------------------------
# Is this an evil filename?  It is if it contains path info or
# non-ASCII characters.  Provided for backwards-compatibility
# with version 1.x.

sub evil_name {
    my $name = shift;
    return 1 if (!defined($name) || ($name eq ''));
    return 1 if ($name =~ m|/|);                      # currently, '/' is evil
    return 1 if (($name eq '.') || ($name eq '..'));  # '.' and '..' are evil
    return 1 if ($name =~ /[\x00-\x1f\x80-\xff]/);    # non-ASCIIs are evil
    0;     # it's good!
}

#------------------------------------------------------------
# output_path
#------------------------------------------------------------

=item output_path HEAD

I<Instance method.>
Given a MIME head for a file to be extracted, come up with a good
output pathname for the extracted file.

The "directory" portion of the returned path will be the C<output_dir()>, 
and the "filename" portion will be determined as follows:

=over

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
	warn "Provided filename '$outname' is evil... I'm ignoring it\n";
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

#------------------------------------------------------------
# output_path_hook
#------------------------------------------------------------

=item output_path_hook SUBREF

I<Instance method: DEPRECATED.>
Install a different function to generate the output filename
for extracted message data.  Declare it like this:

    sub my_output_path_hook {
        my $parser = shift;   # this MIME::Parser
	my $head = shift;     # the MIME::Head for the current message

        # Your code here: it must return a path that can be 
        # open()ed for writing.  Remember that you can ask the
        # $parser about the output_dir, and you can ask the
        # $head about the recommended_filename!
    }

And install it immediately before parsing the input stream, like this:

    # Create a new parser object, and install my own output_path hook:
    my $parser = new MIME::Parser;
    $parser->output_path_hook(\&my_output_path_hook);
    
    # NOW we can parse an input stream:
    $entity = $parser->read(\*STDIN);

This method is intended for people who are squeamish about creating 
subclasses.  See the C<output_path()> documentation for a cleaner, 
OOish way to do this.

=cut

sub output_path_hook {
    my ($self, $subr) = @_;

    usage "deprecated: use subclassing to override output_path instead.";

    $self->{MP_OutputPathHook} = $subr if (@_ > 1);
    $self->{MP_OutputPathHook};
}

#------------------------------------------------------------
# output_prefix 
#------------------------------------------------------------

=item output_prefix [PREFIX]

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

#------------------------------------------------------------

=back

=head1 WRITING SUBCLASSES

Authors of subclasses can consider overriding the following methods.
They are listed in approximate order of most-to-least impact.

=over

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


=head1 SEE ALSO

MIME::Decoder,
MIME::Entity,
MIME::Head, 
MIME::Parser.


=head1 AUTHOR

Copyright (c) 1996 by Eryq / eryq@rhine.gsfc.nasa.gov

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 2.4 $ $Date: 1996/10/28 18:38:42 $

=cut



#------------------------------------------------------------
# Execute simple test if run as a script...
#------------------------------------------------------------
{ 
  package main; no strict;
  eval join('',<main::DATA>) || die "$@ $main::DATA" unless caller();
}
1;           # end the module
__END__

BEGIN {unshift @INC, ".", "./etc"}
MIME::ToolUtils->debugging(1);
$Counter = 0;
$^W = 1;

# simple_output_path -- sample hook function, for testing
sub simple_output_path {
    my ($parser, $head) = @_;

    # Get the output filename:
    ++$Counter;
    my $outname = "message-$Counter.dat";
    my $outdir = $parser->output_dir;
    "$outdir/$outname";  
}

$DIR = "./testout";
((-d $DIR) && (-w $DIR)) or die "no output directory $DIR";

my $parser = new MIME::Parser;
$parser->output_dir($DIR);
$parser->output_to_core(512);       # 512 bytes or less goes to core
$parser->parse_nested_messages('REPLACE');

# Uncomment me to see path hooks in action...
# $parser->output_path_hook(\&simple_output_path);

print "* Waiting for a MIME message from STDIN...\n";
my $entity = $parser->read(\*STDIN);
$entity or die "parse failed";

print "=" x 60, "\n";
$entity->dump_skeleton;
print "=" x 60, "\n\n";


#------------------------------------------------------------
1;
