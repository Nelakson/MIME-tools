#!/usr/bin/perl
use ExtUtils::MakeMaker;
WriteMakefile(
      NAME         => "MIME",
      VERSION_FROM => "MIME/ToolUtils.pm",
      DISTNAME     => "MIME-tools",
      'dist'       => {
	  PREOP        =>'(cd docs ; make )',
	  COMPRESS     =>'gzip',
	  SUFFIX       =>'gz',	      
      },
);

