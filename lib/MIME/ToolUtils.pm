package MIME::ToolUtils;


=head1 NAME

MIME::ToolUtils - MIME-tools kit configuration and utilities


=head1 SYNOPSIS

    # Get current debugging flag, and invert it:
    $current = config MIME::ToolUtils 'DEBUGGING';
    config MIME::ToolUtils DEBUGGING => !$current;


=head1 DESCRIPTION

A catch-all place for miscellaneous global information related to 
the configuration of the MIME-tools kit.

Since most of the MIME-tools modules "use" it by name,  this module 
is really not subclassable.


=head1 PUBLIC INTERFACE

=over 4

=cut

#------------------------------

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
    'msgs'   => [qw(usage debug whine error)],
    'utils'  => [qw(textual_type tmpopen shellquote)],	
    );
Exporter::export_ok_tags('config', 'msgs', 'utils');


#------------------------------
#
# Globals
#
#------------------------------ 

# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4.103 $, 10;

# Configuration (do NOT alter this directly)...
# All legal CONFIG vars *must* be in here, even if only to be set to undef:
%CONFIG = 
    (
     DEBUGGING       => 0,
     EMULATE_TMPFILE => 'IGNORED',
     EMULATE_VERSION => $VERSION,
     QUIET           => 1,
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

#------------------------------

=item config [VARIABLE, [VALUE]]

I<Class method.>
Set/get a configuration variable:

    # Get current debugging flag:
    $current = config MIME::ToolUtils 'DEBUGGING';
    
    # Invert it:
    config MIME::ToolUtils DEBUGGING => !$current;

The complete list of configuration variables is listed below.  They are 
all-uppercase, possibly with underscores.  To get a list of all valid config 
variables in your program, and output their current values, you can say:

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

#------------------------------
#
# config_EMULATE_VERSION 
#
# Private support hook for config(EMULATE_VERSION).
#
sub config_EMULATE_VERSION {
    my $class = shift;
    if (@_) {         # setting value...
	my ($version) = @_;

	# Default to current:
	defined($version) or $version = $CONFIG{'VERSION'}; # current

	# Do some immediate tweaks, if necessary:
	($version < 2.0) and die "can no longer emulate v.1; sorry!";

	# Set emulation, and warn them:
	$CONFIG{EMULATE_VERSION} = $version;
	warn "WARNING: emulating old MIME-parser v.$version!\n" if $^W;
    }
    $CONFIG{EMULATE_VERSION};       # return current value
}





#------------------------------
#
# OLD-STYLE CONFIGURATION...
#
#------------------------------
# All of these still work, but have been deprecated with "config"
# variables of the same name.

sub debugging {
    usage("deprecated: please use config() from now on");
    shift->config('DEBUGGING', @_);
}

sub emulate_tmpfile {
    usage("deprecated: this option no longer does anything");
}

sub emulate_version {
    usage("deprecated: please use config() from now on");
    shift->config('EMULATE_VERSION', @_);
}



#------------------------------
#
# MESSAGES...
#
#------------------------------


#------------------------------
#
# debug MESSAGE...
#
# Private: output a debug message.
#
sub debug { 
    print STDERR "DEBUG: ", @_, "\n"      if $CONFIG{DEBUGGING};
}

#------------------------------
#
# whine MESSAGE...
#
# Private: issue a warning, but only if $^W (-w) is true, and
# we're not being QUIET.
#
sub whine { 
    my ( $p,  $f,  $l,  $s) = caller(1);
    my $msg = join('', (($s =~ /::/) ? "$s(): " : "${p}::$s(): "), @_, "\n");
    warn $msg if ($^W && !$CONFIG{QUIET});
    return (wantarray ? () : undef);
}

#------------------------------
#
# error MESSAGE...
#
# Private: something failed; register general unhappiness.
#
sub error { 
    my ( $p,  $f,  $l,  $s) = caller(1);
    my $msg = join('', (($s =~ /::/) ? "$s(): " : "${p}::$s(): "), @_, "\n");
    warn $msg if $^W;
    return (wantarray ? () : undef);
}

#------------------------------
#
# usage MESSAGE...
#
# Register unhappiness about usage (once per).
#
sub usage { 
    my ( $p,  $f,  $l,  $s) = caller(1);
    my ($cp, $cf, $cl, $cs) = caller(2);
    my $msg = join('', (($s =~ /::/) ? "$s() " : "${p}::$s() "), @_, "\n");
    my $loc = ($cf ? "\tin code called from $cf l.$cl" : '');
    warn "$msg$loc\n" if ($^W && !$CONFIG{QUIET} && !$AlreadySaid{$msg});
    $AlreadySaid{$msg} = 1;
    return (wantarray ? () : undef);
}




#------------------------------
#
# UTILS...
#
#------------------------------


#------------------------------
#
# shellquote STRING
#
# Private utility: make string safe for shell.
#
sub shellquote {
    my $str = shift;
    $str =~ s/\$/\\\$/g;
    $str =~ s/\`/\\`/g;
    $str =~ s/\"/\\"/g;
    return "\"$str\"";        # wrap in double-quotes
}

#------------------------------
#
# textual_type MIMETYPE
#
# Function.  Does the given MIME type indicate a textlike document?
#
sub textual_type {
    ($_[0] =~ m{^(text|message)(/|\Z)}i);
}

#------------------------------
#
# tmpopen
#
# Private: open a temporary file.
# If we predate 5.004, assume that new_tmpfile is broken, and use 
# tmpopen_opendup().
#
sub tmpopen { 
    (($] >= 5.004) ? FileHandle->new_tmpfile : tmpopen_opendup());
}

#------------------------------
#
# tmpopen_opendup
#
# Private: possible back end for tmpopen() (q.v.)
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



#------------------------------

=back

=head1 CONFIGURATION VARIABLES

You may set/get all of these via the C<config> method.

=over 4

=item DEBUGGING

Value should be a boolean: true to turn debugging on, false to turn it off.

=item EMULATE_TMPFILE

I<Obsolete.>  Prior to our 4.x release, this determined how to patch a 
Perl 5.004 bug in FileHandle::new_tmpfile, and get a FileHandle object 
which really I<will> be destroyed when it goes out of scope.  The
bug has been corrected in 5.004, so this option (and much of the bulky code 
which supported it) was removed; pre-5.004 installations will use
the "opendup" emulation, which has been hardcoded.

=item EMULATE_VERSION

Emulate the behavior of a previous version of the MIME-tools kit (a.k.a
the MIME-parser kit in its version 1.x incarnations). Since 1.x emulation
was turned off in 4.x, this doesn't really do anything currently.

=item QUIET

Most of the warnings from this toolkit may be silenced if you set
QUIET true.  The default is false.

=item VERSION

I<Read-only.>  The version of the I<toolkit.>

    config MIME::ToolUtils VERSION => 1.0;

Please notice that as of 3.x, this I<happens> to be the same as the
$MIME::ToolUtils::VERSION: however, this was not always the case, and
someday may not be the case again.

=back



=head1 AUTHOR

Copyright (c) 1996, 1997 by Eryq / eryq@zeegee.com

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.


=head1 VERSION

$Revision: 4.103 $ $Date: 1998/05/01 19:52:15 $

I<Note: this file is used to set the version of the entire MIME-tools 
distribution.>

=cut


#------------------------------
1;
  
