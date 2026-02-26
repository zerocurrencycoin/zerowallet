#!/bin/bash
# Dev build for Windows: cross-build from Linux via MXE. No packaging.
# Output: debug/zerowallet.exe (default) or release/zerowallet.exe (-r). Requires MXE with static Qt.
set -e -u -o pipefail
ME="mkdev-win"
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

parse_mkdev_args "logs/mkdev-win.log" "$@"
if [ -n "${MKDEV_CLEAN:-}" ]; then
  rm -rf debug release zero-qt-wallet-mingw.pro Makefile
  notice "Cleaned debug/, release/, mingw files"
  exit 0
fi
[ -n "$LOG_FILE" ] && : > "$LOG_FILE"
resolve_qt win dev
[ -d "$MXE_PATH" ] || err "MXE not found. Set MXE_PATH or install to ~/mxe. See BUILD.md Windows."
command -v $QMAKE >/dev/null 2>&1 || err "MXE qmake not found. Build Qt in MXE: make qtbase qtwebsockets"

notice "CONFIG=$CONFIG -j$JOBS (MXE cross-build)"
[ -n "$LOG_FILE" ] && notice "Log: $LOG_FILE"

notice "Building libsodium..."
res/libsodium/buildlibsodium-win.sh 2>&1 | log_capture || err "libsodium build failed"

notice "Configuring..."
make clean 2>/dev/null || true
rm -f zero-qt-wallet-mingw.pro Makefile
sed "s/precompile_header/$CONFIG/g" zero-qt-wallet.pro | sed '/PRECOMPILED_HEADER/d' > zero-qt-wallet-mingw.pro
$QMAKE zero-qt-wallet-mingw.pro CONFIG+=$CONFIG 2>&1 | log_capture || err "qmake failed"

notice "Building..."
if make -j$JOBS 2>&1 | log_capture; then
  :
else
  build_fail "build failed"
fi

OUTDIR="$([ "$CONFIG" = "release" ] && echo release || echo debug)"
if [ -f "$OUTDIR/zerowallet.exe" ]; then
  notice "Done. Binary: $OUTDIR/zerowallet.exe"
  ls -la "$OUTDIR/zerowallet.exe"
  if [ -n "${RUN_AFTER_BUILD:-}" ]; then
    if command -v wine >/dev/null 2>&1; then
      notice "Running wine $OUTDIR/zerowallet.exe --help"
      wine "$OUTDIR/zerowallet.exe" --help 2>/dev/null || true
    else
      notice "Install wine to test: wine $OUTDIR/zerowallet.exe --help"
    fi
  fi
else
  build_fail "$OUTDIR/zerowallet.exe not produced"
fi
