#!/bin/bash
# Parse args (env vars override). Same interface as mkrelease-linux/win.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -q|--qt|--qt_static) QT_STATIC="$2"; shift 2 ;;
    -z|--zero) ZERO_DIR="$2"; shift 2 ;;
    -v|--version) APP_VERSION="$2"; shift 2 ;;
    *) shift ;;
  esac
done

ZERO_DIR="${ZERO_DIR:-../Zero/src}"
QT_STATIC="${QT_STATIC:-$(brew --prefix qt@5 2>/dev/null)}"

if [ -z "$QT_STATIC" ]; then
    echo "QT_STATIC is not set. Use -q/--qt or 'brew install qt@5'. Default: brew --prefix qt@5";
    exit 1;
fi

if [ -z "$APP_VERSION" ]; then
    echo "APP_VERSION is not set. Please set it to the current release version of the app";
    exit 1;
fi

if [ ! -f "$ZERO_DIR/zerod" ]; then
    echo "Could not find compiled zerod in $ZERO_DIR/.";
    exit 1;
fi

if ! cat src/version.h | grep -q "$APP_VERSION"; then
    echo "Version mismatch in src/version.h"
    exit 1
fi

export PATH=$PATH:/usr/local/bin

#Clean
echo -n "Cleaning..............."
make distclean >/dev/null 2>&1
rm -f artifacts/macOS-zerowallet-v$APP_VERSION.dmg
echo "[OK]"


echo -n "Configuring............"
# Build
#TODO
./src/scripts/dotranslations.sh >/dev/null
$QT_STATIC/bin/qmake zero-qt-wallet.pro CONFIG+=release >/dev/null
echo "[OK]"


echo -n "Building..............."
make -j4 >/dev/null
echo "[OK]"

#Qt deploy
echo -n "Deploying.............."
mkdir artifacts >/dev/null 2>&1
rm -f artifcats/zerowallet.dmg >/dev/null 2>&1
rm -f artifacts/rw* >/dev/null 2>&1
cp $ZERO_DIR/zerod zerowallet.app/Contents/MacOS/
cp $ZERO_DIR/zero-cli zerowallet.app/Contents/MacOS/
$QT_STATIC/bin/macdeployqt zerowallet.app
echo "[OK]"


echo -n "Building dmg..........."
mv zerowallet.app ZeroWallet.app
create-dmg --volname "ZeroWallet-v$APP_VERSION" --volicon "res/logo.icns" --window-pos 200 120 --icon "ZeroWallet.app" 200 190  --app-drop-link 600 185 --hide-extension "ZeroWallet.app"  --window-size 800 400 --hdiutil-quiet --background res/dmgbg.png  artifacts/macOS-zerowallet-v$APP_VERSION.dmg ZeroWallet.app >/dev/null 2>&1

#mkdir bin/dmgbuild >/dev/null 2>&1
#sed "s/RELEASE_VERSION/${APP_VERSION}/g" res/appdmg.json > bin/dmgbuild/appdmg.json
#cp res/logo.icns bin/dmgbuild/
#cp res/dmgbg.png bin/dmgbuild/

#cp -r zerowallet.app bin/dmgbuild/

#appdmg --quiet bin/dmgbuild/appdmg.json artifacts/macOS-zerowallet-v$APP_VERSION.dmg >/dev/null
if [ ! -f artifacts/macOS-zerowallet-v$APP_VERSION.dmg ]; then
    echo "[ERROR]"
    exit 1
fi
echo  "[OK]"
