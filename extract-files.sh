#!/bin/sh

#Credit to CM for base of extraction script
#Augmented by Ayysir

set -e

host=`whoami`
SOURCE=$(pwd)
system_img=/mnt/android/system
VENDOR=moto
DEVICE=shamu
OUTDIR=vendor/$VENDOR/$DEVICE

#APK packages
declare -a apks=("ConfigUpdater" "DMAgent")

# VTREE means "vendor tree" this is for
VTREE=$SOURCE/$OUTDIR
mkdir -p $VTREE

if [ $# -eq 0 ]; then
  SRC=adb
else
  if [ $# -eq 1 ]; then
    SRC=$1
  else
    echo "$0: bad number of arguments"
    echo ""
    echo "usage: $0 [PATH_TO_EXPANDED_ROM]"
    echo ""
    echo "If PATH_TO_EXPANDED_ROM is not specified, blobs will be extracted from"
    echo "the device using adb pull."
    exit 1
  fi
fi

BASE=$SOURCE/$VENDOR/$DEVICE/proprietary
rm -rf $BASE/*

for FILE in `cat $SOURCE/proprietary-blobs.txt | grep -v ^# | grep -v ^$ | sed -e 's#^/system/##g'| sed -e "s#^-/system/##g"`; do
    DIR=`dirname $FILE`
    if [ ! -d $BASE/$DIR ]; then
        mkdir -p $BASE/$DIR
    fi

    if [ -d $system_img ]; then
      cp $system_img/$FILE $BASE/$FILE

        #grab odex files for APKs
        for j in "${apks[@]}"
        do
          cp -R $system_img/app/${j}/arm $BASE/app/${j}
        done

    elif [ "$SRC" = "adb" ]; then
      adb pull /system/$FILE $BASE/$FILE
    else
      echo "Cannot find source locations"
    fi


done

echo " "
echo "starting makefile creations"
echo " "
./setup-makefiles.sh
