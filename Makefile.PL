#!/usr/bin/perl
use ExtUtils::MakeMaker;
WriteMakefile(
      NAME         =>MIME,
      VERSION      =>2.02,
      DISTNAME     =>'MIME-tools',
      'dist'       => {
	  COMPRESS     =>'gzip',
	  SUFFIX       =>'gz',	      
      },
);

