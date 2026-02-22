#!/bin/bash
# Parse args (env vars override)
while [[ $# -gt 0 ]]; do
  case "$1" in
    -z|--zero) ZERO_DIR="$2"; shift 2 ;;
    -v|--version) APP_VERSION="$2"; shift 2 ;;
    -p|--prev) PREV_VERSION="$2"; shift 2 ;;
    -m|--mxe) MXE_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

ZERO_DIR="${ZERO_DIR:-../Zero/src}"
MXE_PATH="${MXE_PATH:-$HOME/mxe/usr/bin}"
[ -d "$MXE_PATH" ] || MXE_PATH="$HOME/github/mxe/usr/bin"

if [ -z "$APP_VERSION" ]; then echo "APP_VERSION is not set. Use -v/--version or set env."; exit 1; fi
if [ -z "$PREV_VERSION" ]; then echo "PREV_VERSION is not set. Use -p/--prev or set env."; exit 1; fi

if [ ! -f "$ZERO_DIR/zerod.exe" ]; then
    echo "Couldn't find zerod.exe in $ZERO_DIR/. Please build zerod.exe"
    exit 1;
fi

if [ ! -f "$ZERO_DIR/zero-cli.exe" ]; then
    echo "Couldn't find zero-cli.exe in $ZERO_DIR/. Please build zero-cli.exe"
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

if [ -z "$MXE_PATH" ] || [ ! -d "$MXE_PATH" ]; then
    echo "MXE_PATH not found. Defaults: \$HOME/mxe/usr/bin, \$HOME/github/mxe/usr/bin. Use -m/--mxe to override."
    echo "Not building Windows"
    exit 0;
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
cp $ZERO_DIR/zerod.exe               release/zerowallet-v$APP_VERSION > /dev/null
cp $ZERO_DIR/zero-cli.exe            release/zerowallet-v$APP_VERSION > /dev/null
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
