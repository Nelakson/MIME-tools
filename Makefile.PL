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
		       "IO::Scalar"        => 1.104,
		       "IO::ScalarArray"   => 1.105,
		       },
      'dist'       => {
	  PREOP        => q{(cd docs ; make)},
	  COMPRESS     =>'gzip',
	  SUFFIX       =>'gz',	      
      },
);





