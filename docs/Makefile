TRACE = 

P2CH   = pod2coolhtml
LIBPOD = README.pod

all: pod readme

pod:
	${P2CH} -R ../lib -O . -I MIME

readme: ../README

../README: ${LIBPOD}
	pod2readme -s -t ${LIBPOD} > readme
	mv readme ../README


#------------------------------------------------------------




