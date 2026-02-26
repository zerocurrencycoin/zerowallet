#!/bin/bash
set -e -u -o pipefail
# Linux + Windows release in one run. DEPRECATED: use mkrelease-linux and mkrelease-win separately.
# Must run on Linux (host); Windows via MXE cross-build.
[ "$(uname -s)" = "Linux" ] || { echo "mkrelease-linuxwin: ERROR: must run on Linux." >&2; exit 1; }

ME="mkrelease-linuxwin"
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

# Parse args (env vars override). Zero outputs Linux and Windows to different dirs.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -z|--zero) ZERO_DIR="$2"; shift 2 ;;
    --zerolinux) ZERO_DIR_LINUX="$2"; shift 2 ;;
    --zerowin) ZERO_DIR_WIN="$2"; shift 2 ;;
    -v|--version) APP_VERSION="$2"; shift 2 ;;
    -p|--prev) PREV_VERSION="$2"; shift 2 ;;
    -q|--qt) QT_PREFIX="$2"; shift 2 ;;
    -m|--mxe) MXE_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

resolve_zero_dirs_linuxwin
resolve_qt linux release

[ -z "$QT_PREFIX" ] && err "QT_PREFIX not set. Use -q/--qt or set env."
[ -z "$APP_VERSION" ] && err "APP_VERSION not set. Use -v/--version or set env."
[ -z "$PREV_VERSION" ] && err "PREV_VERSION not set. Use -p/--prev or set env."
[ ! -f "$ZERO_DIR_LINUX/zerod" ] && err "zerod not found in $ZERO_DIR_LINUX. Build Zero for Linux first."
[ ! -f "$ZERO_DIR_LINUX/zero-cli" ] && err "zero-cli not found in $ZERO_DIR_LINUX. Build Zero for Linux first."

check_version_mismatch
apply_version_sed

rm -rf bin/*
rm -rf artifacts/*
make distclean >/dev/null 2>&1
step_done "Cleaning"

section "Linux ($(lsb_release -rs 2>/dev/null || echo 'build'))"

./src/scripts/dotranslations.sh >/dev/null
$QMAKE zero-qt-wallet.pro -spec linux-clang CONFIG+=release >/dev/null
step_done "Configuring"

rm -rf bin/zero-qt-wallet* >/dev/null
rm -rf bin/zerowallet* >/dev/null
make clean >/dev/null
make -j${JOBS:-2} >/dev/null
step_done "Building"

if [[ $(ldd zerowallet | grep -i "Qt") ]]; then
    err "release build requires static Qt; found dynamic Qt linkage"
fi
step_done "Static link"

mkdir bin/zerowallet-v$APP_VERSION > /dev/null
strip zerowallet

cp zerowallet                     bin/zerowallet-v$APP_VERSION > /dev/null
cp $ZERO_DIR_LINUX/zerod          bin/zerowallet-v$APP_VERSION > /dev/null
cp $ZERO_DIR_LINUX/zero-cli       bin/zerowallet-v$APP_VERSION > /dev/null
cp README.md                      bin/zerowallet-v$APP_VERSION > /dev/null
cp LICENSE                        bin/zerowallet-v$APP_VERSION > /dev/null

cd bin && tar czf linux-zerowallet-v$APP_VERSION.tar.gz zerowallet-v$APP_VERSION/ > /dev/null
cd ..

mkdir artifacts >/dev/null 2>&1
mkdir release >/dev/null 2>&1
cp bin/linux-zerowallet-v$APP_VERSION.tar.gz ./artifacts/linux-zerowallet-v$APP_VERSION.tar.gz
step_done "Packaging"

[ ! -f artifacts/linux-zerowallet-v$APP_VERSION.tar.gz ] && err "tar.gz artifact not created"
tar tf "artifacts/linux-zerowallet-v$APP_VERSION.tar.gz" | wc -l | grep -q "6" || err "package contents incomplete"
step_done "Package contents"

debdir=bin/deb/zerowallet-v$APP_VERSION
mkdir -p $debdir > /dev/null
mkdir    $debdir/DEBIAN
mkdir -p $debdir/usr/local/bin

cat src/scripts/control | sed "s/RELEASE_VERSION/$APP_VERSION/g" > $debdir/DEBIAN/control

cp zerowallet                   $debdir/usr/local/bin/

strip $ZERO_DIR_LINUX/zerod
strip $ZERO_DIR_LINUX/zero-cli

cp $ZERO_DIR_LINUX/zerod       $debdir/usr/local/bin/zerod
cp $ZERO_DIR_LINUX/zero-cli    $debdir/usr/local/bin/zero-cli

mkdir -p                        $debdir/usr/share/pixmaps/
cp res/zero.xpm                 $debdir/usr/share/pixmaps/

mkdir -p                        $debdir/usr/share/applications
cp src/scripts/desktopentry     $debdir/usr/share/applications/zerowallet.desktop

dpkg-deb --build                $debdir >/dev/null
cp $debdir.deb                  artifacts/linux-zerowallet-v$APP_VERSION.deb
step_done "Building deb"

section "Windows"

resolve_qt win release
if [ -z "$MXE_PATH" ] || [ ! -d "$MXE_PATH" ]; then
    warn "MXE_PATH not found. Default: \$HOME/mxe/usr/bin. Use -m/--mxe to override."
    notice "Skipping Windows build"
    exit 0
fi

[ ! -f "$ZERO_DIR_WIN/zerod.exe" ] && err "zerod.exe not found in $ZERO_DIR_WIN. Build Zero for Windows first."
[ ! -f "$ZERO_DIR_WIN/zero-cli.exe" ] && err "zero-cli.exe not found in $ZERO_DIR_WIN. Build Zero for Windows first."

make clean >/dev/null
rm -f zero-qt-wallet-mingw.pro
rm -rf release/
cat zero-qt-wallet.pro | sed "s/precompile_header/release/g" | sed "s/PRECOMPILED_HEADER.*//g" > zero-qt-wallet-mingw.pro
step_done "Configuring"

res/libsodium/buildlibsodium-win.sh >/dev/null
step_done "Building libsodium"

$QMAKE zero-qt-wallet-mingw.pro CONFIG+=release >/dev/null
make -j${JOBS:-2} >/dev/null
step_done "Building"

mkdir release/zerowallet-v$APP_VERSION > /dev/null 2>&1
cp release/zerowallet.exe             release/zerowallet-v$APP_VERSION > /dev/null
cp $ZERO_DIR_WIN/zerod.exe            release/zerowallet-v$APP_VERSION > /dev/null
cp $ZERO_DIR_WIN/zero-cli.exe         release/zerowallet-v$APP_VERSION > /dev/null
cp README.md                          release/zerowallet-v$APP_VERSION > /dev/null
cp LICENSE                            release/zerowallet-v$APP_VERSION > /dev/null
cd release && zip -r Windows-zerowallet-v$APP_VERSION.zip zerowallet-v$APP_VERSION/ > /dev/null
cd ..

mkdir artifacts >/dev/null 2>&1
cp release/Windows-zerowallet-v$APP_VERSION.zip ./artifacts/
step_done "Packaging"

[ ! -f artifacts/Windows-zerowallet-v$APP_VERSION.zip ] && err "Windows zip artifact not created"
unzip -l "artifacts/Windows-zerowallet-v$APP_VERSION.zip" | wc -l | grep -q "11" || err "package contents incomplete"
step_done "Package contents"
