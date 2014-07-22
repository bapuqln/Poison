#!/bin/bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

echo "Copyright (c) 2014 stal @ Zodiac Labs."
echo "Did you remember to commit so the version number gets bumped?"

set +e
XCTOOL=`which xctool`
if [ $? != 0 ]
    then echo "xctool not found, is it on your PATH?"
fi
set -e

xctool -project Poison2x.xcodeproj -scheme Poison -configuration Release \
       "CONFIGURATION_BUILD_DIR=./build" $@

rm -rf dist || true
mkdir dist
cd dist

tar -xjf "../resources/frozen_disk_image.tar.bz2"
rm Tox/Tox.app
cp -r "../build/Tox.app" Tox/Tox.app
cp -r "../build/Tox.app.dSYM" "Tox/Debug Tools/Tox.app.dSYM"
hdiutil create -size 32m -srcfolder Tox \
        -format UDBZ -nospotlight -noanyowners "Tox.dmg"
rm -rf Tox

cd "../build"

GREF=$(defaults read $(pwd)/Tox.app/Contents/Info.plist SCGitRef | cut -c 1-7)
BNUM=$(defaults read $(pwd)/Tox.app/Contents/Info.plist CFBundleVersion)

zip -r "../dist/$BNUM-$GREF.zip" Tox.app

cat <<EOF
All done. Here's the rest of the release checklist:
- Generate delta package using deltatool
- Sign packages with arisa
- Update the catalog
EOF
