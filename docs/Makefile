#------------------------------------------------------------
# Master makefile for MIME::
#------------------------------------------------------------

SHELL     = /bin/sh
MODS      =	\
		Body.pm \
		Decoder.pm \
		Entity.pm \
		Head.pm \
		IO.pm \
		Latin1.pm \
		Parser.pm \
		ParserBase.pm \
		ToolUtils.pm

#------------------------------------------------------------
# For installers...
#------------------------------------------------------------

POD2HTML       = ../misc/mod2html
POD2HTML_FLAGS = --podpath=. --flush --htmlroot=..
HTMLS          = ${MODS:.pm=.html} MIME-tools.html
VPATH          = ../MIME 
DOCS           = .

.SUFFIXES: .pm .pod .html

docs: ${HTMLS} ${MODS}
	cp MIME-tools.pod ../README

.pm.html:
	${POD2HTML} ${POD2HTML_FLAGS} \
		--title=MIME::$* \
		--infile=$< \
		--outfile=${DOCS}/$*.html
	rm -rf /tmp/.pod2html*

.pod.html:
	${POD2HTML} ${POD2HTML_FLAGS} \
		--title=$* \
		--infile=$< \
		--outfile=$*.html
	rm -rf /tmp/.pod2html*
	
#------------------------------------------------------------

