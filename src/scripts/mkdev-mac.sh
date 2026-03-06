#!/bin/bash
# Copyright 2026 Zero Developers
# Dev build for macOS: Homebrew Qt, CONFIG+=debug, no packaging.
# Output: ZeroWallet.app in repo root. Run: open ZeroWallet.app
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="mkdev-mac"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

parse_mkdev_args "logs/mkdev-mac.log" "$@"
notice "CONFIG=${CONFIG} -j${JOBS}"
[ -n "${LOG_FILE:-}" ] && notice "Log: ${LOG_FILE}"

resolve_qt mac dev
[ -z "${QT_PREFIX:-}" ] && err "Qt not found. Run: brew install qt@5"
[ -x "${QMAKE:-}" ] || err "qmake not found at ${QT_PREFIX:-}/bin/qmake"

notice 'Configuring...'
if [ -n "${MKDEV_CLEAN:-}" ]; then
  make distclean 2>/dev/null || true
  rm -rf ZeroWallet.app zerowallet.app bin
  notice 'Cleaned (distclean)'
fi
$QMAKE zero-qt-wallet.pro CONFIG+="$CONFIG" CONFIG+=sdk_no_version_check 2>&1 | log_capture

notice 'Building...'
if make -j"$JOBS" 2>&1 | log_capture; then
  :
else
  build_fail 'build failed'
fi

if [ -d ZeroWallet.app ]; then
  notice 'Done. Run: open ZeroWallet.app'
  ls -la ZeroWallet.app
  [ -n "${RUN_AFTER_BUILD:-}" ] && { notice 'Launching ZeroWallet.app'; open ZeroWallet.app; }
else
  build_fail 'ZeroWallet.app not produced'
fi
