#!/bin/bash
# Dev build for Linux: system Qt, CONFIG+=debug, no packaging.
# Output: zerowallet in repo root.
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="mkdev-linux"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

parse_mkdev_args "logs/mkdev-linux.log" "$@"
if [ -n "${MKDEV_CLEAN:-}" ]; then
  rm -rf zerowallet bin
  notice "Cleaned zerowallet, bin/"
  exit 0
fi
notice "CONFIG=$CONFIG -j$JOBS"
[ -n "$LOG_FILE" ] && notice "Log: $LOG_FILE"

for pkg in qtbase5-dev qtbase5-dev-tools libqt5websockets5-dev libqt5svg5-dev; do
  if ! dpkg -l "$pkg" 2>/dev/null | grep -q ^ii; then
    notice "Installing $pkg..."
    sudo apt-get install -y "$pkg"
  fi
done

resolve_qt linux dev
[ -z "$QMAKE" ] && err "qmake not found. Install qtbase5-dev-tools."

notice "Configuring..."
make distclean 2>/dev/null || true
rm -rf bin
$QMAKE zero-qt-wallet.pro CONFIG+="$CONFIG" 2>&1 | log_capture

notice "Building..."
if make -j"$JOBS" 2>&1 | log_capture; then
  :
else
  build_fail "build failed"
fi

[ -f zerowallet ] || err "zerowallet binary not produced"
notice "Done. Run ./zerowallet"
ls -la zerowallet
[ -n "${RUN_AFTER_BUILD:-}" ] && { notice "Running ./zerowallet --help"; ./zerowallet --help || true; }
