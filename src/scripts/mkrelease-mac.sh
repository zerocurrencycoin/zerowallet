#!/bin/bash
# Copyright 2026 Zero Developers
# Release build for macOS: DMG package.
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
resolve_version
check_version_mismatch

apply_version_sed

[ -z "${QT_PREFIX:-}" ] && err "QT_PREFIX not set. Use -q/--qt or 'brew install qt@5'. Default: brew --prefix qt@5"
[ ! -f "$ZERO_DIR/zerod" ] && err "zerod not found in $ZERO_DIR. Build Zero first."

export PATH="${PATH}:/usr/local/bin"

make distclean >/dev/null 2>&1
rm -rf zerowallet.app ZeroWallet.app
rm -f "artifacts/macOS-zerowallet-v${APP_VERSION}.dmg"
step_done "Cleaning"

run_dotranslations >/dev/null
$QMAKE zero-qt-wallet.pro CONFIG+=release CONFIG+=sdk_no_version_check >/dev/null
step_done "Configuring"

make -j"${JOBS:-2}" >/dev/null
step_done "Building"

mkdir -p artifacts
rm -f artifacts/zerowallet.dmg >/dev/null 2>&1
rm -f artifacts/rw* >/dev/null 2>&1
cp "$ZERO_DIR/zerod" zerowallet.app/Contents/MacOS/
cp "$ZERO_DIR/zero-cli" zerowallet.app/Contents/MacOS/
rm -rf zerowallet.app/Contents/PlugIns
"$QT_PREFIX/bin/macdeployqt" zerowallet.app
step_done "Deploying"

mv zerowallet.app ZeroWallet.app
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
codesign --force --deep --sign "$CODESIGN_IDENTITY" ZeroWallet.app
step_done "Signing"

create-dmg --volname "ZeroWallet-v${APP_VERSION}" --volicon "res/logo.icns" --window-pos 200 120 --icon "ZeroWallet.app" 200 190 --app-drop-link 600 185 --hide-extension "ZeroWallet.app" --window-size 800 400 --hdiutil-quiet --background res/dmgbg.png "artifacts/macOS-zerowallet-v${APP_VERSION}.dmg" ZeroWallet.app >/dev/null 2>&1

[ ! -f "artifacts/macOS-zerowallet-v${APP_VERSION}.dmg" ] && err "DMG not created"
if [ "$(uname -s)" = "Darwin" ]; then
  "$SCRIPT_DIR/package-verify.sh" --mac "artifacts/macOS-zerowallet-v${APP_VERSION}.dmg"
fi
step_done "Package contents"
rm -rf artifacts/ZeroWallet.app
mv ZeroWallet.app artifacts/
step_done "Building dmg"
