#!/usr/bin/perl
use ExtUtils::MakeMaker;
WriteMakefile(
      NAME         => "MIME",
      VERSION_FROM => "MIME/ToolUtils.pm",
      DISTNAME     => "MIME-tools",
      PREREQ_PM    => {"Mail::Header"      => 1.01,
		       "Mail::Internet"    => 1.0203,
		       "MIME::QuotedPrint" => 1.05,
		       "MIME::Base64"      => 1.03
		       },
      'dist'       => {
	  PREOP        =>'(cd docs ; make )',
	  COMPRESS     =>'gzip',
	  SUFFIX       =>'gz',	      
      },
);

