#!/bin/bash
# Dev build for Linux: system Qt, CONFIG+=debug, no packaging.
# Output: ./zerowallet in repo root.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ME="mkdev-linux"
. "$SCRIPT_DIR/lib-log.sh"
cd "$REPO_ROOT"

# -L or -L=path: capture log. Default: logs/mkdev-linux.log
LOG_FILE=""
JOBS=2
CONFIG="debug"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -L) LOG_FILE="${LOG_FILE:-$REPO_ROOT/logs/mkdev-linux.log}"; shift ;;
    -L=*) LOG_FILE="${1#-L=}"; shift ;;
    -j) JOBS="${2:-$(nproc)}"; shift 2 ;;
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

for pkg in qtbase5-dev qtbase5-dev-tools libqt5websockets5-dev libqt5svg5-dev; do
  if ! dpkg -l "$pkg" 2>/dev/null | grep -q ^ii; then
    notice "Installing $pkg..."
    sudo apt-get install -y "$pkg"
  fi
done

QMAKE=$(command -v qmake || command -v qmake-qt5 || true)
[ -z "$QMAKE" ] && err "qmake not found. Install qtbase5-dev-tools."

notice "Configuring..."
make distclean 2>/dev/null || true
rm -rf bin
$QMAKE zero-qt-wallet.pro CONFIG+=$CONFIG 2>&1 | log_capture

notice "Building..."
if make -j$JOBS 2>&1 | log_capture; then
  :
else
  [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ] && analyze_build_log "$LOG_FILE"
  err "build failed"
fi

[ -f zerowallet ] || err "zerowallet binary not produced"
notice "Done. Run ./zerowallet"
ls -la zerowallet
