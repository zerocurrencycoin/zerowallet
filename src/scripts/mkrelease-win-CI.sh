#!/bin/bash
if [ -z $APP_VERSION ]; then echo "APP_VERSION is not set"; exit 1; fi
if [ -z $PREV_VERSION ]; then echo "PREV_VERSION is not set"; exit 1; fi

if [ -z $ZCASH_DIR ]; then
    echo "ZCASH_DIR is not set. Please set it to the base directory of a Zero project with built Zero binaries."
    exit 1;
fi

if [ ! -f $ZCASH_DIR/zerod ]; then
    echo "Couldn't find zerod in $ZCASH_DIR/. Please build zerod."
    exit 1;
fi

if [ ! -f $ZCASH_DIR/zero-cli ]; then
    echo "Couldn't find zero-cli in $ZCASH_DIR/. Please build zerod."
    exit 1;
fi


## Ensure that zerod is built
if [ ! -f $ZCASH_DIR/zerod ]; then
    echo "Couldn't find zerod in $ZCASH_DIR/. Please build zerod"
    exit 1;
fi


if [ ! -f $ZCASH_DIR/zero-cli ]; then
    echo "Couldn't find zero-cli in $ZCASH_DIR/. Please build zero-cli"
    exit 1;
fi

echo -n "Version files.........."
# Replace the version number in the .pro file so it gets picked up everywhere
sed -i "s/${PREV_VERSION}/${APP_VERSION}/g" zero-qt-wallet.pro > /dev/null

# Also update it in the README.md
sed -i "s/${PREV_VERSION}/${APP_VERSION}/g" README.md > /dev/null
echo "[OK]"

echo -n "Cleaning..............."
rm -rf bin/*
rm -rf artifacts/*
make distclean >/dev/null 2>&1
echo "[OK]"

echo ""
echo "[Building on" `lsb_release -r`"]"



echo -n "Configuring............"
./src/scripts/dotranslations.sh >/dev/null



echo "[Windows]"

if [ -z $MXE_PATH ]; then
    echo "MXE_PATH is not set. Set it to ~/github/mxe/usr/bin if you want to build Windows"
    echo "Not building Windows"
    exit 0;
fi

if [ ! -f $ZCASH_DIR/zerod.exe ]; then
    echo "Couldn't find zerod.exe in $ZCASH_DIR/. Please build zerod.exe"
    exit 1;
fi


if [ ! -f $ZCASH_DIR/zero-cli.exe ]; then
    echo "Couldn't find zero-cli.exe in $ZCASH_DIR/. Please build zerod.exe"
    exit 1;
fi

export PATH=$MXE_PATH:$PATH

echo -n "Configuring............"
make clean  > /dev/null
rm -f zero-qt-wallet-mingw.pro
rm -rf release/
#Mingw seems to have trouble with precompiled headers, so strip that option from the .pro file
cat zero-qt-wallet.pro | sed "s/precompile_header/release/g" | sed "s/PRECOMPILED_HEADER.*//g"  > zero-qt-wallet-mingw.pro

echo "[OK]"




echo -n "Building Libsodium..............."
res/libsodium/buildlibsodium-win.sh > /dev/null
echo "[Libsodium Complete]"
echo -n "Building..............."
x86_64-w64-mingw32.static-qmake-qt5 zero-qt-wallet-mingw.pro CONFIG+=release > /dev/null
make -j32 > /dev/null
echo "[OK]"


echo -n "Packaging.............."
mkdir release/zerowallet-v$APP_VERSION > /dev/null 2>&1
cp release/zerowallet.exe             release/zerowallet-v$APP_VERSION > /dev/null
cp $ZCASH_DIR/zerod.exe               release/zerowallet-v$APP_VERSION > /dev/null
cp $ZCASH_DIR/zero-cli.exe            release/zerowallet-v$APP_VERSION > /dev/null
cp README.md                          release/zerowallet-v$APP_VERSION > /dev/null
cp LICENSE                            release/zerowallet-v$APP_VERSION > /dev/null
cd release && zip -r Windows-zerowallet-v$APP_VERSION.zip zerowallet-v$APP_VERSION/ > /dev/null
cd ..

mkdir artifacts >/dev/null 2>&1
cp release/Windows-zerowallet-v$APP_VERSION.zip ./artifacts/
echo "[OK]"

if [ -f artifacts/Windows-zerowallet-v$APP_VERSION.zip ] ; then
    echo -n "Package contents......."
    if unzip -l "artifacts/Windows-zerowallet-v$APP_VERSION.zip" | wc -l | grep -q "11"; then
        echo "[OK]"
    else
        echo "[ERROR]"
        exit 1
    fi
else
    echo "[ERROR]"
    exit 1
fi
