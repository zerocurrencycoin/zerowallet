#!/bin/bash
# Dev build for Windows: cross-build from Linux via MXE. No packaging.
# Output: bin/zerowallet.exe (dev does not build in release/). Requires MXE with static Qt.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ME="mkdev-win"
. "$SCRIPT_DIR/lib-log.sh"
cd "$REPO_ROOT"

# -L or -L=path: capture log. Default: logs/mkdev-win.log
# -r: release config (default: debug, like mkdev-linux/mac)
LOG_FILE=""
CONFIG="debug"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -L) LOG_FILE="${LOG_FILE:-$REPO_ROOT/logs/mkdev-win.log}"; shift ;;
    -L=*) LOG_FILE="${1#-L=}"; shift ;;
    -r) CONFIG="release"; shift ;;
    -j) JOBS="$2"; shift 2 ;;
    -j*) JOBS="${1#-j}"; shift ;;
    -m|--mxe) MXE_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$LOG_FILE" ] && { mkdir -p "$(dirname "$LOG_FILE")"; : > "$LOG_FILE"; }

log_capture() {
  [ -n "$LOG_FILE" ] && tee -a "$LOG_FILE" || cat
}

# MXE: ~/mxe, /opt/mxe (build-from-source only)
if [ -z "$MXE_PATH" ]; then
  for p in "$HOME/mxe/usr/bin" /opt/mxe/usr/bin; do
    [ -x "$p/x86_64-w64-mingw32.static-qmake-qt5" ] && { MXE_PATH="$p"; break; }
  done
  MXE_PATH="${MXE_PATH:-$HOME/mxe/usr/bin}"
fi
[ -d "$MXE_PATH" ] || err "MXE not found. Set MXE_PATH or install to ~/mxe. See BUILD.md Windows."

export PATH="$MXE_PATH:$PATH"
QMAKE="x86_64-w64-mingw32.static-qmake-qt5"
command -v $QMAKE >/dev/null 2>&1 || err "MXE qmake not found. Build Qt in MXE: make qtbase qtwebsockets"

notice "CONFIG=$CONFIG -j$JOBS (MXE cross-build)"
[ -n "$LOG_FILE" ] && notice "Log: $LOG_FILE"

notice "Building libsodium..."
res/libsodium/buildlibsodium-win.sh 2>&1 | log_capture || err "libsodium build failed"

notice "Configuring..."
make clean 2>/dev/null || true
rm -f zero-qt-wallet-mingw.pro Makefile
cat zero-qt-wallet.pro | sed "s/precompile_header/$CONFIG/g" | sed '/PRECOMPILED_HEADER/d' > zero-qt-wallet-mingw.pro
$QMAKE zero-qt-wallet-mingw.pro CONFIG+=$CONFIG DESTDIR=bin 2>&1 | log_capture || err "qmake failed"

notice "Building..."
if make -j$JOBS 2>&1 | log_capture; then
  :
else
  [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ] && analyze_build_log "$LOG_FILE"
  err "build failed"
fi

if [ -f bin/zerowallet.exe ]; then
  notice "Done. Binary: bin/zerowallet.exe"
  ls -la bin/zerowallet.exe
else
  [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ] && analyze_build_log "$LOG_FILE"
  err "bin/zerowallet.exe not produced"
fi
