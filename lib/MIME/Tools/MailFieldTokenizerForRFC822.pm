package MIME::Tools::MailFieldTokenizerForRFC822;

my $TYPE = 0;
my $TEXT = 1;

my $NULL = [NULL=>""];

my $TSPECIAL = q{\(\)\<\>\@,;:\\\"\.\[\]};
my $CTL      = q{\000-\037,\177};


sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub tokenize {
    my ($self, $string) = @_;

    local $_ = $string;
    s{\n}{ }g;
    my @tokens;
    while (1) {

	### End?
	m{\G\Z}gc and do { 
	    last; 
	};

	### Whitespace?
	m{\G(\s+)}gc and do {
	    push @tokens, [SPACE=>$1];
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
	     push @tokens, [COMMENT=>$1];
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
	      push @tokens, [QUOTED=>$1];
	      next;
	  };

	### Special?
	m{\G([$TSPECIAL])}osgcx and do { 
	      push @tokens, [SPECIAL=>$1];
	      next;
	 };

	### Atom?
	m{\G([^ \s $CTL $TSPECIAL ]+)}osgcx and do { 
	      push @tokens, [ATOM=>$1];
	      next;
	 };
	
	### Oops.
        die("syntax error in string\n" .
            "\t$_\n" .
            ("\t".(" " x pos($_))."^\n"));
    }
    return @tokens;
}

sub list_tokens  {
    my ($self, @tokens) = @_;
    return join("", map { sprintf "  %-10s %s\n", $_->[$TYPE], $_->[$TEXT] } @tokens);
} 

sub join_tokens  {
    my ($self, @tokens) = @_;
    my @canon;
    my ($token, $last_token) = ($NULL,$NULL);

    ### Filter out comments:
    @tokens = grep {$_->[$TYPE] ne 'COMMENT'} @tokens; 

    ### Collapse remaining runs of whitespace:
    my @t;
    foreach (@tokens) {
	if (($_->[$TYPE] eq 'SPACE') and @t and ($t[-1]->[$TYPE] eq 'SPACE')) {
	    ### skip
	}
	else {
	    push @t, $_;
	}
    }
    @tokens = @t;

    ### Go through remaining:
    while (@tokens) {
	$token = shift @tokens;
	if ($token->[$TYPE] eq 'SPACE') {
	    my $a = $last_token;
	    my $b = $tokens[$TYPE] || $NULL;
	    if    (($a->[$TYPE] eq 'SPECIAL') and ($a->[$TEXT] =~ /[\@\.]/) and ($b->[$TYPE] =~ /^(ATOM|QUOTED)$/)) {}
	    elsif (($b->[$TYPE] eq 'SPECIAL') and ($b->[$TEXT] =~ /[\@\.]/) and ($a->[$TYPE] =~ /^(ATOM|QUOTED)$/)) {}
	    else { push @canon, " "; }
	}
	elsif ($token->[$TYPE] eq 'COMMENT') {
	    ### skip
	}
	else {
	    push @canon, $token->[$TEXT];
	}
	
    } continue {
	$last_token = $token;
    }
    join '', @canon;
}

### Strip comments, collapse whitespace as appropriate:
sub canonicalize {
    my ($self, $string) = @_;
    $self->join_tokens($self->tokenize($string));
}

{
  package main; no strict; local $^W = 0;
  eval join('',<main::DATA>) || die "$@ $main::DATA" unless caller();
}
1;           # end the module
__END__

=pod


        So, for example, the folded body of an address field

            ":sysmail"@  Some-Group. Some-Org,
            Muhammed.(I am  the greatest) Ali @(the)Vegas.WBA

        is analyzed into the following lexical symbols and types:

                    :sysmail              quoted string
                    @                     special
                    Some-Group            atom
                    .                     special
                    Some-Org              atom
                    ,                     special
                    Muhammed              atom
                    .                     special
                    (I am  the greatest)  comment
                    Ali                   atom
                    @                     atom
                    (the)                 comment
                    Vegas                 atom
                    .                     special
                    WBA                   atom

        The canonical representations for the data in these  addresses
        are the following strings:

                        ":sysmail"@Some-Group.Some-Org

        and

                            Muhammed.Ali@Vegas.WBA



=cut

BEGIN { unshift @INC, ".", "./etc", "./lib" };
use MIME::Tools;
import MIME::Tools::MailFieldTokenizerForRFC822;
print "MIME-tools version = $MIME::Tools::VERSION\n";
$^W = 1;

my $string1 = <<EOF;
         ":sysmail"@  Some-Group. Some-Org,
            Muhammed.(I am  the greatest) Ali @(the)Vegas.WBA
EOF
my $string2 = "text/html; charset=us-ascii; name = (regrettably) sober[1].txt";

my $tok = new MIME::Tools::MailFieldTokenizerForRFC822;
foreach my $s ($string1, $string2) {
    print "-------\n";

    print "Original:  $s\n\n";

    print "Canonical: ";
    print $tok->canonicalize($s), "\n\n";

    print "Tokens: $s\n";
    print $tok->list_tokens($tok->tokenize($s)), "\n";

}

1;
