#!/usr/bin/perl
use ExtUtils::MakeMaker;
WriteMakefile(
      NAME         => "MIME-tools",
      VERSION_FROM => "lib/MIME/Tools.pm",
      PREREQ_PM    => {"Mail::Header"      => 1.01,
		       "Mail::Internet"    => 1.0203,
		       "Mail::Field"       => 1.05,

		       "MIME::QuotedPrint" => 2.03,
	               "MIME::Base64"      => 2.04,
		       "IO::Stringy"       => 1.211,
		       "File::Spec"        => 0.8,
		       },
      'dist'       => {
	  PREOP        =>"cvu_perl_preop -f -m MIME::Tools -A", 
	  COMPRESS     =>'gzip',
	  SUFFIX       =>'gz',	      
      },
);





