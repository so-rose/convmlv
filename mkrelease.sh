#!/bin/bash

VERSION=$(echo "$(./convmlv.sh -v)" | sed -e 's/\./\_/g')
TYPE=$1

if [[ -z "${TYPE// }" ]]; then TYPE="examples"; fi

#HOW TO USE (Linux and Mac):
#  1. Make sure everything is up to date.
#  2. Put mlv2badpixels.sh, mlv_dump, raw2dng, and cr2hdr into the "binaries" folder in the repository.
#  4. Run the script with "bare" or "examples" as argument. "examples" is default.
#  3. A release tarball will automatically be created in "release" in the repository.

## It's reccommended that BINPATH is a folder in REP_PATH.

REP_PATH="$(pwd)"
BINPATH="${REP_PATH}/binaries"
SRCPATH="${REP_PATH}/src"
DOCPATH="${REP_PATH}/docs"
RELEASE="${REP_PATH}/release"

mkdir -p "$RELEASE"

#Determine Platform
if [[ $OSTYPE == "linux-gnu" ]]; then
	PLATFORM="linux"
elif [[ $OSTYPE == "darwin11" || $OSTYPE == "darwin15" ]]; then
	PLATFORM="mac"
else
	echo "Platform not yet supported! Contact me at contact@sofusrose.com."
fi

TARBALL="$RELEASE/convmlv-${VERSION}-${PLATFORM}.tar.gz"

#Build Docs
$DOCPATH/cleanDocs.sh > /dev/null
$DOCPATH/buildDocs.sh > /dev/null

#Make tarball
cd $REP_PATH
case $TYPE in
	examples)
		tar -czvf "$TARBALL" binaries/ src/ CHANGELOG 7D_badpixels.txt licence convmlv.sh \
			color-core/ color-ext docs/MANPAGE docs/docs.pdf docs/workflow.txt configs/*
		;;
	bare)
		tar -czvf "$TARBALL" binaries/ src/ CHANGELOG licence convmlv.sh \
                        color-core/ color-ext docs/MANPAGE docs/docs.pdf
		;;
esac

#Sign & Verify
gpg -b "$TARBALL"

$DOCPATH/cleanDocs.sh > /dev/null

gpg --verify "${TARBALL}.sig" "$TARBALL"
