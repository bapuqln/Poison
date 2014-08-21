#!/bin/bash
# Like Base internationalization, but works on OS X before 10.8.
# Copyright (c) 2013 - 2014 Zodiac Labs.
if [ "x$XCODE_VERSION_ACTUAL" != "x" ]
    then cd $PROJECT_DIR
else
    cd "$(echo $0 | sed -E s/[^/]+$//g)"
fi

if [ "x$1" == "x" ]
    then echo "$0: need one of (create, integrate, update, compile [destination], genstrings)"; exit 1;
fi

init_dirstruct() {
    mkdir -p "resources/interfaces/TL/strings"
    mkdir -p "resources/interfaces/TL/current_set"
    mkdir -p "resources/interfaces/TL/translated"
}
init_dirstruct

case $1 in
    create)
        for xib in resources/interfaces/*.xib
        do
            if [ ! -d "resources/interfaces/TL/strings/en.lproj" ]
                then mkdir -p "resources/interfaces/TL/strings/en.lproj"
            fi
            cp "$xib" "resources/interfaces/TL/current_set/$(basename $xib)"
            ibtool --generate-strings-file "resources/interfaces/TL/strings/en.lproj/$(basename $xib | sed s/\.xib$/.strings/)" $xib
        done
        ;;
    integrate)
        for xib in resources/interfaces/TL/current_set/*.xib
        do
            xibasename=$(basename $xib | sed s/\.xib$//)
            echo "... integrating localizations for $xibasename.xib..."
            for lang in resources/interfaces/TL/strings/*.lproj
            do
                lang_=$(basename $lang)
                mkdir -p "resources/interfaces/TL/translated/$lang_"
                ibtool --import-strings-file "resources/interfaces/TL/strings/$lang_/$xibasename.strings" \
                       --write "resources/interfaces/TL/translated/$lang_/$xibasename.xib" \
                       "$xib"
            done
        done
        exit 0
        ;;
    update)
        echo "making sure everything is integrated first"
        bash "./$(echo $0 | sed -E s/^.+\\///g)" integrate
        echo "okay, merging changes and updating strings files."
        for xib in resources/interfaces/*.xib
        do
            tempdir="_tmp"
            mkdir -p $tempdir
            xibasename=$(basename $xib | sed s/\.xib$//)
            for lang in resources/interfaces/TL/strings/*.lproj
            do
                lang_=$(basename $lang)
                echo "updating localization of $lang_ for $xibasename.xib..."
                ibtool --previous-file "resources/interfaces/TL/current_set/$xibasename.xib" \
                       --incremental-file "resources/interfaces/TL/translated/$lang_/$xibasename.xib" \
                       --localize-incremental --write "$tempdir/$xibasename.xib" \
                       "$xib"
                echo "... rewriting its strings file..."
                ibtool --generate-strings-file "resources/interfaces/TL/strings/$lang_/$xibasename.strings" \
                       "$tempdir/$xibasename.xib"
                echo "... copying it back into place..."
                cp "$tempdir/$xibasename.xib" "resources/interfaces/TL/translated/$lang_/$xibasename.xib"
            done
            echo "done, updating the current set"
            cp "$xib" "resources/interfaces/TL/current_set/$xibasename.xib"
            rm -rf $tempdir
        done
        ;;
    compile)
        echo "compiling all -> $2"
        for lang in resources/interfaces/TL/translated/*.lproj
        do
            lang_=$(basename $lang)
            if [ $lang_ == "en.lproj" ]
                then continue
            fi
            if [ ! -d "$2/$lang_" ]
                then mkdir -p  "$2/$lang_"
            fi
            for xib in $lang/*.xib
            do
                xibasename=$(basename $xib | sed s/\.xib$//)
                echo "... compiling $xibasename.xib for $lang_"
                ibtool --flatten "YES" --compile "$2/$lang_/$xibasename.nib" \
                       $xib
            done
        done
        ;;
    genstrings)
        echo "updating .strings for code..."
        find . -name '*.m' | xargs genstrings --little-endian -o "$(pwd)/resources/strings/en.lproj"
        ;;
esac


