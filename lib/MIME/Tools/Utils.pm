package MIME::Tools::Utils;


=head1 NAME

MIME::Tools::Utils - common utilities for the MIME::Tools toolkit


=head1 SYNOPSIS

B<The MIME::Tools::* modules are for MIME::Tools internal consumption only.>
The modules and their interfaces may change radically from version to version.
 


=cut



# Because the POD documenation is pretty extensive, it follows
# the __END__ statement below...

use strict;
use vars qw(@ISA %CONFIG @EXPORT_OK %EXPORT_TAGS $VERSION
	    $LOG $Tmpopen);

use Exporter;
use FileHandle;
use Carp;
use MIME::Tools qw($LOG %CONFIG);

@ISA = qw(Exporter);


#------------------------------
#
# GLOBALS...
#
#------------------------------

### Exporting (importing should only be done by modules in this toolkit!):
%EXPORT_TAGS = (
    'config'  => [],
    'msgs'    => [qw( 
		      usage_warning
		      usage_error 
		      internal_error
		      )],
    'utils'   => [qw( benchmark shellquote textual_type tmpopen )],
    );
Exporter::export_ok_tags('config', 'msgs', 'utils');

### The TOOLKIT version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 6.2 $, 10;



#------------------------------
#
# MESSAGES...
#
#------------------------------

#------------------------------
#
# usage_warning MESSAGE...
#
# Warn about unwise usage.
# Documented behavior is in MIME::Tools::diag.
#
sub usage_warning {
    return if !$^W or $CONFIG{QUIET};
    unshift @_, "MIME-tools: usage: ";
    goto &Carp::carp;
}

#------------------------------
#
# usage_error MESSAGE...
#
# Throw exception because of unsupported usage.
# Documented behavior is in MIME::Tools::diag.
#
sub usage_error {
    unshift @_, "MIME-tools: usage: ";
    goto &Carp::croak;
}

#------------------------------
#
# internal_error MESSAGE...
#
# Throw exception because of [fatal] internal logic error.
# Documented behavior is in MIME::Tools::diag.
#
sub internal_error {
    unshift @_, "MIME-tools: internal: ";
    goto &Carp::confess;
}



#------------------------------
#
# UTILS...
#
#------------------------------

#------------------------------
#
# benchmark CODE
#
# Private benchmarking utility.
#
sub benchmark(&) {
    my ($code) = @_;
    if (0) {
	eval "require Benchmark;";
	my $t0 = new Benchmark;
	&$code;
	my $t1 = new Benchmark;
	return timestr(timediff($t1, $t0));
    }
    else {
	&$code;
	return "";
    }
}

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
#
sub tmpopen {
    &$MIME::Tools::Tmpopen();  ### backcompat
}


#------------------------------
1;
__END__


