package MIME::ParserConf;

=head1 NAME

MIME::ParserConf - MIME-parser configuration

=head1 DESCRIPTION

A catch-all place for miscellaneous global information related to 
the configuration of the MIME-parser kit.

=head1 PUBLIC INTERFACE

=over

=cut

#------------------------------------------------------------

require Exporter;
use Mail::Header;
use vars (qw(@ISA %CONFIG @EXPORT_OK));

@EXPORT_OK = qw(%CONFIG);
@ISA = qw(Exporter);

# Configuration:
%CONFIG = 
    (
     EMULATE_VERSION => 9999;
     );


#------------------------------
#
# Private globals...
#
#------------------------------

# Warnings?
my %AlreadySaid = ();



#------------------------------------------------------------
# emulate_version
#------------------------------------------------------------

=item emulate_version [VERSION]

I<Class method.>
Emulate MIME::Parser's behavior of a previoous version.
This will I<not> turn off warnings about deprecated usage (that would
be too dangerous), but it I<will> patch the C<get()> method:

    MIME::ParserConf->emulate_version(1.0)

The VERSION should be '1' or '1.0'.

=cut

sub emulate_version {
    shift if $_[0] =~ /::/;      # get rid of class
    my $version = shift;
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
    warn "$msg$loc" unless $AlreadySaid{$msg};   
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

$Revision: 1.1 $ $Date: 1996/10/05 04:50:29 $

=cut




#------------------------------------------------------------
1;
  
