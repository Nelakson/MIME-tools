package MIME::Parser::Reader;

=head1 NAME

MIME::Parser::Reader - a line-oriented reader for a MIME::Parser

=head1 DESCRIPTION

A line-oriented reader which can deal with virtual end-of-stream
defined by a collection of boundaries. 

B<Warning:> this is a private class solely for use by MIME::Parser.
This class has no official public interface

=cut

use strict;
use IO::ScalarArray;

### All possible end-of-line sequences.
### Note that "" is included because last line of stream may have no newline!
my @EOLs = ("", "\r", "\n", "\r\n", "\n\r");

### Long line:
my $LONGLINE = ' ' x 1000;


#------------------------------
#
# new
#
# Construct an empty (top-level) reader.
#
sub new {
    my ($class) = @_;
    my $eos;
    return bless {
	Bounds => [],
	BH     => {},
	TH     => {},
	EOS    => \$eos,
    }, $class;
}

#------------------------------
#
# spawn
#
# Return a reader which is mostly a duplicate, except that the EOS 
# accumulator is shared.
#
sub spawn {
    my $self = shift;
    my $dup = bless {}, ref($self);
    $dup->{Bounds} = [ @{$self->{Bounds}} ];  ### deep copy
    $dup->{BH}     = { %{$self->{BH}} };      ### deep copy
    $dup->{TH}     = { %{$self->{TH}} };      ### deep copy
    $dup->{EOS}    = $self->{EOS};            ### shallow copy; same ref!
    $dup;
}

#------------------------------
#
# add_boundary BOUND
#
# Let BOUND be the new innermost boundary.  Returns self.
#
sub add_boundary {
    my ($self, $bound) = @_;
    unshift @{$self->{Bounds}}, $bound;   ### now at index 0
    $self->{BH}{"--$bound"}   = "DELIM $bound";
    $self->{BH}{"--$bound--"} = "CLOSE $bound";
    $self;
}

#------------------------------
#
# add_terminator LINE
#
# Let LINE be another terminator.  Returns self.
#
sub add_terminator {
    my ($self, $line) = @_;
    foreach (@EOLs) {
	$self->{TH}{"$line$_"} = "DONE $line";
    }
    $self;
}

#------------------------------
#
# has_bounds
#
# Are there boundaries to contend with?
#
sub has_bounds {
    scalar(@{shift->{Bounds}});
}

#------------------------------
#
# depth
#
# How many levels are there? 
#
sub depth {
    scalar(@{shift->{Bounds}});
}

#------------------------------
#
# eos [EOS]
#
# Return the last end-of-stream token seen.
# See read_chunk() for what these might be.
#
sub eos {
    my $self = shift;
    ${$self->{EOS}} = $_[0] if @_;
    ${$self->{EOS}};
}

#------------------------------
#
# eos_type [EOSTOKEN]
#
# Return the high-level type of the given token (defaults to our token).
#
#    DELIM       saw an innermost boundary like --xyz
#    CLOSE       saw an innermost boundary like --xyz-- 
#    DONE        callback returned false
#    EOF         end of file
#    EXT         saw boundary of some higher-level
#
sub eos_type {
    my ($self, $eos) = @_;
    $eos = $self->eos if (@_ == 1);

    if    ($eos =~ /^(DONE|EOF)/) {
	return $1;
    }
    elsif ($eos =~ /^(DELIM|CLOSE) (.*)$/) {
	return (($2 eq $self->{Bounds}[0]) ? $1 : 'EXT');
    }
    else {
	die("internal error: unable to classify boundary token ($eos)");
    }
}

#------------------------------
#
# native_handle HANDLE
#
# Can we do native i/o on HANDLE?  If true, returns the handle
# that will respond to native I/O calls; else, returns undef.
#
sub native_handle {
    my $fh = shift;
    return $fh  if $fh->isa('IO::File');
    return $$fh if ($fh->isa('IO::Wrap') && (ref($$fh) eq 'GLOB'));
    undef;
}

#------------------------------
#
# read_chunk INHANDLE, OUTHANDLE
#
# Get lines until end-of-stream.
# Returns the terminating-condition token:
#
#    DELIM xyz   saw boundary line "--xyz"
#    CLOSE xyz   saw boundary line "--xyz--"
#    DONE xyz    saw terminator line "xyz"
#    EOF         end of file
#
sub read_chunk {
    my ($self, $in, $out) = @_;
    
    ### Init:
    my %bh = %{$self->{BH}};
    my %th = %{$self->{TH}}; my $thx = keys %th;
    local $_ = $LONGLINE;
    my $maybe;
    my $last = '';
    my $eos  = '';
    
    ### Determine types:
    my $n_in  = native_handle($in);
    my $n_out = native_handle($out);

    ### Handle efficiently by type:
    if ($n_in) {
	if ($n_out) {            ### native input, native output [fastest]
	    while (<$n_in>) {
		if (substr($_, 0, 2) eq '--') {
		    ($maybe = $_) =~ s/[ \t\r\n]+\Z//;
		    $bh{$maybe} and do { $eos = $bh{$maybe}; last };
		}
		$thx and $th{$_} and do { $eos = $th{$_}; last };
		print $n_out $last; $last = $_; 
	    }
	}
	else {                   ### native input, OO output [slower]
	    while (<$n_in>) { 
		if (substr($_, 0, 2) eq '--') {
		    ($maybe = $_) =~ s/[ \t\r\n]+\Z//;
		    $bh{$maybe} and do { $eos = $bh{$maybe}; last };
		}
		$thx and $th{$_} and do { $eos = $th{$_}; last };
		$out->print($last); $last = $_; 
	    }
	}
    }
    else {
	if ($n_out) {            ### OO input, native output [even slower]
	    while (defined($_ = $in->getline)) { 
		if (substr($_, 0, 2) eq '--') {
		    ($maybe = $_) =~ s/[ \t\r\n]+\Z//;
		    $bh{$maybe} and do { $eos = $bh{$maybe}; last };
		}
		$thx and $th{$_} and do { $eos = $th{$_}; last };
		print $n_out $last; $last = $_;  
	    }
	}
	else {                   ### OO input, OO output [slowest]
	    while (defined($_ = $in->getline)) { 
		if (substr($_, 0, 2) eq '--') {
		    ($maybe = $_) =~ s/[ \t\r\n]+\Z//;
		    $bh{$maybe} and do { $eos = $bh{$maybe}; last };
		}
		$thx and $th{$_} and do { $eos = $th{$_}; last };
		$out->print($last); $last = $_; 
	    }
	}
    }
    
    ### Write out last held line, removing terminating CRLF if ended on bound:
    $last =~ s/[\r\n]+\Z// if ($eos =~ /^(DELIM|CLOSE)/);
    $out->print($last);

    ### Save and return what we finished on:
    ${$self->{EOS}} = ($eos || 'EOF');
    1;
}

#------------------------------
#
# read_lines INHANDLE, \@OUTLINES
#
# Read lines into the given array.
# 
sub read_lines {
    my ($self, $in, $outlines) = @_;
    $self->read_chunk($in, IO::ScalarArray->new($outlines));
    shift @$outlines if ($outlines->[0] eq '');   ### leading empty line
    1;
}

1;
__END__


