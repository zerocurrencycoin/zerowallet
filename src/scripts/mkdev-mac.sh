#!/bin/bash
# Dev build for macOS: Homebrew Qt, CONFIG+=debug, no packaging.
# Output: zerowallet.app in repo root. Run: open zerowallet.app
set -e -u -o pipefail
ME="mkdev-mac"
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

parse_mkdev_args "logs/mkdev-mac.log" "$@"
if [ -n "${MKDEV_CLEAN:-}" ]; then
  rm -rf zerowallet.app ZeroWallet.app bin
  notice "Cleaned zerowallet.app, ZeroWallet.app, bin/"
  exit 0
fi
notice "CONFIG=$CONFIG -j$JOBS"
[ -n "$LOG_FILE" ] && notice "Log: $LOG_FILE"

resolve_qt mac dev
[ -z "$QT_PREFIX" ] && err "Qt not found. Run: brew install qt@5"
[ -x "$QMAKE" ] || err "qmake not found at $QT_PREFIX/bin/qmake"

notice "Configuring..."
make distclean 2>/dev/null || true
rm -rf zerowallet.app ZeroWallet.app bin
$QMAKE zero-qt-wallet.pro CONFIG+=$CONFIG CONFIG+=sdk_no_version_check 2>&1 | log_capture

notice "Building..."
if make -j$JOBS 2>&1 | log_capture; then
  :
else
  build_fail "build failed"
fi

if [ -d zerowallet.app ]; then
  notice "Done. Run: open zerowallet.app"
  ls -la zerowallet.app
  [ -n "${RUN_AFTER_BUILD:-}" ] && { notice "Launching zerowallet.app"; open zerowallet.app; }
else
  build_fail "zerowallet.app not produced"
fi
