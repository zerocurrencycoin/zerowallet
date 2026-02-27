#!/bin/bash
# Copyright 2026 Zero Developers
# Release build for Windows *target*, running on Linux (MXE cross-compile).
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="mkrelease-win"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

parse_mkrelease_args "logs/mkrelease-win.log" "$@"
[ -n "$LOG_FILE" ] && exec > >(tee -a "$LOG_FILE") 2>&1
resolve_zero_dir win
resolve_qt win release
resolve_version
check_version_mismatch

apply_version_sed

[ ! -f "$ZERO_DIR/zerod.exe" ] && err "zerod.exe not found in $ZERO_DIR. Build Zero for Windows first."
[ ! -f "$ZERO_DIR/zero-cli.exe" ] && err "zero-cli.exe not found in $ZERO_DIR. Build Zero for Windows first."

rm -rf bin/*
rm -rf artifacts/*
make distclean >/dev/null 2>&1 || true
step_done "Cleaning"

run_dotranslations >/dev/null
section "Windows target (Linux host)"

[ -d "${MXE_PATH:-}" ] || err "MXE_PATH not found or not a directory. Set -m/--mxe or MXE_PATH. See BUILD.md Windows."

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
mkdir -p "$PKGDIR"
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

(cd release && zip -r "Windows-zerowallet-v${APP_VERSION}.zip" "zerowallet-v${APP_VERSION}/" >/dev/null 2>&1) || err "zip failed"

mkdir -p artifacts
cp "release/Windows-zerowallet-v${APP_VERSION}.zip" ./artifacts/
step_done "Packaging"

[ ! -f "artifacts/Windows-zerowallet-v${APP_VERSION}.zip" ] && err "Windows zip artifact not created"
"$SCRIPT_DIR/package-verify.sh" --windows "artifacts/Windows-zerowallet-v${APP_VERSION}.zip"
step_done "Package contents"
