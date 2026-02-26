#!/bin/bash
# Linux + Windows release in one run. DEPRECATED: use mkrelease-linux and mkrelease-win separately.
# Must run on Linux (host); Windows via MXE cross-build.
[ "$(uname -s)" = "Linux" ] || { echo "mkrelease-linuxwin: ERROR: must run on Linux." >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ME="mkrelease-linuxwin"
. "$SCRIPT_DIR/lib-log.sh"

# Parse args (env vars override). Zero outputs Linux and Windows to different dirs.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -z|--zero) ZERO_DIR="$2"; shift 2 ;;  # legacy: sets both
    --zerolinux) ZERO_DIR_LINUX="$2"; shift 2 ;;
    --zerowin) ZERO_DIR_WIN="$2"; shift 2 ;;
    -v|--version) APP_VERSION="$2"; shift 2 ;;
    -p|--prev) PREV_VERSION="$2"; shift 2 ;;
    -q|--qt) QT_STATIC="$2"; shift 2 ;;
    -m|--mxe) MXE_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Default: ../Zero; if absent, ../ZeroLinux / ../ZeroWin. Binaries in src/
for _base in "../Zero" "../ZeroLinux"; do [ -d "$_base" ] && break; done
ZERO_DIR_LINUX="${ZERO_DIR_LINUX:-${ZERO_DIR:-$_base/src}}"
for _base in "../Zero" "../ZeroWin"; do [ -d "$_base" ] && break; done
ZERO_DIR_WIN="${ZERO_DIR_WIN:-${ZERO_DIR:-$_base/src}}"

[ -z "$QT_STATIC" ] && err "QT_STATIC not set. Use -q/--qt or set env."
[ -z "$APP_VERSION" ] && err "APP_VERSION not set. Use -v/--version or set env."
[ -z "$PREV_VERSION" ] && err "PREV_VERSION not set. Use -p/--prev or set env."
[ ! -f "$ZERO_DIR_LINUX/zerod" ] && err "zerod not found in $ZERO_DIR_LINUX. Build Zero for Linux first."
[ ! -f "$ZERO_DIR_LINUX/zero-cli" ] && err "zero-cli not found in $ZERO_DIR_LINUX. Build Zero for Linux first."

sed -i "s/${PREV_VERSION}/${APP_VERSION}/g" zero-qt-wallet.pro >/dev/null
sed -i "s/${PREV_VERSION}/${APP_VERSION}/g" README.md >/dev/null
step_done "Version files"

rm -rf bin/*
rm -rf artifacts/*
make distclean >/dev/null 2>&1
step_done "Cleaning"

section "Linux ($(lsb_release -rs 2>/dev/null || echo 'build'))"

./src/scripts/dotranslations.sh >/dev/null
$QT_STATIC/bin/qmake zero-qt-wallet.pro -spec linux-clang CONFIG+=release >/dev/null
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

# MXE: ~/mxe, /opt/mxe (build-from-source only)
if [ -z "$MXE_PATH" ]; then
  for p in "$HOME/mxe/usr/bin" /opt/mxe/usr/bin; do
    [ -x "$p/x86_64-w64-mingw32.static-qmake-qt5" ] && { MXE_PATH="$p"; break; }
  done
  MXE_PATH="${MXE_PATH:-$HOME/mxe/usr/bin}"
fi
if [ -z "$MXE_PATH" ] || [ ! -d "$MXE_PATH" ]; then
    warn "MXE_PATH not found. Default: \$HOME/mxe/usr/bin. Use -m/--mxe to override."
    notice "Skipping Windows build"
    exit 0
fi

[ ! -f "$ZERO_DIR_WIN/zerod.exe" ] && err "zerod.exe not found in $ZERO_DIR_WIN. Build Zero for Windows first."
[ ! -f "$ZERO_DIR_WIN/zero-cli.exe" ] && err "zero-cli.exe not found in $ZERO_DIR_WIN. Build Zero for Windows first."

export PATH=$MXE_PATH:$PATH

make clean >/dev/null
rm -f zero-qt-wallet-mingw.pro
rm -rf release/
cat zero-qt-wallet.pro | sed "s/precompile_header/release/g" | sed "s/PRECOMPILED_HEADER.*//g" > zero-qt-wallet-mingw.pro
step_done "Configuring"

res/libsodium/buildlibsodium-win.sh >/dev/null
step_done "Building libsodium"

x86_64-w64-mingw32.static-qmake-qt5 zero-qt-wallet-mingw.pro CONFIG+=release >/dev/null
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
