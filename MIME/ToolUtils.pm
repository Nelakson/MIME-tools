package MIME::ToolUtils;

=head1 NAME

MIME::ToolUtils - MIME-tools kit configuration and utilities

=head1 DESCRIPTION

A catch-all place for miscellaneous global information related to 
the configuration of the MIME-tools kit.

=head1 PUBLIC INTERFACE

=over

=cut

#------------------------------------------------------------

require Exporter;
use Mail::Header;
use vars (qw(@ISA %CONFIG @EXPORT_OK %EXPORT_TAGS));
use strict;

@ISA = qw(Exporter);

# Exporting:
%EXPORT_TAGS = (
    'config' => [qw(%CONFIG)],
    'msgs'   => [qw(usage debug error)],
    );
Exporter::export_ok_tags('config', 'msgs');

# Configuration:
%CONFIG = 
    (
     DEBUGGING => 0,
     EMULATE_VERSION => 9999,
     );


#------------------------------
#
# Private globals...
#
#------------------------------

# Warnings?
my %AlreadySaid = ();



#------------------------------------------------------------
# debugging
#------------------------------------------------------------

=item debugging ONOFF

I<Class method.>
Turn debugging on (true) or off (false) for the entire MIME-tools
library.  Debug messages go to STDERR.

=cut

sub debugging {
    my ($class, $onoff) = @_;
    $CONFIG{DEBUGGING} = $onoff if defined($onoff);
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

#------------------------------------------------------------

=back

=head1 AUTHOR

Copyright (c) 1996 by Eryq / eryq@rhine.gsfc.nasa.gov  

All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.

=head1 VERSION

$Revision: 1.2 $ $Date: 1996/10/18 06:52:28 $

=cut




#------------------------------------------------------------
1;
  
