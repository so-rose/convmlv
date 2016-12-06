#!/bin/bash

VERSION=$(echo "$(./convmlv.sh -v)" | sed -e 's/\./\_/g')

#HOW TO USE (Linux and Mac):
#  1. Update version above.
#  2. Put mlv2badpixels.sh, mlv_dump, raw2dng, and cr2hdr into a "binaries" folder in the repository.
#  3. Run this script, with one argument representing the path to the binaries.
#  4. A release tarball will automatically be created in "release" in the repository.

## It's reccommended that BINPATH is a folder in REP_PATH.

REP_PATH="$(pwd)"
BINPATH="${REP_PATH}/binaries"
SRCPATH="${REP_PATH}/src"
RELEASE="${REP_PATH}/release"

mkdir -p "$RELEASE"

if [[ $OSTYPE == "linux-gnu" ]]; then
	PLATFORM="linux"
elif [[ $OSTYPE == "darwin11" ]]; then
	PLATFORM="mac"
else
	echo "Platform not yet supported! Contact me at contact@sofusrose.com."
fi

cd $REP_PATH
tar -czvf $RELEASE/convmlv-${VERSION}-${PLATFORM}.tar.gz binaries/ src/ CHANGELOG licence convmlv.sh color-core/ color-ext DEPENDENCIES docs/MANPAGE docs/docs.pdf docs/workflow.txt configs/*
