#!/bin/bash
# Copyright 2026 Zero Developers
# Dev build for Windows *target*, running on Linux (MXE cross-compile). No packaging.
# Output: debug/zerowallet.exe (default) or release/zerowallet.exe (-r). Requires MXE with static Qt.
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="mkdev-win"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

parse_mkdev_args "logs/mkdev-win.log" "$@"
resolve_qt win dev
preflight_mkdev_win
if [ -n "${MKDEV_CHECK_ONLY:-}" ]; then
  notice "mkdev-win preflight OK"
  exit 0
fi

notice "CONFIG=${CONFIG} -j${JOBS} (Windows target, MXE cross-build on Linux)"
[ -n "${LOG_FILE:-}" ] && notice "Log: ${LOG_FILE}"

notice 'Configuring...'
if [ -n "${MKDEV_CLEAN:-}" ]; then
  make clean 2>/dev/null || true
  rm -f zero-qt-wallet-mingw.pro Makefile
  rm -rf debug release
  notice 'Cleaned (clean)'
fi

notice 'Building libsodium (Windows target)...'
res/libsodium/buildlibsodium-win.sh 2>&1 | log_capture || err 'libsodium build failed'
[ -n "${CONFIG:-}" ] || err 'CONFIG not set (parse_mkdev_args)'
sed "s/precompile_header/$CONFIG/g" zero-qt-wallet.pro | sed '/PRECOMPILED_HEADER/d' > zero-qt-wallet-mingw.pro
$QMAKE zero-qt-wallet-mingw.pro CONFIG+="$CONFIG" 2>&1 | log_capture || err "qmake failed"

notice 'Building...'
if make -j"$JOBS" 2>&1 | log_capture; then
  :
else
  build_fail 'build failed'
fi

OUTDIR="$([ "$CONFIG" = "release" ] && echo release || echo debug)"
if [ -f "$OUTDIR/zerowallet.exe" ]; then
  notice "Done. Binary: ${OUTDIR}/zerowallet.exe"
  ls -la "$OUTDIR/zerowallet.exe"
  if [ -n "${RUN_AFTER_BUILD:-}" ]; then
    if command -v wine >/dev/null 2>&1; then
      notice "Running wine ${OUTDIR}/zerowallet.exe --help"
      wine "$OUTDIR/zerowallet.exe" --help 2>/dev/null || true
    else
      notice "Install wine to test: wine ${OUTDIR}/zerowallet.exe --help"
    fi
  fi
else
  build_fail "${OUTDIR}/zerowallet.exe not produced"
fi
