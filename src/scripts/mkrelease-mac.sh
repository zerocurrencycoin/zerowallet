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
[ -n "${LOG_FILE:-}" ] && exec > >(tee -a "${LOG_FILE}") 2>&1
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
make distclean >/dev/null 2>&1 || true
step_done 'Cleaning'

section 'macOS'
run_dotranslations >/dev/null
$QMAKE zero-qt-wallet.pro CONFIG+=release CONFIG+=sdk_no_version_check >/dev/null
step_done 'Configuring'

make -j"${JOBS:-2}" >/dev/null
step_done 'Building'

mkdir -p artifacts
rm -f artifacts/rw.*.macOS-zerowallet-v*.dmg "artifacts/macOS-zerowallet-v${APP_VERSION}.dmg"
notice "ZERO_DIR=${ZERO_DIR} (zerod: $(stat -f %z "${ZERO_DIR}/zerod" 2>/dev/null || stat -c %s "${ZERO_DIR}/zerod" 2>/dev/null) bytes)"
cp -f "$ZERO_DIR/zerod" ZeroWallet.app/Contents/MacOS/ || err 'copy zerod failed'
cp -f "$ZERO_DIR/zero-cli" ZeroWallet.app/Contents/MacOS/ || err 'copy zero-cli failed'
step_done 'Copying zerod'
rm -rf ZeroWallet.app/Contents/PlugIns
$QT_PREFIX/bin/macdeployqt ZeroWallet.app || err 'macdeployqt failed'
step_done 'Deploying'

if [ -z "${SKIP_STRIP:-}" ]; then
  for f in ZeroWallet.app/Contents/MacOS/ZeroWallet ZeroWallet.app/Contents/MacOS/zerod ZeroWallet.app/Contents/MacOS/zero-cli; do
    [ -f "$f" ] && strip "$f"
  done
  step_done 'Stripping'
fi
# Always sign so the app runs (unsigned => EXC_BAD_ACCESS Code Signature Invalid). -N = ad-hoc only.
if [ -n "${SKIP_SIGN:-}" ]; then
  CODESIGN_IDENTITY="-"
fi
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
if [ "$CODESIGN_IDENTITY" = "-" ]; then
  notice 'Signing (ad-hoc)'
else
  notice "Signing (identity: ${CODESIGN_IDENTITY})"
fi
codesign --force --deep --sign "$CODESIGN_IDENTITY" ZeroWallet.app || err 'codesign failed'
step_done 'Signing'

rm -rf artifacts/ZeroWallet.app
mv -f ZeroWallet.app artifacts/ || err 'move ZeroWallet.app to artifacts failed'
step_done 'App in artifacts'

DMG_OUT="artifacts/macOS-zerowallet-v${APP_VERSION}.dmg"
rm -f artifacts/rw.*.macOS-zerowallet-v*.dmg "$DMG_OUT"
# Quieter output by default (--hdiutil-quiet, stdout to /dev/null). On failure, re-run with CREATE_DMG_VERBOSE=1 to see full output.
CREATE_DMG_EXTRA=()
[ -z "${CREATE_DMG_VERBOSE:-}" ] && CREATE_DMG_EXTRA=(--hdiutil-quiet)
if [ -n "${CREATE_DMG_VERBOSE:-}" ]; then
  create-dmg --volname "ZeroWallet-v${APP_VERSION}" --volicon "res/logo.icns" --window-pos 200 120 --icon "ZeroWallet.app" 200 190 --app-drop-link 600 185 --hide-extension "ZeroWallet.app" --window-size 800 400 "${CREATE_DMG_EXTRA[@]}" --background res/dmgbg.png "$DMG_OUT" artifacts/ZeroWallet.app || err 'create-dmg failed (see above)'
else
  create-dmg --volname "ZeroWallet-v${APP_VERSION}" --volicon "res/logo.icns" --window-pos 200 120 --icon "ZeroWallet.app" 200 190 --app-drop-link 600 185 --hide-extension "ZeroWallet.app" --window-size 800 400 "${CREATE_DMG_EXTRA[@]}" --background res/dmgbg.png "$DMG_OUT" artifacts/ZeroWallet.app 1>/dev/null || err 'create-dmg failed (see above)'
fi
[ ! -f "$DMG_OUT" ] && err 'DMG not created'
DMG_FORMAT=$(hdiutil imageinfo "$DMG_OUT" 2>/dev/null | sed -n 's/^Format:[[:space:]]*//p')
DMG_SIZE=$(stat -f %z "$DMG_OUT" 2>/dev/null || stat -c %s "$DMG_OUT" 2>/dev/null)
[ -n "$DMG_FORMAT" ] && [ -n "$DMG_SIZE" ] && notice "DMG: ${DMG_FORMAT}, $(( DMG_SIZE / 1024 / 1024 ))MB"
step_done 'Building dmg'

if [ -n "${MAKE_TGZ:-}" ]; then
  TGZ_DIR="artifacts/tgz/macOS-zerowallet-v${APP_VERSION}"
  TGZ_OUT="artifacts/macOS-zerowallet-v${APP_VERSION}.tgz"
  rm -rf "$TGZ_DIR" "${TGZ_OUT}"
  mkdir -p "artifacts/tgz" "$TGZ_DIR" || err 'mkdir for tgz failed'
  cp -R artifacts/ZeroWallet.app "$TGZ_DIR/" || err 'copy app into tgz dir failed'
  cp -f README.md "$TGZ_DIR/" || err 'copy README into tgz dir failed'
  (cd artifacts/tgz && tar czf "../macOS-zerowallet-v${APP_VERSION}.tgz" "macOS-zerowallet-v${APP_VERSION}") || err 'tar tgz failed'
  rm -rf "$TGZ_DIR"
  [ -f "$TGZ_OUT" ] || err 'tgz not created'
  step_done 'Building tgz'
fi
