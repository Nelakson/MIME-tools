#!/usr/bin/perl
use ExtUtils::MakeMaker;
WriteMakefile(
      NAME         =>MIME,
      VERSION      =>2.04,
      DISTNAME     =>'MIME-tools',
      'dist'       => {
	  COMPRESS     =>'gzip',
	  SUFFIX       =>'gz',	      
      },
);

