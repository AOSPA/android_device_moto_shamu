#!/bin/bash

host=`whoami`
SOURCE=$(pwd)
system_img=/mnt/android/system
export VENDOR=motorola
export DEVICE_VENDOR=moto
export DEVICE=shamu

VTREE=$SOURCE/$OUTDIR
mkdir -p $VTREE

# Check to see if the user passed a folder in to extract from rather than adb pull
if [ $# -eq 1 ]; then
    COPY_FROM=$1
    test ! -d "$COPY_FROM" && echo error reading dir "$COPY_FROM" && exit 1
fi

set -e

oat2dex()
{
    OFILE="$1"

    OAT="`dirname $OFILE`/arm/`basename $OFILE ."${OFILE##*.}"`.odex"
    if [ ! -e $OAT ]; then
        return 0
    fi

    HIT=`r2 -q -c '/ dex\n035' "$OAT" 2>/dev/null | grep hit0_0 | awk '{print $1}'`
    if [ -z "$HIT" ]; then
        echo "ERROR: Can't find dex header of `basename $OFILE`"
        return 1
    fi

    SIZE=`r2 -e scr.color=false -q -c "px 4 @$HIT+32" $OAT 2>/dev/null | tail -n 1 | awk '{print $2 $3}' | sed -e "s/^/0x/" | rax2 -e`
    r2 -q -c "pr $SIZE @$HIT > /tmp/classes.dex" "$OAT" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: Something went wrong in `basename $OFILE`"
    fi
}

function extract() {
    for FILE in `egrep -v '(^#|^$)' $1`; do
        echo "Extracting /system/$FILE ..."
        OLDIFS=$IFS IFS=":" PARSING_ARRAY=($FILE) IFS=$OLDIFS
        FILE=`echo ${PARSING_ARRAY[0]} | sed -e "s/^-//g"`
        DEST=${PARSING_ARRAY[1]}
        if [ -z $DEST ]; then
            DEST=$FILE
        fi
        DIR=`dirname $FILE`
        if [ ! -d $2/$DIR ]; then
            mkdir -p $2/$DIR
        fi
        if [ "$COPY_FROM" = "" ]; then
            # Try destination target first
            if [ -f $system_img/$DEST ]; then
                cp $system_img/$DEST $2/$DEST
            #else
                # if file does not exist try OEM target
                #if [ "$?" != "0" ]; then
                    cp $system_img/$FILE $2/$DEST
                #fi
                if [ "${FILE##*.}" = "apk" ] || [ "${FILE##*.}" = "jar" ]; then
                    oat2dex $system_img/$FILE
                fi
            fi
        else
            # Try destination target first
            if [ -f $COPY_FROM/$DEST ]; then
                cp $COPY_FROM/$DEST $2/$DEST
                if [ "${FILE##*.}" = "apk" ] || [ "${FILE##*.}" = "jar" ]; then
                    oat2dex $COPY_FROM/$DEST
                fi
            else
                # if file does not exist try OEM target
                if [ "$?" != "0" ]; then
                    cp $COPY_FROM/$FILE $2/$DEST
                fi
            fi
        fi
        if [ -e /tmp/classes.dex ]; then
            zip -gjq $2/$DEST /tmp/classes.dex
            rm /tmp/classes.dex
        fi
    done
}

DEVICE_BASE=$SOURCE/$VENDOR/$DEVICE/proprietary
rm -rf $DEVICE_BASE/*

# Extract the device specific files
extract $SOURCE/device-proprietary-files.txt $DEVICE_BASE

echo " "
echo "starting makefile creations"
echo " "
./setup-makefiles.sh
