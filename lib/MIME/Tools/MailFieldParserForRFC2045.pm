package MIME::Tools::MailFieldTokenizerForRFC2045;


=head1 NAME

MIME::Tools::MailFieldTokenizerForRFC2045 - as it says


=head1 SYNOPSIS

B<The MIME::Tools::* modules are for MIME::Tools internal consumption only.>
The modules and their interfaces may change radically from version to version.


    $mfp = new MIME::Tools::MailFieldParser;
    %hash = $mfp->parse_to_hash;




=head1 DESCRIPTION

A parser for structured fields.


=cut

use strict;
use MIME::Tools::MailFieldTokenizerForRFC2045 qw(:all);

use Data::Dumper;

### Special tokens.
### We recast these to no longer be TSPECIALs, since MIMEdefang thinks
### we need to handle [intentionally] bad MIME headers which violate
### RFC2045, like this:
###
###       Content-type: text/html; name=myfile[1].txt
###
### Techincally, this is illegal: values must either be quoted strings
### or single atoms.  However, it's pretty clear what happening here,
### and since we want to "allow garbage in", we tolerate the bogus tokens.
### The question is whether we want to handle:
###
###       Content-type: text/html; name=/home/Jane Doe/profile.txt
###
### I almost think we do, which means that whitespace may become an
### issue again.  Regression tests are clearly needed here.
###
my $TT_SEMI = 'SEMI';
my $TC_SEMI = $TC_NULL->ref->new($TT_SEMI, ";");
###
my $TT_EQUAL = 'EQUAL';
my $TC_EQUAL = $TC_NULL->ref->new($TT_EQUAL, "=");

#------------------------------
# Class method, constructor.
#
sub new {
    my ($class) = @_;
    bless {}, $class;
}

#------------------------------
# Instance method.
# Parse a string.
#
sub parse_to_hash {
    my ($self, $string) = @_;

    ### Tokenize:
    my $mft = new MIME::Tools::MailFieldTokenizerForRFC2045;
    my @tokens = $mft->tokenize($string);

    ### Skip whitespace and comments:
    @tokens = grep {
	not($_->is($TT_SPACE)) and not($_->is($TT_COMMENT));
    } @tokens;

    ### Map TSPECIAL(;) and TSPECIAL(=) to their own tokens:
    @tokens = map {
	if    ($_->is($TT_SPECIAL, ';')) { $_ = $TC_SEMI; }
	elsif ($_->is($TT_SPECIAL, '=')) { $_ = $TC_EQUAL; }
	$_;
    } @tokens;
    $self->{Tokens} = \@tokens;

    ### Parse:
    my %hash = $self->nt_FIELD;
}

#------------------------------
# Instance method.
# Get a token if it matches the given criteria.
# Returns the token, or undef if there is no next token of if the
# next token doesn't match.  You *can* use this to "get" TC_NULL.
#
sub t_get {
    my ($self, $type, $text) = @_;

    ### Peek and test:
    my $token = $self->{Tokens}[0] || $TC_NULL;   ### peek
    return undef if defined($type) && $token->[$TF_TYPE] eq $type;
    return undef if defined($text) && $token->[$TF_TEXT] ne $text;

    ### It's good:
    shift @{$self->{Tokens}};
    return $self->{LastToken} = $token;
}

#------------------------------
# Instance method.
# Unget the last token.
#
sub t_unget {
    my ($self) = @_;
    my $token = $self->{LastToken};
    defined($token) or return 1;   ### nothing to do

    unshift @{$self->{Tokens}}, $token   unless $token->[$TF_TYPE] eq $TT_NULL;
    $self->{LastToken} = undef;
    1;
}

1;
__END__

BEGIN { unshift @INC, ".", "./etc", "./lib" };
use MIME::Tools;

import MIME::Tools::MailFieldParserForRFC2045;
print "MIME-tools version = $MIME::Tools::VERSION\n";
$^W = 1;

my $string1 = "text/html; charset=us-ascii; name = (regrettably) sober[1].txt";

my $p = new MIME::Tools::MailFieldParserForRFC2045;
foreach my $s ($string1) {
    print "-------\n";
}

1;
