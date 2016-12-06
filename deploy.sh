#!/bin/bash

VERSION=$(echo "$(./convmlv.sh -v)" | sed -e 's/\./\_/g')
REMOTE=sofus@yeti

if [[ $OSTYPE == "linux-gnu" ]]; then
        PLATFORM="linux"
elif [[ $OSTYPE == "darwin11" ]]; then
        PLATFORM="mac"
else
        echo "Platform not yet supported! Contact me at contact@sofusrose.com."
fi

rsync -avzP release/convmlv-${VERSION}-${PLATFORM}.tar.gz $REMOTE:/data/main/convmlv/

ssh $REMOTE VERSION=$VERSION PLATFORM=$PLATFORM 'bash -s'  << 'ENDSSH'

cd /data/main/convmlv
tar -xvzf /data/main/convmlv/convmlv-$VERSION-$PLATFORM.tar.gz
rm /data/main/convmlv/convmlv-$VERSION-$PLATFORM.tar.gz

ENDSSH

echo -e "\nRemember to update apt dependencies on $REMOTE"!
