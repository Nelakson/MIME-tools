package MIME::Parser::Filer;

=head1 NAME

MIME::Parser::Filer - manage file-output of the parser


=head1 SYNOPSIS

Before reading further, you should see L<MIME::Parser> to make sure that 
you understand where this module fits into the grand scheme of things.
Go on, do it now.  I'll wait.

Ready?  Ok...


=head2 Public interface

    ### Create a "filer" of the desired class:
    my $filer = MIME::Parser::FileInto->new($dir);
    my $filer = MIME::Parser::FileUnder->new($basedir);
    ...
     
    ### Want added security?  Don't let outsiders name your files:
    $filer->ignore_filename(1); 
     
    ### Prepare for the parsing of a new top-level message:     
    $filer->init_parse;
     
    ### Return the path where this message's data should be placed:
    $path = $filer->output_path($head);


=head2 Semi-public interface

These methods might be overriden or ignored in some subclasses, 
so they don't all make sense in all circumstances:

    ### Tweak the mapping from content-type to extension:
    $emap = $filer->output_extension_map;
    $emap->{"text/html"} = ".htm";


=head2 Using with MIME::Parser objects

    $parser->filer($filer); 



=head1 DESCRIPTION

When a MIME::Parser decides that it wants to output a file to disk,
it uses its "Filer" object -- an instance of a MIME::Parser::Filer 
subclass -- to determine where to put the file.  There are two 
standard "Filer" subclasses (see below).  To implement your own custom
behavior, however, you may want to author your own Filer subclass.
The only method you have to override is L<output_path()|/output_path>:

    $filer->output_path($head);

This method is invoked by MIME::Parser when it wants to put a 
decoded message body in an output file.  The method should return a 
path to the file to create.  Failure is indicated by throwing an 
exception.

The path returned by C<output_path()> should be "ready for open()":
any necessary parent directories need to exist at that point.
These directories can be created by the Filer, if course.

Actually, if your issue is more I<where> the files go than
what they're named, you can use the default L<output_path()|/output_path>
method and just override one of its components:

    $dir  = $filer->output_dir($head);
    $name = $filer->output_filename($head);
    ...


=head1 PUBLIC INTERFACE


=head2 MIME::Parser::Filer

This is the abstract superclass of all "filer" objects.

=over 4

=cut

use strict;

### Kit modules:
use MIME::Tools qw(:msgtypes);
use File::Spec;

### Output path uniquifiers:
my $GFileNo = 0;
my $GSubdirNo = 0;

### Map content-type to extension.
### If we can't map "major/minor", we try "major/*", then use "*/*".
my %DefaultTypeToExt = 
qw(

application/andrew-inset	.ez
application/octet-stream	.bin
application/oda			.oda
application/pdf			.pdf
application/pgp			.pgp
application/postscript		.ps
application/rtf			.rtf
application/x-bcpio		.bcpio
application/x-chess-pgn		.pgn
application/x-cpio		.cpio
application/x-csh		.csh
application/x-dvi		.dvi
application/x-gtar		.gtar
application/x-gunzip		.gz
application/x-hdf		.hdf
application/x-latex		.latex
application/x-mif		.mif
application/x-netcdf		.cdf
application/x-netcdf		.nc
application/x-sh		.sh
application/x-shar		.shar
application/x-sv4cpio		.sv4cpio
application/x-sv4crc		.sv4crc
application/x-tar		.tar
application/x-tcl		.tcl
application/x-tex		.tex
application/x-texinfo		.texi
application/x-troff		.roff
application/x-troff		.tr
application/x-troff-man		.man
application/x-troff-me		.me
application/x-troff-ms		.ms
application/x-ustar		.ustar
application/x-wais-source	.src
application/zip			.zip

audio/basic			.snd
audio/ulaw			.au
audio/x-aiff			.aiff
audio/x-wav			.wav

image/gif			.gif
image/ief			.ief
image/jpeg			.jpg
image/png                       .png
image/xbm                       .xbm
image/tiff			.tif
image/x-cmu-raster		.ras
image/x-portable-anymap		.pnm
image/x-portable-bitmap		.pbm
image/x-portable-graymap	.pgm
image/x-portable-pixmap		.ppm
image/x-rgb			.rgb
image/x-xbitmap			.xbm
image/x-xpixmap			.xpm
image/x-xwindowdump		.xwd

text/*                          .txt
text/html			.html
text/plain			.txt
text/richtext			.rtx
text/tab-separated-values	.tsv
text/x-setext			.etx
text/x-vcard                    .vcf

video/mpeg			.mpg
video/quicktime			.mov
video/x-msvideo			.avi
video/x-sgi-movie		.movie

message/*                       .msg

*/*                             .dat

);
	      

#------------------------------

=item new INITARGS...

I<Class method, constructor.>
Create a new outputter for the given parser.
Any subsequent arguments are given to init(), which subclasses should
override for their own use (the default init does nothing).

=cut

sub new {
    my ($class, @initargs) = @_;
    my $self = bless {
	MPF_Prefix => "msg",
	MPF_Dir    => ".",
	MPF_Ext    => { %DefaultTypeToExt },
    }, $class;
    $self->init(@initargs);
    $self;
}

sub init {
    ### no-op
}

#------------------------------
#
# cleanup_dir
#
# Instance method, private.
# Cleanup a directory, defaulting empty to "."
#
sub cleanup_dir {
    my ($self, $dir) = @_;
    $dir = '.' if (!defined($dir) || ($dir eq ''));   # coerce empty to "."
    $dir = '/.' if ($dir eq '/');   # coerce "/" so "$dir/$filename" works
    $dir =~ s|/$||;                 # be nice: get rid of any trailing "/"
    $dir;
}

#------------------------------

=item results RESULTS

I<Instance method.>
Link this filer to a MIME::Parser::Results object which will 
tally the messages.  Notice that we avoid linking it to the 
parser to avoid circular reference!

=cut

sub results {
    my ($self, $results) = @_;
    $self->{MPF_Results} = $results if (@_ > 1);
    $self->{MPF_Results};
}

### Log debug messages:
sub debug {
    my $self = shift;
    if ($self->{MPF_Results}) {
	unshift @_, $self->{MPF_Results}->indent;
	$self->{MPF_Results}->msg($M_DEBUG, @_);
    }
    MIME::Tools::debug(@_);
}

### Log warning messages:
sub whine {
    my $self = shift;
    if ($self->{MPF_Results}) {
	unshift @_, $self->{MPF_Results}->indent;
	$self->{MPF_Results}->msg($M_WARNING, @_);
    }
    MIME::Tools::whine(@_);
}

#------------------------------

=item init_parse

I<Instance method.>
Prepare to start parsing a new message.
Default does nothing.

=cut

sub init_parse {
    my $self = shift;
}

#------------------------------

=item evil_filename FILENAME

I<Instance method.>
Is this an evil filename; i.e., one which should not be used
in generating a disk file name?  It is if any of these are true:

    * it is empty
    * it is a string of dots: ".", "..", etc.
    * it contains a known "path" character: '/' '\' ':' '[' ']'

If you just want to change this behavior, you should override 
this method in the subclass of MIME::Parser::Filer that you use.

B<Note:> subclasses of MIME::Parser::Filer which override 
output_path() might not consult this method; note, however, that
the built-in subclasses do consult it.

B<Note:> This method used to be a lot stricter, but it unnecessailry
inconvenienced users on non-ASCII systems. 

I<Thanks to Andrew Pimlott for finding a real dumb bug in the original
version.  Thanks to Nickolay Saukh for noting that evil is in the 
eye of the beholder.>

=cut

sub evil_filename {
    my ($self, $name) = @_;

    $self->debug("is this evil? '$name'");

    return 1 if (!defined($name) or ($name eq ''));   ### empty
    return 1 if ($name =~ m{^\.+\Z});         ### dots
    return 1 if ($name =~ tr{\\/:[]}{});      ### path characters
    $self->debug("it's ok");
    0;
}

#------------------------------

=item ignore_filename [YESNO]

I<Instance method.>
Return true if we should always ignore recommended filenames in
messages, choosing instead to always generate our own filenames.  
With argument, sets this value.

B<Note:> subclasses of MIME::Parser::Filer which override 
output_path() might not honor this setting; note, however, that
the built-in subclasses honor it.

=cut

sub ignore_filename {
    my $self = shift;
    $self->{MPF_IgnoreFilename} = $_[0] if @_;
    $self->{MPF_IgnoreFilename};
}

#------------------------------

=item output_dir HEAD

I<Instance method.>
Return the output directory for the given header.
The default method returns ".".

=cut

sub output_dir {
    my ($self, $head) = @_;
    return ".";
}

#------------------------------

=item output_filename HEAD

I<Instance method, subclasses only.>
A given recommended filename was either not given, or it was judged
to be evil.  Return a fake name, possibly using information in the 
message HEADer.  Note that this is just the filename, not the full path.

Used by L<output_path()|/output_path>.
If you're using the default C<output_path()>, you probably don't 
need to worry about avoiding collisions with existing files; 
we take care of that in L<find_unused_path()|/find_unused_path>.

=cut

sub output_filename {
    my ($self, $head) = @_;

    ### Get the recommended name:
    my $recommended = $head->recommended_filename;

    ### Get content type:
    my ($type, $subtype) = split m{/}, $head->mime_type; $subtype ||= '';

    ### Get recommended extension, being quite conservative:
    my $recommended_ext = (($recommended and ($recommended =~ m{(\.\w+)\Z}))
			   ? $1 
			   : undef);

    ### Try and get an extension, honoring a given one first:
    my $ext = ($recommended_ext ||
	       $self->{MPF_Ext}{"$type/$subtype"} ||
	       $self->{MPF_Ext}{"$type/*"} ||
	       $self->{MPF_Ext}{"*/*"} ||
	       ".dat");
    
    ### Get a prefix:
    ++$GFileNo;
    return ($self->output_prefix . "-$$-$GFileNo$ext");
}

#------------------------------

=item output_prefix [PREFIX]

I<Instance method.>
Get the short string that all filenames for extracted body-parts 
will begin with (assuming that there is no better "recommended filename").  
The default is F<"msg">.

If PREFIX I<is not> given, the current output prefix is returned.
If PREFIX I<is> given, the output prefix is set to the new value,
and the previous value is returned.

Used by L<output_filename()|/output_filename>.

B<Note:> subclasses of MIME::Parser::Filer which override 
output_path() or output_filename() might not honor this setting; 
note, however, that the built-in subclasses honor it.

=cut

sub output_prefix {
    my ($self, $prefix) = @_;
    $self->{MPF_Prefix} = $prefix if (@_ > 1);
    $self->{MPF_Prefix};
}

#------------------------------

=item output_type_ext 

I<Instance method.>
Return a reference to the hash used by the default 
L<output_filename()|/output_filename> for mapping from content-types 
to extensions when there is no default extension to use.

    $emap = $filer->output_typemap;
    $emap->{'text/plain'} = '.txt';
    $emap->{'text/html'}  = '.html';
    $emap->{'text/*'}     = '.txt';
    $emap->{'*/*'}        = '.dat';

B<Note:> subclasses of MIME::Parser::Filer which override 
output_path() or output_filename() might not consult this hash; 
note, however, that the built-in subclasses consult it.

=cut

sub output_type_ext  {
    my $self = shift;
    return $self->{MPF_Ext};
}

#------------------------------

=item output_path HEAD

I<Instance method, subclasses only.>
Given a MIME head for a file to be extracted, come up with a good
output pathname for the extracted file.  This is the only method
you need to worry about if you are building a custom filer.

The default implementation does a lot of work; subclass 
implementers I<really> should try to just override its components 
instead of the whole thing.  It works basically as follows:

    $directory = $self->output_dir($head);   
     
    $filename = $head->recommended_filename();
    if (!$filename or 
	 $self->ignore_filename() or 
	 $self->evil_filename($filename)) {
 	$filename = $self->output_filename($head);
    }
    
    return $self->find_unused_path($directory, $filename);

B<Note:> There are many, many, many ways you might want to control
the naming of files, based on your application.  If you don't like 
the behavior of this function, you can easily define your own subclass 
of MIME::Parser::Filer and override it there.

B<Note:> Nickolay Saukh pointed out that, given the subjective nature of
what is "evil", this function really shouldn't I<warn> about an evil
filename, but maybe just issue a I<debug> message.  I considered that, 
but then I thought: if debugging were off, people wouldn't know why 
(or even if) a given filename had been ignored.  In mail robots
that depend on externally-provided filenames, this could cause 
hard-to-diagnose problems.  So, the message is still a warning.

I<Thanks to Laurent Amon for pointing out problems with the original
implementation, and for making some good suggestions.  Thanks also to
Achim Bohnet for pointing out that there should be a hookless, OO way of 
overriding the output path.>

=cut

sub output_path {
    my ($self, $head) = @_;

    ### Get the output directory:
    my $dir = $self->output_dir($head);
    
    ### Get the output filename:
    my $fname = $head->recommended_filename;
    if    (!defined($fname)) {
	$self->debug("no filename recommended: synthesizing our own");
	$fname = $self->output_filename($head);
    }
    elsif ($self->ignore_filename) {
	$self->debug("ignoring all external filenames: synthesizing our own");
	$fname = $self->output_filename($head);
    }
    elsif ($self->evil_filename($fname)) {

	### Can we save it by just taking the last element?
	my $last = $fname; $last =~ s{^.*[/\\\[\]:]}{};
	if ($last and !$self->evil_filename($last)) {
	    $self->whine("Provided filename '$fname' is regarded as evil, ",
			 "but it looks like I can use the last path element.");
	    $fname = $last;
	}
	else {
	    $self->whine("Provided filename '$fname' is regarded as evil; ",
			 "I'm ignoring it and supplying my own.");
	    $fname = $self->output_filename($head);
	}
    }
    $self->debug("planning to use '$fname'");

    ### Resolve collisions and return final path:
    return $self->find_unused_path($dir, $fname);
}

#------------------------------

=item find_unused_path DIR, FILENAME

I<Instance method, subclasses only.>
We have decided on an output directory and tentative filename,
but there is a chance that it might already exist.  Keep
adding a numeric suffix "-1", "-2", etc. to the filename
until an unused path is found, and then return that path.

The suffix is actually added before the first "." in the filename
is there is one; for example:

    picture.gif       archive.tar.gz      readme
    picture-1.gif     archive-1.tar.gz    readme-1
    picture-2.gif     archive-2.tar.gz    readme-2
    ...               ...                 ...
    picture-10.gif
    ...

This can be a costly operation, and risky if you don't want files
renamed, so it is in your best interest to minimize situations
where these kinds of collisions occur.  Unfortunately, if
a multipart message gives all of its parts the same recommended
filename, and you are placing them all in the same directory,
this method might be unavoidable.

=cut

sub find_unused_path {
    my ($self, $dir, $fname) = @_;
    my $i = 0;
    while (1) {

	### Create suffixed name (from filename), and see if we can use it:
	my $suffix = ($i ? "-$i" : "");
	my $sname = $fname; $sname =~ s/^(.*?)(\.|\Z)/$1$suffix$2/;
	my $path = File::Spec->catfile($dir, $sname);
	if (! -e $path) {   ### it's good!
	    $i and $self->whine("collision with $fname in $dir: using $path");
	    return $path;
	}
	$self->debug("$path already taken");
    } continue { ++$i; }
}

=back

=cut


#------------------------------------------------------------

=head2 MIME::Parser::FileInto

This concrete subclass of MIME::Parser::Filer supports filing 
into a given directory.

=over 4

=cut

package MIME::Parser::FileInto;

use strict;
use vars qw(@ISA);
@ISA = qw(MIME::Parser::Filer);

#------------------------------

=item init DIRECTORY

I<Instance method, initiallizer.>
Set the directory where all files will go.

=cut

sub init {
    my ($self, $dir) = @_;
    $self->{MPFI_Dir} = $self->cleanup_dir($dir);
}

#------------------------------
#
# output_dir HEAD
#
# I<Instance method, concrete override.>
# Return the output directory where the files go.
#
sub output_dir {
    shift->{MPFI_Dir};
}

=back

=cut



#------------------------------------------------------------

=head2 MIME::Parser::FileUnder

This concrete subclass of MIME::Parser::Filer supports filing under 
a given directory, using one subdirectory per message, but with
all message parts in the same directory.

=over 4

=cut

package MIME::Parser::FileUnder;

use strict;
use vars qw(@ISA);
@ISA = qw(MIME::Parser::Filer);

#------------------------------

=item init BASEDIR, OPTSHASH...

I<Instance method, initiallizer.>
Set the base directory which will contain the message directories.
If used, then each parse of begins by creating a new subdirectory
of BASEDIR where the actual parts of the message are placed.  
OPTSHASH can contain the following:

=over 4

=item DirName

Explicitly set the name of the subdirectory which is created.
The default is to use the time, process id, and a sequence number,
but you might want a predictable directory.  

=item Purge

Automatically purge the contents of the directory (including all
subdirectories) before each parse.  This is really only needed if
using an explicit DirName, and is provided as a convenience only.
Currently we use the 1-arg form of File::Path::rmtree; you should
familiarize yourself with the caveats therein.

=back

The output_dir() will return the path to this message-specific directory 
until the next parse is begun, so you can do this:

    use File::Path;
     
    $parser->output_under("/tmp");
    $ent = eval { $parser->parse_open($msg); };   ### parse
    if (!$ent) {	 ### parse failed
	rmtree($parser->output_dir);
	die "parse failed: $@";
    } 
    else {               ### parse succeeded
	...do stuff...
    }

=cut

sub init {
    my ($self, $basedir, %opts) = @_;

    $self->{MPFU_Base}    = $self->cleanup_dir($basedir);
    $self->{MPFU_DirName} = $opts{DirName}; 
    $self->{MPFU_Purge}   = $opts{Purge}; 
}

#------------------------------
#
# init_parse
#
# I<Instance method, override.>
# Prepare to start parsing a new message.
#
sub init_parse {
    my $self = shift;

    ### Determine the subdirectory of ther base to use:
    my $subdir = (defined($self->{MPFU_DirName})
		  ?       $self->{MPFU_DirName}
		  :       ("msg-".scalar(time)."-$$-".$GSubdirNo++));
    $self->debug("subdir = $subdir");
    
    ### Determine full path to output directory:
    $self->{MPFU_Dir} = File::Spec->catfile($self->{MPFU_Base}, $subdir);

    ### Remove and re-create it:
    rmtree $self->output_dir if $self->{MPFU_Purge};
    (-d $self->output_dir) or
	mkdir $self->output_dir, 0700 or 
	    die "mkdir ".$self->output_dir.": $!\n";
    1;
}

#------------------------------
#
# output_dir HEAD
#
# I<Instance method, concrete override.>
# Return the output directory that we used for the last parse.
#
sub output_dir {
    shift->{MPFU_Dir};
}

=back

=cut

1;
__END__


=head1 AUTHOR

Eryq (F<eryq@zeegee.com>), ZeeGee Software Inc (F<http://www.zeegee.com>).

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 5.9 $

