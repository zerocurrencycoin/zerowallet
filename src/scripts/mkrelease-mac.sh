#!/bin/bash
# Copyright 2026 Zero Developers
# Release build for macOS: Qt from Homebrew, DMG.
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="mkrelease-mac"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

parse_mkrelease_args "logs/mkrelease-mac.log" "$@"
[ -n "$LOG_FILE" ] && exec > >(tee -a "$LOG_FILE") 2>&1
resolve_zero_dir mac
resolve_qt mac release
[ ! -x "${QMAKE:-}" ] && err "QT_PREFIX not found at ${QT_PREFIX:-}. Use -q/--qt or 'brew install qt@5'."
export PATH="$PATH:/usr/local/bin"

resolve_version
check_version_mismatch
# macOS does not modify version files (zero-qt-wallet.pro, README.md); DMG name from version.h only.

check_zero_binaries mac

rm -rf zerowallet.app ZeroWallet.app
rm -rf bin/*
rm -rf artifacts/*
make distclean >/dev/null 2>&1 || true
step_done "Cleaning"

section "macOS"
run_dotranslations >/dev/null
$QMAKE zero-qt-wallet.pro CONFIG+=release CONFIG+=sdk_no_version_check >/dev/null
step_done "Configuring"

make -j"${JOBS:-2}" >/dev/null
step_done "Building"

mkdir -p artifacts
rm -f artifacts/zerowallet.dmg >/dev/null 2>&1
rm -f artifacts/rw* >/dev/null 2>&1
notice "ZERO_DIR=$ZERO_DIR (zerod: $(stat -f %z "$ZERO_DIR/zerod" 2>/dev/null || stat -c %s "$ZERO_DIR/zerod" 2>/dev/null) bytes)"
cp "$ZERO_DIR/zerod" zerowallet.app/Contents/MacOS/
cp "$ZERO_DIR/zero-cli" zerowallet.app/Contents/MacOS/
step_done "Copying zerod"
rm -rf zerowallet.app/Contents/PlugIns
$QT_PREFIX/bin/macdeployqt zerowallet.app
step_done "Deploying"

mv zerowallet.app ZeroWallet.app
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
codesign --force --deep --sign "$CODESIGN_IDENTITY" ZeroWallet.app
step_done "Signing"

create-dmg --volname "ZeroWallet-v$APP_VERSION" --volicon "res/logo.icns" --window-pos 200 120 --icon "ZeroWallet.app" 200 190 --app-drop-link 600 185 --hide-extension "ZeroWallet.app" --window-size 800 400 --hdiutil-quiet --background res/dmgbg.png "artifacts/macOS-zerowallet-v${APP_VERSION}.dmg" ZeroWallet.app >/dev/null 2>&1
[ ! -f "artifacts/macOS-zerowallet-v${APP_VERSION}.dmg" ] && err "DMG not created"
rm -rf artifacts/ZeroWallet.app
mv ZeroWallet.app artifacts/
step_done "Building dmg"
