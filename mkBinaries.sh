#!/bin/bash

#Run from convmlv root. Builds all ML-specific binaries.

cd binaries

#Remove old binaries.
rm cr2hdr mlv_dump raw2dng

#Build Binaries
git clone https://git.sofusrose.com/so-rose/magic-tools.git

#cd magic-tools
magic-tools/prepAll.sh
magic-tools/tools/mkToolStack.sh

cp magic-tools/tools/latest/* .
#No place to build mlv2badpixels.sh from, unfortunately.

rm -rf magic-tools
