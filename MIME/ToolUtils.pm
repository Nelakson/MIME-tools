package MIME::ToolUtils;

=head1 NAME

MIME::ToolUtils - MIME-tools kit configuration and utilities


=head1 DESCRIPTION

A catch-all place for miscellaneous global information related to 
the configuration of the MIME-tools kit.

Since most of the MIME-tools modules "use" it by name,  this module 
is really not subclassable.


=head1 PUBLIC INTERFACE

=over 4

=cut

#------------------------------------------------------------

require Exporter;

use FileHandle;
use Carp;

use Mail::Header;

use vars (qw(@ISA %CONFIG @EXPORT_OK %EXPORT_TAGS $VERSION));
use strict;

@ISA = qw(Exporter);

# Exporting (importing should only be done by modules in this toolkit!):
%EXPORT_TAGS = (
    'config' => [qw(%CONFIG)],
    'msgs'   => [qw(usage debug error)],
    'utils'  => [qw(tmpopen)],	
    );
Exporter::export_ok_tags('config', 'msgs', 'utils');


#------------------------------
#
# Globals
#
#------------------------------ 

# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 3.203 $, 10;

# Configuration (do NOT alter this directly):
%CONFIG = 
    (
     DEBUGGING       => 0,
     EMULATE_TMPFILE => 'OPENDUP',
     EMULATE_VERSION => $VERSION,
     VERSION         => $VERSION,        # toolkit version as well
     );

# Unsettable:
my %NOCONFIG  = (VERSION => 1);

# Use methods to set (yes, I could do this from the symbol table...):
my %SUBCONFIG = (EMULATE_VERSION => 1);



#------------------------------
#
# Private globals...
#
#------------------------------

# Warnings?
my %AlreadySaid = ();




#------------------------------
#
# Configuration...
#
#------------------------------

#------------------------------------------------------------
# config
#------------------------------------------------------------

=item config [VARIABLE, [VALUE]]

I<Class method.>
Set/get a configuration variable:

    # Get current debugging flag:
    $current = config MIME::ToolUtils 'DEBUGGING';
    
    # Invert it:
    config MIME::ToolUtils DEBUGGING => !$current;

I<Note:> as you can see, I like the `arrow' syntax when setting values.

The complete list of configuration variables is listed below.  They
are all-uppercase, possibly with underscores.  To get a list of all
valid config variables in your program, and output their current values,
you can say:

    foreach $var (sort (config MIME::ToolUtils)) {
       print "MIME config $var = ", (config MIME::ToolUtils $var), "\n";
    }

Note that some of these variables may have nice printed representations,
while others may not.

I<Rationale:> I wanted access to the configuration to be done via
some kind of controllable public interface, in case "setting a config
variable" involved making a subroutine call.  This approach is an attempt 
to do so while preventing an explosion of lots of little methods, many
of which will do nothing more than set an entry in the internal %CONFIG hash. 
I suppose a tied hash would have been slicker.

=cut

sub config {
    my $class = shift;

    # No args? Just return list:
    @_ or return keys %CONFIG; 
    my $var = uc(shift);
    my ($value) = (@_);

    # Trap for attempt to set an illegal or unsettable:
    exists($CONFIG{$var}) or croak "no such config variable: '$var'";
    croak "config variable $var is read-only!" if (@_ and $NOCONFIG{$var});
    
    # See if this variable is mapped to a method:
    my $methodname = "config_$var";
    if ($SUBCONFIG{$var}) {
	return $class->$methodname(@_);
    }
    else {    # just a flag
	$CONFIG{$var} = $value if (@_);    # set if necessary
	return $CONFIG{$var};
    }
}

#------------------------------------------------------------
# config_EMULATE_VERSION 
#------------------------------------------------------------
# Private support hook for config(EMULATE_VERSION).

sub config_EMULATE_VERSION {
    my $class = shift;
    if (@_) {         # setting value...
	my ($version) = @_;

	# Default to current:
	defined($version) or $version = $CONFIG{'VERSION'}; # current

	# Set emulation, and warn them:
	$CONFIG{EMULATE_VERSION} = $version;
	warn "EMULATING MIME-parser v.$version.  You have been warned!\n";

	# Do some immediate tweaks, if necessary:
	($version < 2.0) and Mail::Header->mail_from('COERCE');
    }
    $CONFIG{EMULATE_VERSION};       # return current value
}




#------------------------------
#
# Old-style configuration...
#
#------------------------------
# All of these still work, but have been deprecated with "config"
# variables of the same name.

#------------------------------------------------------------
# debugging
#------------------------------------------------------------
sub debugging {
    usage("deprecated: please use config() from now on");
    shift->config('DEBUGGING', @_);
}

#------------------------------------------------------------
# emulate_tmpfile
#------------------------------------------------------------
sub emulate_tmpfile {
    usage("deprecated: please use config() from now on");
    shift->config('EMULATE_TMPFILE', @_);
}

#------------------------------------------------------------
# emulate_version
#------------------------------------------------------------
sub emulate_version {
    usage("deprecated: please use config() from now on");
    shift->config('EMULATE_VERSION', @_);
}





#------------------------------
#
# Logging (private)...
#
#------------------------------

#------------------------------------------------------------
# debug -- private: register general unhappiness
#------------------------------------------------------------
sub debug { 
    print STDERR "DEBUG: ", @_, "\n"      if $CONFIG{DEBUGGING};
}

#------------------------------------------------------------
# error -- private: register general unhappiness
#------------------------------------------------------------
sub error { 
    my ( $p,  $f,  $l,  $s) = caller(1);
    my $msg = join('', (($s =~ /::/) ? "$s() " : "${p}::$s() "), @_, "\n");
    warn "$msg" if $^W;
    return (wantarray ? () : undef);
}

#------------------------------------------------------------
# usage -- private: register unhappiness about usage (once per)
#------------------------------------------------------------
sub usage { 
    my ( $p,  $f,  $l,  $s) = caller(1);
    my ($cp, $cf, $cl, $cs) = caller(2);
    my $msg = join('', (($s =~ /::/) ? "$s() " : "${p}::$s() "), @_, "\n");
    my $loc = ($cf ? "\tin code called from $cf l.$cl" : '');
    warn "$msg$loc\n" if ($^W and !$AlreadySaid{$msg});
    $AlreadySaid{$msg} = 1;
    return (wantarray ? () : undef);
}



#------------------------------
#
# Other utils (private)...
#
#------------------------------

#------------------------------------------------------------
# tmpopen_opendup
#------------------------------------------------------------
# Possible back end for tmpopen() (q.v.)
#
# This backend of tmpopen() is pretty ugly (two additional
# filehandles sharing the same descriptor are briefly open at one point), 
# but probably quite portable since it (a) doesn't require POSIX, 
# and (b) doesn't make assumptions as to the underlying implementation 
# of FileHandle objects.

sub tmpopen_opendup {
    my $err;

    # Open a new tmpfile object:
    my $buggyFH = FileHandle->new_tmpfile || die "tmpfile: $!";

    # Open a symbolic file handle with the same fd as the tmpfile:
    if (!(open(BUGGY, ("+>&=".fileno($buggyFH))))) {
	$err = "$!"; close $buggyFH;           # cleanup in case die is caught
	die "couldn't open BUGGY: $err";
    }

    # Open a tmpfile, dup'ing the symbolic filehandle:
    my $tempFH = FileHandle->new("+>&MIME::ToolUtils::BUGGY");
    $err = "$!"; close BUGGY; close $buggyFH;  # cleanup in case die is caught
    $tempFH or die "couldn't dup BUGGY: $err";
    
    # We're ready!
    binmode($tempFH);
    return $tempFH;
}

#------------------------------------------------------------
# tmpopen_unlink
#------------------------------------------------------------
# Possible back end for tmpopen() (q.v.)
# Uses a Unix-y construct.

sub tmpopen_unlink {
    my $nam;
    require POSIX;     # only if we need it!

    # Open a new file:
    my $fh = new FileHandle;	
    ($fh->open(($nam = POSIX::tmpnam()), (O_CREAT|O_RDWR|O_EXCL), 0600))
	or die "open: $!";
    
    # Unlink file from the filesystem, and do other setup:
    unlink $nam or die "unlink: $!";  # we now have a true tmpfile!
    binmode($fh);    # standard for tmpfiles
    return $fh;
}

#------------------------------------------------------------
# tmpopen
#------------------------------------------------------------
# Return a FileHandle object which really WILL be destroyed when
# it goes out of scope.  In other words, this does what 
# FileHandle->new_tmpfile in Perl5.002 should do, but doesn't.  
# Uses a CONFIG option "EMULATE_TMPFILE" which selects the emulation method.

sub tmpopen {
    my $emulation      = $CONFIG{'EMULATE_TMPFILE'};
    my $need_to_emulate = 1;     # best guess for now is "always"
    my $fh;

    # If emulation is forbidden, or 
    # if emulation is optional and we don't NEED to do it, 
    # then don't do it:
    if (($emulation eq 'NO') || 
	(($emulation !~ /\!$/) and !$need_to_emulate)) {
	return FileHandle->new_tmpfile;
    }
    
    # Emulate!
    (ref($emulation) eq 'CODE') and return &$emulation();
    ($emulation =~ /^OPENDUP/) and return tmpopen_opendup();
    ($emulation =~ /^UNLINK/)  and return tmpopen_unlink();
    die "Yow! No support for tmpfile emulation option <$emulation>!";
}

#------------------------------------------------------------

=back

=head1 CONFIGURATION VARIABLES

You may set/get all of these via the C<config> method.

=over 4


=item AUTO_SYNC_HEADERS

When printing out a MIME entity, you may find it desirable to always
output a Content-Length header (even though this is a non-standard 
MIME header).  If you set this configuration option true (the default
is false), the toolkit will attempt to precompute the Content-Length
of all singleparts in your message, and set the headers appropriately. 
Otherwise, it will leave the headers alone.

You should be aware that auto-synching the headers can slow down
the printing of messages.



=item DEBUGGING

Value should be a boolean: true to turn debugging on, false to turn it off.



=item EMULATE_TMPFILE

Determines how to patch a Perl 5.002 bug in FileHandle::new_tmpfile, 
and get a FileHandle object which really I<will> be destroyed when it 
goes out of scope.  Possible values are:

=over 4

=item OPENDUP

Always emulate FileHandle->new_tmpfile, using an fd-opened duplicate 
filehandle.  Pretty ugly (two additional filehandles sharing the same 
descriptor are briefly open at one point, though both are closed before
the new tmpfile object is returned): however, it's probably quite portable 
since it (a) doesn't require POSIX, and (b) doesn't make assumptions as 
to the underlying implementation of FileHandle objects.

=item UNLINK   

Always emulate FileHandle->new_tmpfile, using tmpnam() plus unlink().
Probably only works on Unix-like systems, but is very straightforward.
Depends on POSIX::tmpnam() and on the autodelete-on-unlink behavior. 

=item NO

No emulation: always just use FileHandle->new_tmpfile to get tmpfile
handles.

=item (a subroutine reference)

Use the given subroutine, with no arguments, to return a tmpfile.

=back

If any of the named emulation options ends with '!' (e.g., "UNLINK!"),
then the package will I<always> emulate that way.  Otherwise, it will 
try to make a reasonable guess as to whether emulation is necessary,
based on your version of Perl.

The default setting (if you never invoke this method) is C<"OPENDUP">.



=item EMULATE_VERSION

Emulate the behavior of a previous version of the MIME-tools kit (a.k.a
the MIME-parser kit in its version 1.x incarnations).
This will I<not> turn off warnings about deprecated usage (that would
impede progress), but it I<will> patch things like the C<get()> method
of MIME::Head:

    config MIME::ToolUtils EMULATE_VERSION => 1.0;

The value should be '1' or '1.0'.  To reliably turn off emulation,
set it to undef.



=item VERSION

I<Read-only.>  The version of the I<toolkit.>

    config MIME::ToolUtils VERSION => 1.0;

Please notice that as of 3.x, this I<happens> to be the same as the
$MIME::ToolUtils::VERSION: however, this was not always the case, and
someday may not be the case again.

=back





=head1 AUTHOR

Copyright (c) 1996 by Eryq / eryq@rhine.gsfc.nasa.gov  

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 3.203 $ $Date: 1997/01/19 07:40:14 $

I<Note: this file is used to set the version of the entire MIME-tools 
distribution.>

=cut




#------------------------------------------------------------
1;
  
