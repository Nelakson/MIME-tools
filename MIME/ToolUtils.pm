package MIME::ToolUtils;

=head1 NAME

MIME::ToolUtils - MIME-tools kit configuration and utilities

=head1 DESCRIPTION

A catch-all place for miscellaneous global information related to 
the configuration of the MIME-tools kit.

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
( $VERSION ) = '$Revision: 2.13 $ ' =~ /\$Revision:\s+([^\s]+)/;

# Configuration:
%CONFIG = 
    (
     DEBUGGING       => 0,
     EMULATE_VERSION => 9999,
     EMULATE_TMPFILE => 'OPENDUP',
     VERSION         => $VERSION,        # toolkit version as well
     );


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
# debugging
#------------------------------------------------------------

=item debugging [ONOFF]

I<Class method.>
Turn debugging on (if ONOFF is true) or off (if ONOFF is false) 
for the entire MIME-tools library.  Debug messages go to STDERR.

With no argument, this method just returns the current setting.

=cut

sub debugging {
    my ($class, $onoff) = @_;
    $CONFIG{DEBUGGING} = $onoff if (@_ > 1);
    $CONFIG{DEBUGGING};
}

#------------------------------------------------------------
# emulate_tmpfile
#------------------------------------------------------------

=item emulate_tmpfile [OPTION]

I<Class method.>
Determines how to patch a Perl 5.002 bug in FileHandle::new_tmpfile, 
and get a FileHandle object which really I<will> be destroyed when it 
goes out of scope.  Possible options are:

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

Use this subroutine.

=back

If any of the emulation options ends with '!' (e.g., "UNLINK!"),
then the package will I<always> emulate that way.  Otherwise, it will 
try to make a reasonable guess as to whether emulation is necessary,
based on your version of Perl.

The default setting (if you never invoke this method) is C<"OPENDUP">.

With no argument, this method just returns the current setting.

=cut

sub emulate_tmpfile {
    my ($class, $option) = @_;
    if (@_ > 1) {
	$CONFIG{EMULATE_TMPFILE} = $option;
    }
    $CONFIG{EMULATE_TMPFILE};
}

#------------------------------------------------------------
# emulate_version
#------------------------------------------------------------

=item emulate_version [VERSION]

I<Class method.>
Emulate the behavior of a previous version of the MIME-tools kit (a.k.a
the MIME-parser kit in its version 1.x incarnations).
This will I<not> turn off warnings about deprecated usage (that would
impede progress), but it I<will> patch things like the C<get()> method
of MIME::Head:

    MIME::ToolUtils->emulate_version(1.0)

The VERSION should be '1' or '1.0'.

With no argument, this method just returns the current setting.

=cut

sub emulate_version {
    my ($class, $version) = @_;
    if ($version) {

	# Set emulation, and warn them:
	$CONFIG{EMULATE_VERSION} = $version;
	warn "EMULATING MIME-parser v.$version.  You have been warned!\n";

	# Do some immediate tweaks, if necessary:
	if ($CONFIG{EMULATE_VERSION} < 2.0) {
	  Mail::Header->mail_from('COERCE');
	}
    }
    $CONFIG{EMULATE_VERSION};
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
    warn "$msg";
    return (wantarray ? () : undef);
}

#------------------------------------------------------------
# usage -- private: register unhappiness about usage
#------------------------------------------------------------
sub usage { 
    my ( $p,  $f,  $l,  $s) = caller(1);
    my ($cp, $cf, $cl, $cs) = caller(2);
    my $msg = join('', (($s =~ /::/) ? "$s() " : "${p}::$s() "), @_, "\n");
    my $loc = ($cf ? "\tin code called from $cf l.$cl" : '');
    warn "$msg$loc\n" unless $AlreadySaid{$msg};   
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

=head1 AUTHOR

Copyright (c) 1996 by Eryq / eryq@rhine.gsfc.nasa.gov  

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.

=head1 VERSION

$Revision: 2.13 $ $Date: 1997/01/13 01:37:53 $

I<Note: this file is used to set the version of the entire MIME-tools 
distribution.>

=cut




#------------------------------------------------------------
1;
  
