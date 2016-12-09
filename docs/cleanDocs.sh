#!/bin/bash

#Run from within docs/.

ROOT_DIR="/home/sofus/subhome/src/convmlv"
DDIR="$ROOT_DIR/docs"

#~ rm -f ./docs.aux ./docs.log ./docs.out ./docs.toc ./texput.log > /dev/null #Remove any local bullshit.

cd $DDIR

rm -f $DDIR/docs.aux $DDIR/docs.log $DDIR/docs.out $DDIR/docs.toc $DDIR/texput.log $DDIR/MANPAGE $DDIR/docs.pdf > /dev/null
