#!/bin/bash
set -e -u -o pipefail
# Parse args (env vars override)
# shellcheck disable=SC2034
ME="mkrelease-win"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -z|--zero) ZERO_DIR="$2"; shift 2 ;;
    -v|--version) APP_VERSION="$2"; shift 2 ;;
    -p|--prev) PREV_VERSION="$2"; shift 2 ;;
    -m|--mxe) MXE_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

resolve_zero_dir win
resolve_qt win release

[ -z "$APP_VERSION" ] && err "APP_VERSION not set. Use -v/--version or set env."
[ -z "$PREV_VERSION" ] && err "PREV_VERSION not set. Use -p/--prev or set env."
[ ! -f "$ZERO_DIR/zerod.exe" ] && err "zerod.exe not found in $ZERO_DIR. Build Zero for Windows first."
[ ! -f "$ZERO_DIR/zero-cli.exe" ] && err "zero-cli.exe not found in $ZERO_DIR. Build Zero for Windows first."

check_version_mismatch
apply_version_sed

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
sed "s/precompile_header/release/g" zero-qt-wallet.pro | sed "s/PRECOMPILED_HEADER.*//g" > zero-qt-wallet-mingw.pro
step_done "Configuring"

res/libsodium/buildlibsodium-win.sh >/dev/null
step_done "Building libsodium"

$QMAKE zero-qt-wallet-mingw.pro CONFIG+=release >/dev/null
make -j"${JOBS:-2}" >/dev/null
step_done "Building"

PKGDIR="release/zerowallet-v${APP_VERSION}"
mkdir "$PKGDIR" >/dev/null 2>&1
cp release/zerowallet.exe             "$PKGDIR/" >/dev/null
cp "$ZERO_DIR/zerod.exe"             "$PKGDIR/" >/dev/null
cp "$ZERO_DIR/zero-cli.exe"          "$PKGDIR/" >/dev/null
cp README.md                          "$PKGDIR/" >/dev/null
cp LICENSE                            "$PKGDIR/" >/dev/null

# Wallet expects zerod.exe next to zerowallet.exe (connection.cpp: applicationDirPath + zerod.exe)
ZEROD_IN_PKG="$PKGDIR/zerod.exe"
[ -f "$ZEROD_IN_PKG" ] || err "zerod.exe not found at $ZEROD_IN_PKG after copy (ZERO_DIR=$ZERO_DIR)"
notice "zerod.exe: $ZEROD_IN_PKG (same dir as zerowallet.exe)"
step_done "zerod path verified"

cd release && zip -r "Windows-zerowallet-v${APP_VERSION}.zip" "zerowallet-v${APP_VERSION}/" >/dev/null
cd ..

mkdir artifacts >/dev/null 2>&1
cp "release/Windows-zerowallet-v${APP_VERSION}.zip" ./artifacts/
step_done "Packaging"

[ ! -f "artifacts/Windows-zerowallet-v${APP_VERSION}.zip" ] && err "Windows zip artifact not created"
unzip -l "artifacts/Windows-zerowallet-v$APP_VERSION.zip" | wc -l | grep -q "11" || err "package contents incomplete"
step_done "Package contents"
