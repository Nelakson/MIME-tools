package MIME::Tools::MailFieldTokenizerForRFC2045;


=head1 NAME

MIME::Tools::MailFieldTokenizerForRFC2045 - as it says


=head1 SYNOPSIS

B<The MIME::Tools::* modules are for MIME::Tools internal consumption only.>
The modules and their interfaces may change radically from version to version.


    $mft = new MIME::Tools::MailFieldTokenizerForRFC2045;
    
    @tokens = $mft->tokenize($contents_of_mail_header_field);
    $listed = $mft->list_tokens(@tokens);
    $pretty = $mft->join_tokens(@tokens);
     
    $canon  = $mft->canonicalize($contents_of_mail_header_field);


=head1 DESCRIPTION

Methods for parsing and formatting mail header field tokens,
as per RFC-2045.  This is a modification of the RFC-822 syntax
and logic.


=cut


#============================================================

package MIME::Tools::MailFieldTokenizerForRFC2045;

use strict;
use base qw(Exporter);

our %EXPORT_TAGS = 
    ('types' => [qw(
		    $TT_NULL    
		    $TT_ATOM    
		    $TT_SPECIAL 
		    $TT_SPACE   
		    $TT_COMMENT 
		    $TT_QUOTED  
		    )],
     'fields'=> [qw(
		    $TF_TYPE
		    $TF_TEXT
		    )],
     'consts'=> [qw(
		    $TC_NULL
		    )],
     'all'   => [qw( types fields consts)],
     );
Exporter::export_ok_tags('types','fields','all');

### Token class:
my $TOKEN = 'MIME::Tools::MailFieldTokenizerForRFC2045::Token';

#------------------------------
# Globals, public

### Parts of a token, for direct access:
our $TF_TYPE = 0;
our $TF_TEXT = 1;

### Token types:
our $TT_NULL    = 'NULL';
our $TT_ATOM    = 'ATOM';
our $TT_SPECIAL = 'SPECIAL';
our $TT_SPACE   = 'SPACE';
our $TT_COMMENT = 'COMMENT';
our $TT_QUOTED  = 'QUOTED';

### Special null token:
our $TC_NULL = $TOKEN->new($TT_NULL, '');

#------------------------------
# Globals, private

### Regular expression fragments:
###    TSPECIAL is as per RFC-822, minus ".", plus "/" "?" "=":
###
my $TSPECIAL_CC = q{\(\)\<\>\@,;:\\\"\[\]/?=};     ### RFC-2045
my $ESPECIAL_CC = q(\(\)\<\>\@,;:\\\"\[\]\?=\./);  ### RFC-2047
my $CTL_CC      = q{\000-\037,\177};
my $ETOKEN_RE   = "[^\\s${CTL_CC}${ESPECIAL_CC}]+";
my $ETEXT_RE    = "[^\\s${CTL_CC}\?]*";

### Address elements which should not have whitespace around them:
my %AddrSep = ('@'=>1, '.'=>1);
my %AtomOrQuoted = ($TT_ATOM=>1, $TT_QUOTED=>1);

#------------------------------
# Class method, constructor.
#
sub new {
    my ($class) = @_;
    bless {
	RFC2047 => 1,    ### recognize =?..?..?= sequences as atoms
    }, $class;
}

#------------------------------
# Instance method.
# Tokenize a mail header field.
#
sub tokenize {
    my ($self, $string) = @_;

    local $_ = $string;
    my @tokens;
    while (1) {

	### End?
	m{\G\Z}sgc and do { 
	    last; 
	};

	### Whitespace?
	m{\G(\s+)}sgc and do {
	    push @tokens, $TOKEN->new($TT_SPACE=>$1);
	    next;
	};

	### RFC-2047 atom?
	m{\G(
	     =\?           ### begin encword
	     ($ETOKEN_RE)
	     \?           
	     ($ETOKEN_RE) 
	     \?           
	     ($ETEXT_RE)  
	     \?=           ### end encword
	)}sgcx and $self->{RFC2047} and do {
	    push @tokens, $TOKEN->new($TT_ATOM, $1, {
		Charset  => $2,
		Encoding => $3,
		Text     => $4,
	    });
	    next;
	};

	### Comment?
	m{\G(
	      \(             ### begin comment
	      (?:            ### zero or more of...
	          [^()\\\r]+   ###    ctext
	       |  \\ .         ### or quoted-pair 
	       |  \( [^\)]* \) ### or simple nested comment
	       )*
	      \)             ### end comment 
	 )}sgcx and do { 
	     push @tokens, $TOKEN->new($TT_COMMENT=>$1);
	     next;
	 };

	### Quoted string?
	m{\G(
	      \"             ### begin quoted
	      (?:            ### zero or more of...
	          [^"\\\r]+    ###    qtext
	       |  \\ .         ### or quoted-pair 
	       )*
	      \"             ### end quoted
	 )}sgcx and do { 
	      push @tokens, $TOKEN->new($TT_QUOTED=>$1);
	      next;
	  };

	### Special?
	m{\G([$TSPECIAL_CC])}osgcx and do { 
	      push @tokens, $TOKEN->new($TT_SPECIAL=>$1);
	      next;
	 };

	### Atom?
	m{\G([^ \s $CTL_CC $TSPECIAL_CC ]+)}osgcx and do { 
	      push @tokens, $TOKEN->new($TT_ATOM=>$1);
	      next;
	 };
	
	### Oops.
        die("syntax error in string\n" .
            "\t$_\n" .
            ("\t".(" " x pos($_))."^\n"));
    }
    return @tokens;
}

#------------------------------
# Instance method.
#
sub list_tokens  {
    my ($self, @tokens) = @_;
    return join("", map { sprintf "  %-10s %s\n", $_->[$TF_TYPE], $_->[$TF_TEXT] } @tokens);
} 

#------------------------------
# Instance method.
#
sub join_tokens  {
    my ($self, @tokens) = @_;
    my @canon;

    ### Filter out comments:
    @tokens = grep {$_->[$TF_TYPE] ne $TT_COMMENT} @tokens; 

    ### Collapse remaining runs of whitespace:
    my @t;
    foreach (@tokens) {
	if (($_->[$TF_TYPE] eq $TT_SPACE) 
	    and @t
	    and ($t[-1]->[$TF_TYPE] eq $TT_SPACE)) 
	{
	    ### skip
	}
	else {
	    push @t, $_;
	}
    }
    @tokens = @t;

    ### Go through remaining:
    for (my $i = 0; $i < @tokens; $i++) {
	my $token = $tokens[$i];
	
	if ($token->[$TF_TYPE] eq $TT_SPACE) {
	    my $prev = $tokens[$i-1] || $TC_NULL;
	    my $next = $tokens[$i+1] || $TC_NULL;

	    if    (($prev->[$TF_TEXT] =~ /[\.\@]\Z/) and
		   $AtomOrQuoted{$next->[$TF_TYPE]}) {
		### skip
	    }
	    elsif ($AtomOrQuoted{$prev->[$TF_TYPE]} and
		   ($next->[$TF_TEXT] =~ /\A[\.\@]/)) {
		### skip
	    }
	    else { 
		push @canon, " "; 
	    }
	}
	elsif ($token->[$TF_TYPE] eq $TT_COMMENT) {
	    ### skip
	}
	else {
	    push @canon, $token->[$TF_TEXT];
	}
	
    } 
    join '', @canon;
}

#------------------------------
# Instance method.
# Strip comments, collapse whitespace as appropriate:
#
sub canonicalize {
    my ($self, $string) = @_;
    $self->join_tokens($self->tokenize($string));
}

#------------------------------
# Unit test.
#
{
  package main; no strict; local $^W = 0;
  eval join('',<main::DATA>) || die "$@ $main::DATA" unless caller();
}

#============================================================

package MIME::Tools::MailFieldTokenizerForRFC2045::Token;

use strict;
import MIME::Tools::MailFieldTokenizerForRFC2045 qw(:all);

#------------------------------
sub new { 
    my ($class, $type, $text, $data) = @_;
    bless [$type, $text, $data], $class;     ### no checking: short and fast
}

#------------------------------
sub type {
    shift->[$TF_TYPE];
}

#------------------------------
sub text {
    shift->[$TF_TEXT];
}

#------------------------------
sub is {
    my ($self, $type, $text) = @_;
    return undef if ($self->[$TF_TYPE] ne $type);
    return undef if defined($text) && $self->[$TF_TEXT] ne $text;
    1;
}

#------------------------------
sub equals {
    my ($self, $other) = @_;
    return undef if !defined($other);
    return (($self->[$TF_TYPE] eq $other->[$TF_TYPE]) and
	    ($self->[$TF_TEXT] eq $other->[$TF_TEXT]));
}

1;           # end the module
__END__

BEGIN { unshift @INC, ".", "./etc", "./lib" };
use MIME::Tools;

import MIME::Tools::MailFieldTokenizerForRFC2045;
print "MIME-tools version = $MIME::Tools::VERSION\n";
$^W = 1;

my @s;
push @s, <<EOF;
         ":sysmail"@  Some-Group. Some-Org,
            Muhammed.(I am  the greatest) Ali @(the)Vegas.WBA
EOF
push @s, "text/html; charset=us-ascii; name = (regrettably) sober[1].txt";
push @s, " =?ISO-8859-1?Q?Patrik_F=E4ltstr=F6m?= <paf\@nada.kth.se>";
push @s, " (=?ISO-8859-1?Q?Patrik_F=E4ltstr=F6m?=) <paf\@nada.kth.se>";
  
my $tok = new MIME::Tools::MailFieldTokenizerForRFC2045;
foreach my $s (@s) {
    print "-------\n";

    print "Original:  $s\n\n";

    print "Canonical: ";
    print $tok->canonicalize($s), "\n\n";

    print "Tokens: $s\n";
    print $tok->list_tokens($tok->tokenize($s)), "\n";

}

1;
