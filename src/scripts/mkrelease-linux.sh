#!/bin/bash
# Copyright 2026 Zero Developers
# Release build for Linux: static Qt, tar.gz + deb.
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="mkrelease-linux"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

parse_mkrelease_args "logs/mkrelease-linux.log" "$@"
[ -n "$LOG_FILE" ] && exec > >(tee -a "$LOG_FILE") 2>&1
resolve_zero_dir linux
resolve_qt linux release
[ ! -x "${QMAKE:-}" ] && err "QT_PREFIX not found at ${QT_PREFIX:-}. Run ./src/scripts/build-qt-static.sh first, or set -q/--qt."

resolve_version
check_version_mismatch
apply_version_sed

[ ! -f "$ZERO_DIR/zerod" ] && err "zerod not found in $ZERO_DIR. Build Zero first."
[ ! -f "$ZERO_DIR/zero-cli" ] && err "zero-cli not found in $ZERO_DIR. Build Zero first."

rm -rf bin/*
rm -rf artifacts/*
make distclean >/dev/null 2>&1
step_done "Cleaning"

section "Linux ($(lsb_release -rs 2>/dev/null || echo 'build'))"

run_dotranslations >/dev/null
$QMAKE zero-qt-wallet.pro -spec linux-clang CONFIG+=release > /dev/null
step_done "Configuring"

rm -rf bin/zero-qt-wallet* > /dev/null
rm -rf bin/zerowallet* > /dev/null
make clean > /dev/null
make -j"${JOBS:-2}" > /dev/null
step_done "Building"

if ldd zerowallet | grep -qi "Qt"; then
    err "release build requires static Qt; found dynamic Qt linkage"
fi
step_done "Static link"

mkdir -p "bin/zerowallet-v${APP_VERSION}"
strip zerowallet

cp zerowallet                     "bin/zerowallet-v${APP_VERSION}/" > /dev/null
cp "$ZERO_DIR/zerod"              "bin/zerowallet-v${APP_VERSION}/" > /dev/null
cp "$ZERO_DIR/zero-cli"           "bin/zerowallet-v${APP_VERSION}/" > /dev/null
cp README.md                      "bin/zerowallet-v${APP_VERSION}/" > /dev/null
cp LICENSE                        "bin/zerowallet-v${APP_VERSION}/" > /dev/null

(cd bin && tar czf "linux-zerowallet-v${APP_VERSION}.tar.gz" "zerowallet-v${APP_VERSION}/" >/dev/null 2>&1) || err "tar failed"

mkdir -p artifacts
mkdir -p release
cp "bin/linux-zerowallet-v${APP_VERSION}.tar.gz" "./artifacts/linux-zerowallet-v${APP_VERSION}.tar.gz"
step_done "Packaging"

[ ! -f "artifacts/linux-zerowallet-v${APP_VERSION}.tar.gz" ] && err "tar.gz artifact not created"
"$SCRIPT_DIR/package-verify.sh" --linux "artifacts/linux-zerowallet-v${APP_VERSION}.tar.gz"
step_done "Package contents"

debdir="bin/deb/zerowallet-v${APP_VERSION}"
mkdir -p "$debdir"
mkdir -p "$debdir/DEBIAN"
mkdir -p "$debdir/usr/local/bin"

sed "s/RELEASE_VERSION/$APP_VERSION/g" src/scripts/control > "$debdir/DEBIAN/control"

cp zerowallet                   "$debdir/usr/local/bin/"

strip "$ZERO_DIR/zerod"
strip "$ZERO_DIR/zero-cli"

cp "$ZERO_DIR/zerod"            "$debdir/usr/local/bin/zerod"
cp "$ZERO_DIR/zero-cli"         "$debdir/usr/local/bin/zero-cli"

mkdir -p                        "$debdir/usr/share/pixmaps/"
cp res/zero.xpm                 "$debdir/usr/share/pixmaps/"

mkdir -p                        "$debdir/usr/share/applications"
cp src/scripts/desktopentry     "$debdir/usr/share/applications/zerowallet.desktop"

dpkg-deb --build                "$debdir" >/dev/null
cp "${debdir}.deb"              "artifacts/linux-zerowallet-v${APP_VERSION}.deb"
step_done "Building deb"
