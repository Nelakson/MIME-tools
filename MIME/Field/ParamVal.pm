package MIME::Field::ParamVal;

=head1 NAME

MIME::Field::ParamVal - subclass of Mail::Field, for structured MIME fields

=head1 DESCRIPTION

This is an abstract superclass of most MIME fields.  It handles 
fields with a general syntax like this:

    Content-Type: Message/Partial;
        number=2; total=3;
        id="oc=jpbe0M2Yt4s@thumper.bellcore.com"

Comments are supported I<between> items, like this:

    Content-Type: Message/Partial; (a comment)
        number=2  (another comment) ; (yet another comment) total=3;
        id="oc=jpbe0M2Yt4s@thumper.bellcore.com"

=head1 PUBLIC INTERFACE

=over

=cut

#------------------------------------------------------------

require 5.001;

# Pragmas:
use strict;
use vars qw($VERSION @ISA);

# System modules:
use Carp;

# Other modules:
use Mail::Field;

# Kit modules:
use MIME::ToolUtils qw(:config :msgs);

@ISA = qw(Mail::Field);


#------------------------------
#
# Public globals...
#
#------------------------------

# The package version, both in 1.23 style *and* usable by MakeMaker:
( $VERSION ) = '$Revision: 1.5 $ ' =~ /\$Revision:\s+([^\s]+)/;


#------------------------------
#
# Private globals...
#
#------------------------------

# Pattern to match parameter names (like fieldnames, but = not allowed):
my $PARAMNAME = '[^\x00-\x1f\x80-\xff :=]+';

# Pattern to match the first value on the line:
my $FIRST    = '[^\s\;\x00-\x1f\x80-\xff]+';

# Pattern to match an RFC-1521 token:
#
#      token      =  1*<any  (ASCII) CHAR except SPACE, CTLs, or tspecials>
#
my $TSPECIAL = '()<>@,;:\</[]?="';
my $TOKEN    = '[^ \x00-\x1f\x80-\xff' . "\Q$TSPECIAL\E" . ']+';

# Pattern to match spaces or comments:
my $SPCZ     = '(?:\s|\([^\)]*\))*';


#------------------------------
#
# Class init...
#
#------------------------------

#------------------------------------------------------------
# set
#------------------------------------------------------------

=item set [\%PARAMHASH | KEY=>VAL,...,KEY=>VAL]

Set this field.
The paramhash should contain parameter names
in I<all lowercase>, with the special C<"_"> parameter name
signifying the "default" (unnamed) parameter for the field:

   # Set up to be...
   #
   #     Content-type: Message/Partial; number=2; total=3; id="ocj=pbe0M2"
   #
   $conttype->set('_'       => 'Message/Partial',
		  'number'  => 2,
		  'total'   => 3,
		  'id'      => "ocj=pbe0M2");

Note that a single argument is taken to be a I<reference> to 
a paramhash, while multiple args are taken to be the elements
of the paramhash themselves.

Supplying undef for a hashref, or an empty set of values, effectively
clears the object.

The self object is returned.

=cut

sub set {
    my $self = shift;
    my $params = ((@_ == 1) ? (shift || {}) : {@_});
    %$self = %$params;    # set 'em
    $self;
}

#------------------------------------------------------------
# parse_params
#------------------------------------------------------------

=item parse_params STRING

I<Class/instance utility method.>
Extract parameter info from a structured field, and return
it as a hash reference.  For example, here is a field with parameters:

    Content-Type: Message/Partial;
        number=2; total=3;
        id="oc=jpbe0M2Yt4s@thumper.bellcore.com"

Here is how you'd extract them:

    $params = $class->parse_params('content-type');
    if ($$params{'_'} eq 'message/partial') {
        $number = $$params{'number'};
        $total  = $$params{'total'};
        $id     = $$params{'id'};
    }

Like field names, parameter names are coerced to lowercase.
The special '_' parameter means the default parameter for the
field.

B<NOTE:> This has been provided as a public method to support backwards
compatibility, but you probably shouldn't use it.

=cut

sub parse_params {
    my ($self, $raw) = @_;
    my %params = ();
    my $param;

    # Get raw field, and unfold it:
    $raw =~ s/\n//g;

    # Extract special first parameter:
    $raw =~ m/\A$SPCZ($FIRST)$SPCZ/og or return {};    # nada!
    $params{'_'} = $1;

    # Extract subsequent parameters.
    # No, we can't just "split" on semicolons: they're legal in quoted strings!
    while (1) {                     # keep chopping away until done...
	$raw =~ m/$SPCZ\;$SPCZ/og or last;             # skip leading separator
	$raw =~ m/($PARAMNAME)\s*=\s*/og or last;      # give up if not a param
	$param = lc($1);
	$raw =~ m/(\"([^\"]+)\")|($TOKEN)/g or last;   # give up if no value
	$params{$param} = defined($1) ? $2 : $3;
	# debug "   field param <$param> = <$params{$param}>";
    }

    # Done:
    \%params;
}

#------------------------------------------------------------
# parse 
#------------------------------------------------------------

=item parse STRING

Parse the string into the instance.  Any previous information is wiped.

The self object is returned.

=cut

sub parse {
    my ($self, $string) = @_;
    
    # Get params, and stuff them into the self object:
    $self->set($self->parse_params($string));
}

#------------------------------------------------------------
# param
#------------------------------------------------------------

=item param PARAMNAME,[VALUE]

Return the given parameter, or undef if it isn't there.
With argument, set the parameter to that VALUE.
The PARAMNAME is case-insensitive.  A "_" refers to the "default" parameter.

=cut

sub param {
    my ($self, $paramname, $value) = @_;
    $paramname = lc($paramname);
    $self->{$paramname} = $value if (@_ > 2);
    $self->{$paramname}
}

#------------------------------------------------------------
# stringify
#------------------------------------------------------------

=item stringify

Convert the field to a string, and return it.

=cut

sub stringify {
    my $self = shift;
    my ($key, $val);
    my $str = '';
    foreach $key (sort keys %$self) {
	next if ($key !~ /^[a-z-_0-9]+$/);     # only lowercase ones!
	$val = $self->{$key};
	if ($key eq '_') {             # don't quote it
	    ## note... this was: if (($key eq '_') || ($val =~ /\A$TOKEN\Z/))
	    $str .= qq{; $key=$val};
	}
	else {                         # quote it
	    $str .= qq{; $key="$val"};
	}
    }
    $str =~ s/^; _=//;    # :-)
    $str;
}

#------------------------------------------------------------
# tag
#------------------------------------------------------------

=item tag

Return the tag for this field.  Abstract!

=cut

sub tag { '' }

=back

=cut

#------------------------------------------------------------
1;



