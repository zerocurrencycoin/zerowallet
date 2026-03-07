#!/bin/bash
# Copyright 2026 Zero Developers
# Release build for Linux: static Qt, .tgz + deb.
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="mkrelease-linux"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

parse_mkrelease_args "logs/mkrelease-linux.log" "$@"
[ -n "${LOG_FILE:-}" ] && exec > >(tee -a "${LOG_FILE}") 2>&1
resolve_zero_dir linux
resolve_qt linux release
[ ! -x "${QMAKE:-}" ] && err "Qt not found. Use -q /path/to/qt-prefix (static Qt), run build-qt-static.sh for qt5-static/, or -S/--systemqt for system Qt."

resolve_version
check_version_mismatch
apply_version_sed

check_zero_binaries linux

rm -rf bin/*
make distclean >/dev/null 2>&1 || true
step_done 'Cleaning'

section "Linux ($(lsb_release -rs 2>/dev/null || echo 'build'))"

run_dotranslations >/dev/null
$QMAKE zero-qt-wallet.pro -spec linux-g++ CONFIG+=release >/dev/null
step_done 'Configuring'

rm -rf bin/zero-qt-wallet* >/dev/null
rm -rf bin/zerowallet* >/dev/null
make clean >/dev/null
make -j"${JOBS:-2}" >/dev/null
step_done 'Building'

if [ -z "${USE_SYSTEM_QT:-}" ]; then
  if ldd zerowallet | grep -qi "Qt"; then
    err 'release build requires static Qt; found dynamic Qt linkage (use -S/--systemqt for system Qt)'
  fi
  step_done 'Static link'
else
  step_done 'System Qt (dynamic link)'
fi

tgzdir="bin/tgz/linux-zerowallet-v${APP_VERSION}"
mkdir -p "$tgzdir"

notice "ZERO_DIR=${ZERO_DIR} (zerod: $(stat -c %s "${ZERO_DIR}/zerod" 2>/dev/null) bytes)"
cp -f zerowallet                     "$tgzdir/" >/dev/null
cp -f "$ZERO_DIR/zerod"              "$tgzdir/" >/dev/null
cp -f "$ZERO_DIR/zero-cli"           "$tgzdir/" >/dev/null
cp -f README.md                      "$tgzdir/" >/dev/null
cp -f LICENSE                        "$tgzdir/" >/dev/null
[ -z "${SKIP_STRIP:-}" ] && strip "$tgzdir/zerowallet" "$tgzdir/zerod" "$tgzdir/zero-cli"

(cd bin/tgz && tar czf "linux-zerowallet-v${APP_VERSION}.tgz" "linux-zerowallet-v${APP_VERSION}/" >/dev/null 2>&1) || err 'tar failed'

mkdir -p artifacts
mkdir -p release
cp -f "bin/tgz/linux-zerowallet-v${APP_VERSION}.tgz" "./artifacts/linux-zerowallet-v${APP_VERSION}.tgz"
step_done 'Packaging'

[ ! -f "artifacts/linux-zerowallet-v${APP_VERSION}.tgz" ] && err 'tgz artifact not created'
"$SCRIPT_DIR/package-verify.sh" --linux "artifacts/linux-zerowallet-v${APP_VERSION}.tgz"
step_done 'Package contents'

debdir="bin/deb/zerowallet-v${APP_VERSION}"
mkdir -p "$debdir"
mkdir -p "$debdir/DEBIAN"
mkdir -p "$debdir/usr/local/bin"

sed "s/RELEASE_VERSION/$APP_VERSION/g" src/scripts/control > "$debdir/DEBIAN/control"

cp -f zerowallet                   "$debdir/usr/local/bin/"
cp -f "$ZERO_DIR/zerod"            "$debdir/usr/local/bin/zerod"
cp -f "$ZERO_DIR/zero-cli"         "$debdir/usr/local/bin/zero-cli"
[ -z "${SKIP_STRIP:-}" ] && strip "$debdir/usr/local/bin/zerowallet" "$debdir/usr/local/bin/zerod" "$debdir/usr/local/bin/zero-cli"

mkdir -p                        "$debdir/usr/share/doc/zero-qt-wallet"
cp -f README.md                    "$debdir/usr/share/doc/zero-qt-wallet/README.md"

mkdir -p                        "$debdir/usr/share/pixmaps/"
cp -f res/zero.xpm                 "$debdir/usr/share/pixmaps/"

mkdir -p                        "$debdir/usr/share/applications"
cp -f src/scripts/desktopentry     "$debdir/usr/share/applications/zerowallet.desktop"

dpkg-deb --build                "$debdir" >/dev/null
cp -f "${debdir}.deb"              "artifacts/linux-zerowallet-v${APP_VERSION}.deb"
step_done 'Building deb'
