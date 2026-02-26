#!/bin/bash
# Parse args (env vars override)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ME="mkrelease-win"
. "$SCRIPT_DIR/lib-log.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -z|--zero) ZERO_DIR="$2"; shift 2 ;;
    -v|--version) APP_VERSION="$2"; shift 2 ;;
    -p|--prev) PREV_VERSION="$2"; shift 2 ;;
    -m|--mxe) MXE_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Default: ../Zero; if absent, ../ZeroWin. Binaries in src/
if [ -z "$ZERO_DIR" ]; then
  ZERO_BASE="../Zero"
  [ -d "$ZERO_BASE" ] || ZERO_BASE="../ZeroWin"
  ZERO_DIR="$ZERO_BASE/src"
fi
# MXE: ~/mxe, /opt/mxe (build-from-source only)
if [ -z "$MXE_PATH" ]; then
  for p in "$HOME/mxe/usr/bin" /opt/mxe/usr/bin; do
    [ -x "$p/x86_64-w64-mingw32.static-qmake-qt5" ] && { MXE_PATH="$p"; break; }
  done
  MXE_PATH="${MXE_PATH:-$HOME/mxe/usr/bin}"
fi

[ -z "$APP_VERSION" ] && err "APP_VERSION not set. Use -v/--version or set env."
[ -z "$PREV_VERSION" ] && err "PREV_VERSION not set. Use -p/--prev or set env."
[ ! -f "$ZERO_DIR/zerod.exe" ] && err "zerod.exe not found in $ZERO_DIR. Build Zero for Windows first."
[ ! -f "$ZERO_DIR/zero-cli.exe" ] && err "zero-cli.exe not found in $ZERO_DIR. Build Zero for Windows first."

sed -i "s/${PREV_VERSION}/${APP_VERSION}/g" zero-qt-wallet.pro > /dev/null
sed -i "s/${PREV_VERSION}/${APP_VERSION}/g" README.md > /dev/null
step_done "Version files"

rm -rf bin/*
rm -rf artifacts/*
make distclean >/dev/null 2>&1
step_done "Cleaning"

./src/scripts/dotranslations.sh >/dev/null 2>/dev/null || true
step_done "Configuring"

section "Windows"

if [ -z "$MXE_PATH" ] || [ ! -d "$MXE_PATH" ]; then
    warn "MXE_PATH not found. Default: \$HOME/mxe/usr/bin. Use -m/--mxe to override."
    notice "Skipping Windows build"
    exit 0
fi

export PATH=$MXE_PATH:$PATH

make clean >/dev/null
rm -f zero-qt-wallet-mingw.pro
rm -rf release/
cat zero-qt-wallet.pro | sed "s/precompile_header/release/g" | sed "s/PRECOMPILED_HEADER.*//g" > zero-qt-wallet-mingw.pro
step_done "Configuring"

res/libsodium/buildlibsodium-win.sh >/dev/null
step_done "Building libsodium"

x86_64-w64-mingw32.static-qmake-qt5 zero-qt-wallet-mingw.pro CONFIG+=release >/dev/null
make -j${JOBS:-2} >/dev/null
step_done "Building"

mkdir release/zerowallet-v$APP_VERSION >/dev/null 2>&1
cp release/zerowallet.exe             release/zerowallet-v$APP_VERSION >/dev/null
cp $ZERO_DIR/zerod.exe               release/zerowallet-v$APP_VERSION >/dev/null
cp $ZERO_DIR/zero-cli.exe            release/zerowallet-v$APP_VERSION >/dev/null
cp README.md                          release/zerowallet-v$APP_VERSION >/dev/null
cp LICENSE                            release/zerowallet-v$APP_VERSION >/dev/null
cd release && zip -r Windows-zerowallet-v$APP_VERSION.zip zerowallet-v$APP_VERSION/ >/dev/null
cd ..

mkdir artifacts >/dev/null 2>&1
cp release/Windows-zerowallet-v$APP_VERSION.zip ./artifacts/
step_done "Packaging"

[ ! -f artifacts/Windows-zerowallet-v$APP_VERSION.zip ] && err "Windows zip artifact not created"
unzip -l "artifacts/Windows-zerowallet-v$APP_VERSION.zip" | wc -l | grep -q "11" || err "package contents incomplete"
step_done "Package contents"
