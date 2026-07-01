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
init_logging
resolve_zero_dir win
resolve_qt win release
resolve_version
check_version_mismatch
check_zero_binaries win

make distclean 2>/dev/null || true
rm -rf bin/*
step_done 'Cleaning'

section 'Windows target (Linux host)'
run_dotranslations

rm -f zero-qt-wallet-mingw.pro
rm -rf release/
# MXE MinGW chokes on the precompiled header; strip it from the generated .pro.
sed "s/precompile_header/release/g" zero-qt-wallet.pro | sed '/PRECOMPILED_HEADER/d' > zero-qt-wallet-mingw.pro
step_done 'Configuring'

res/libsodium/buildlibsodium-win.sh
step_done 'Building libsodium'

$QMAKE zero-qt-wallet-mingw.pro CONFIG+=release
make -j"$JOBS"
step_done 'Building'

PKGDIR="release/zerowallet-v${APP_VERSION}"
mkdir -p "$PKGDIR"
notice "ZERO_DIR=${ZERO_DIR} (zerod.exe: $(stat -c %s "${ZERO_DIR}/zerod.exe" 2>/dev/null) bytes)"
cp -f release/zerowallet.exe   "$PKGDIR/"
cp -f "$ZERO_DIR/zerod.exe"     "$PKGDIR/"
cp -f "$ZERO_DIR/zero-cli.exe"  "$PKGDIR/"
[ -z "${SKIP_STRIP:-}" ] && [ -n "${STRIP:-}" ] && "$STRIP" "$PKGDIR/zerowallet.exe" "$PKGDIR/zerod.exe" "$PKGDIR/zero-cli.exe"
cp -f README.md "$PKGDIR/"

# Wallet expects zerod.exe next to zerowallet.exe (connection.cpp: applicationDirPath + zerod.exe)
ZEROD_IN_PKG="$PKGDIR/zerod.exe"
[ -f "$ZEROD_IN_PKG" ] || err "zerod.exe not found at ${ZEROD_IN_PKG} after copy (ZERO_DIR=${ZERO_DIR})"
notice "zerod.exe: ${ZEROD_IN_PKG} (same dir as zerowallet.exe)"
step_done 'zerod path verified'

(cd release && zip -r "Windows-zerowallet-v${APP_VERSION}.zip" "zerowallet-v${APP_VERSION}/") || err 'zip failed'

mkdir -p artifacts
cp -f "release/Windows-zerowallet-v${APP_VERSION}.zip" ./artifacts/
step_done 'Packaging'

[ ! -f "artifacts/Windows-zerowallet-v${APP_VERSION}.zip" ] && err 'Windows zip artifact not created'
"$SCRIPT_DIR/package-verify.sh" --windows "artifacts/Windows-zerowallet-v${APP_VERSION}.zip"
step_done 'Package contents'
