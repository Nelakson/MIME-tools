TRACE = 

P2CH   = perl -I${HOME}/dev/perl/podpeople/lib ${HOME}/bin/pod2coolhtml
LIBPOD = MIME-tools.pod

all: pod readme

pod:
	${P2CH} -R ../lib -O . -I MIME

readme: ../README

../README: ${LIBPOD}
	pod2readme -s -t ${LIBPOD} > readme
	mv readme ../README


#------------------------------------------------------------




