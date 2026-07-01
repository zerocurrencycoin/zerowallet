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
init_logging
notice "CONFIG=${CONFIG} -j${JOBS}"

resolve_qt mac dev
[ -z "${QT_PREFIX:-}" ] && err "Qt not found. Run: brew install qt@5"
[ -x "${QMAKE:-}" ] || err "qmake not found at ${QT_PREFIX:-}/bin/qmake"

if [ -n "${MKDEV_CLEAN:-}" ]; then
  make distclean 2>/dev/null || true
  # make distclean leaves the .app bundle behind; remove it explicitly.
  rm -rf ZeroWallet.app zerowallet.app
  notice 'Cleaned (distclean)'
fi

notice 'Configuring...'
$QMAKE zero-qt-wallet.pro CONFIG+="$CONFIG" CONFIG+=sdk_no_version_check

notice 'Building...'
make -j"$JOBS" || build_fail 'build failed'

if [ -d ZeroWallet.app ]; then
  notice 'Done. Run: open ZeroWallet.app'
  ls -la ZeroWallet.app
  if [ -n "${RUN_AFTER_BUILD:-}" ]; then
    notice 'Launching ZeroWallet.app'
    open ZeroWallet.app
  fi
else
  build_fail 'ZeroWallet.app not produced'
fi
