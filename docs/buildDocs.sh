#!/bin/sh

# Run from within docs/.
ROOT_DIR="/home/sofus/subhome/src/convmlv"
DDIR="$ROOT_DIR/docs"

$ROOT_DIR/convmlv.sh -h | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" > $DDIR/MANPAGE
pdflatex $DDIR/docs.tex #> /dev/null
pdflatex $DDIR/docs.tex #> /dev/null #Compile twice to get TOC to show.
mv ./docs.pdf $DDIR

rm -f ./docs.aux ./docs.log ./docs.out ./docs.toc ./texput.log > /dev/null
