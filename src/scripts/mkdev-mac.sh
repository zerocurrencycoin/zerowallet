#!/bin/bash
# Dev build for macOS: Homebrew Qt, CONFIG+=debug, no packaging.
# Output: zerowallet.app in repo root. Run: open zerowallet.app
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ME="mkdev-mac"
. "$SCRIPT_DIR/lib-log.sh"
cd "$REPO_ROOT"

# -L or -L=path: capture log. Default: logs/mkdev-mac.log
LOG_FILE=""
JOBS=4
CONFIG="debug"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -L) LOG_FILE="${LOG_FILE:-$REPO_ROOT/logs/mkdev-mac.log}"; shift ;;
    -L=*) LOG_FILE="${1#-L=}"; shift ;;
    -j) JOBS="${2:-4}"; shift 2 ;;
    -j*) JOBS="${1#-j}"; shift ;;
    -r) CONFIG="release"; shift ;;
    *) shift ;;
  esac
done
[ -n "$LOG_FILE" ] && mkdir -p "$(dirname "$LOG_FILE")"

log_capture() {
  [ -n "$LOG_FILE" ] && tee -a "$LOG_FILE" || cat
}

notice "CONFIG=$CONFIG -j$JOBS"
[ -n "$LOG_FILE" ] && notice "Log: $LOG_FILE"

QT_PREFIX="${QT_STATIC:-$(brew --prefix qt@5 2>/dev/null)}"
[ -z "$QT_PREFIX" ] && err "Qt not found. Run: brew install qt@5"

export PATH="$QT_PREFIX/bin:$PATH"
QMAKE="$QT_PREFIX/bin/qmake"
[ -x "$QMAKE" ] || err "qmake not found at $QT_PREFIX/bin/qmake"

notice "Configuring..."
make distclean 2>/dev/null || true
rm -rf zerowallet.app ZeroWallet.app bin
$QMAKE zero-qt-wallet.pro CONFIG+=$CONFIG CONFIG+=sdk_no_version_check 2>&1 | log_capture

notice "Building..."
if make -j$JOBS 2>&1 | log_capture; then
  :
else
  [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ] && analyze_build_log "$LOG_FILE"
  err "build failed"
fi

if [ -d zerowallet.app ]; then
  notice "Done. Run: open zerowallet.app"
  ls -la zerowallet.app
else
  [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ] && analyze_build_log "$LOG_FILE"
  err "zerowallet.app not produced"
fi
