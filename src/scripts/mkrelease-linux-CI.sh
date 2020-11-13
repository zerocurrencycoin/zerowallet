#!/bin/bash
if [ -z $QT_STATIC ]; then
    echo "QT_STATIC is not set. Please set it to the base directory of a statically compiled Qt";
    exit 1;
fi

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
#TODO
./src/scripts/dotranslations.sh >/dev/null
$QT_STATIC/bin/qmake zero-qt-wallet.pro -spec linux-clang CONFIG+=release > /dev/null
echo "[OK]"


echo -n "Building..............."
rm -rf bin/zero-qt-wallet* > /dev/null
rm -rf bin/zerowallet* > /dev/null
make clean > /dev/null
make -j$(nproc) > /dev/null
echo "[OK]"


# Test for Qt
echo -n "Static link............"
if [[ $(ldd zerowallet | grep -i "Qt") ]]; then
    echo "FOUND QT; ABORT; RELEASE BUILD REQUIRES STATIC QT";
    exit 1
fi
echo "[OK]"


echo -n "Packaging.............."
mkdir bin/zerowallet-v$APP_VERSION > /dev/null
strip zerowallet

cp zerowallet                     bin/zerowallet-v$APP_VERSION > /dev/null
cp $ZCASH_DIR/zerod               bin/zerowallet-v$APP_VERSION > /dev/null
cp $ZCASH_DIR/zero-cli            bin/zerowallet-v$APP_VERSION > /dev/null
cp README.md                      bin/zerowallet-v$APP_VERSION > /dev/null
cp LICENSE                        bin/zerowallet-v$APP_VERSION > /dev/null

cd bin && tar czf linux-zerowallet-v$APP_VERSION.tar.gz zerowallet-v$APP_VERSION/ > /dev/null
cd ..

mkdir artifacts >/dev/null 2>&1
mkdir release >/dev/null 2>&1
cp bin/linux-zerowallet-v$APP_VERSION.tar.gz ./artifacts/linux-zerowallet-v$APP_VERSION.tar.gz
echo "[OK]"


if [ -f artifacts/linux-zerowallet-v$APP_VERSION.tar.gz ] ; then
    echo -n "Package contents......."
    # Test if the package is built OK
    if tar tf "artifacts/linux-zerowallet-v$APP_VERSION.tar.gz" | wc -l | grep -q "6"; then
        echo "[OK]"
    else
        echo "[ERROR]"
        exit 1
    fi
else
    echo "[ERROR]"
    exit 1
fi

echo -n "Building deb..........."
debdir=bin/deb/zerowallet-v$APP_VERSION
mkdir -p $debdir > /dev/null
mkdir    $debdir/DEBIAN
mkdir -p $debdir/usr/local/bin

cat src/scripts/control | sed "s/RELEASE_VERSION/$APP_VERSION/g" > $debdir/DEBIAN/control

cp zerowallet                   $debdir/usr/local/bin/

strip $ZCASH_DIR/zerod
strip $ZCASH_DIR/zero-cli

cp $ZCASH_DIR/zerod             $debdir/usr/local/bin/zerod
cp $ZCASH_DIR/zero-cli          $debdir/usr/local/bin/zero-cli

mkdir -p                        $debdir/usr/share/pixmaps/
cp res/zero.xpm                 $debdir/usr/share/pixmaps/

mkdir -p                        $debdir/usr/share/applications
cp src/scripts/desktopentry     $debdir/usr/share/applications/zerowallet.desktop

dpkg-deb --build                $debdir >/dev/null
cp $debdir.deb                  artifacts/linux-zerowallet-v$APP_VERSION.deb
echo "[OK]"
