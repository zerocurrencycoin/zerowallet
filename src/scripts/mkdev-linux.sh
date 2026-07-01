#!/bin/bash
# Copyright 2026 Zero Developers
# Dev build for Linux: system Qt, CONFIG+=debug, no packaging.
# Output: zerowallet in repo root.
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="mkdev-linux"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

parse_mkdev_args "logs/mkdev-linux.log" "$@"
init_logging
notice "CONFIG=${CONFIG} -j${JOBS}"

# Check (don't auto-install) the dev Qt packages, matching mkdev-mac/win: hint the admin
# rather than running sudo (which hangs in CI and surprises the user). The dpkg check is cheap.
missing=""
for pkg in qtbase5-dev qtbase5-dev-tools libqt5websockets5-dev libqt5svg5-dev; do
  dpkg -l "$pkg" 2>/dev/null | grep -q ^ii || missing="${missing} ${pkg}"
done
[ -n "$missing" ] && err "Missing Qt dev packages:${missing}. Install: sudo apt install${missing}"

resolve_qt linux dev
[ -z "${QMAKE:-}" ] && err "qmake not found. Install: sudo apt install qtbase5-dev-tools"

notice 'Checking libsodium (Unix)...'
res/libsodium/buildlibsodium.sh || err 'libsodium check/build failed'

if [ -n "${MKDEV_CLEAN:-}" ]; then
  make distclean 2>/dev/null || true
  notice 'Cleaned (distclean)'
fi

notice 'Configuring...'
$QMAKE zero-qt-wallet.pro CONFIG+="$CONFIG"

notice 'Building...'
make -j"$JOBS" || build_fail 'build failed'

[ -f zerowallet ] || err 'zerowallet binary not produced'
notice 'Done. Run ./zerowallet'
ls -la zerowallet
if [ -n "${RUN_AFTER_BUILD:-}" ]; then
  notice 'Running ./zerowallet --help'
  ./zerowallet --help || true
fi
