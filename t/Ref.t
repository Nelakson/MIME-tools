use lib "./t";

use MIME::Tools;
use File::Path;
use File::Basename;
use ExtUtils::TBone;
use Globby;

use strict;
config MIME::Tools DEBUGGING=>0;

use MIME::Parser;

my $T = typical ExtUtils::TBone;
#print STDERR "\n";

### Verify directory paths:
(-d "testout") or die "missing testout directory\n";
my $output_dir = $T->catdir(".", "testout", "Ref_t");

### Get messages to process:
my @refpaths = @ARGV;
if (!@refpaths) { 
    opendir DIR, "testmsgs" or die "opendir: $!\n";
    @refpaths = map { $T->catfile(".", "testmsgs", $_) 
		      } grep /\.ref$/, readdir(DIR);
    closedir DIR; 
}

### Create checker:
$T->begin(int(@refpaths));

### For each reference:
foreach my $refpath (@refpaths) {

    ### Get message:
    my $msgpath = $refpath; $msgpath =~ s/\.ref$/.msg/;
#   print STDERR "   $msgpath\n";

    ### Get reference, as ref to array:
    my $ref = read_ref($refpath);
    $msgpath = $ref->{Parser}{Message} if $ref->{Parser}{Message};
    $T->log("Trying $refpath [$msgpath]\n");

    ### Prepare output directory:
    (-d $output_dir) or mkpath($output_dir) or die "mkpath $output_dir: $!\n";

    ### Create parser which outputs to testout/scratch:
    my $parser = MIME::Parser->new;
    $parser->output_dir($output_dir);
    $parser->extract_nested_messages($ref->{Parser}{ExtractNested});
    $parser->output_to_core(0);
    $parser->ignore_errors(0);
    
    ### Parse:
    my $ent = eval { $parser->parse_open($msgpath) };
    if ($@ || !$ent) {
	$T->ok($ref->{Msg}{Fail},
	       $refpath,
	       Problem => $@);
    }
    else {
	my $ok = eval { check_ref($msgpath, $ent, $ref) };
	$T->ok($ok,
	       $refpath,
	       Error   => $@,
	       Message => $msgpath,
	       Parser  => ($ref->{Parser}{Name} || 'default'));
    }

    ### Cleanup:
    rmtree($output_dir);
}

### Done!
exit(0);
1;

#------------------------------

sub read_ref {
    my $path = shift;
    open IN, "<$path" or die "open $path: $!\n";
    my $expr = join('', <IN>);
    close IN;
    my $ref = eval $expr; $@ and die "syntax error in $path\n";
    $ref;
}

#------------------------------

sub trim {
    local $_ = shift;
    s/^\s*//;
    s/\s*$//;
    $_;
}

#------------------------------

sub check_ref {
    my ($msgpath, $ent, $ref) = @_;

    ### For each Msg in the ref:
  MSG:
    foreach my $partname (sort keys %$ref) {
	$partname =~ /^(Msg|Part_)/ or next;
	my $msg_ref = $ref->{$partname};
	my $part    = get_part($ent, $partname) || 
	    die "no such part: $partname\n";
	my $head    = $part->head; $head->unfold;
	my $body    = $part->bodyhandle;

	### For each attribute in the Msg:
      ATTR:
	foreach (sort keys %$msg_ref) {

	    my $want = $msg_ref->{$_};
	    my $got;
	    if    (/^Boundary$/) { $got = $head->multipart_boundary }
	    elsif (/^From$/)     { $got  = trim($head->get("From", 0)); 
			           $want = trim($want); }
	    elsif (/^To$/)       { $got  = trim($head->get("To", 0)); 
			           $want = trim($want); }
	    elsif (/^Subject$/)  { $got  = trim($head->get("Subject", 0));
			           $want = trim($want); }
	    elsif (/^Charset$/)  { $got = 
				   $head->mime_attr("content-type.charset"); }
	    elsif (/^Disposition$/) { $got = 
				   $head->mime_attr("content-disposition"); }
	    elsif (/^Type$/)     { $got = $head->mime_type }
	    elsif (/^Encoding$/) { $got = $head->mime_encoding }
	    elsif (/^Filename$/) { $got = $head->recommended_filename }
	    elsif (/^Size$/)     { 
		if ($head->mime_type =~ m{^(text|message)}) {
		    $T->log("Skipping Size evaulation in text message\n\n");
		    next ATTR;
		}
		if ($body and $body->path) { $got = (-s $body->path) }
	    }
	    else {
		die "$partname: unrecognized reference attribute: $_\n";
	    }

	    $T->log("Check $msgpath $partname $_:\n");
	    $T->log("  want: ". (defined($want) ? $want : '<<undef>>') . "\n");
	    $T->log("  got:  ". (defined($got)  ? $got  : '<<undef>>') . "\n");
	    $T->log("\n");

	    next ATTR if (!defined($want) and !defined($got));
	    next ATTR if ($want eq $got);
	    die "$partname: wanted '$want', got '$got'\n";
	}
    }

    1;
}

#------------------------------

sub get_part {
    my ($ent, $name) = @_;

    if ($name eq 'Msg') {
	return $ent;
    }
    elsif ($name =~ /^Part_(.*)$/) {
	my @path = split /_/, $1;
	my $part = $ent;
	while (@path) {
	    my $i = shift @path;
	    $part = $part->parts($i - 1);
	}
	return $part;
    }
    undef;   
}

1;
