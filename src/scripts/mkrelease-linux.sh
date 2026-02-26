#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ME="mkrelease-linux"
. "$SCRIPT_DIR/lib-log.sh"

# Parse args (env vars override)
while [[ $# -gt 0 ]]; do
  case "$1" in
    -z|--zero) ZERO_DIR="$2"; shift 2 ;;
    -v|--version) APP_VERSION="$2"; shift 2 ;;
    -p|--prev) PREV_VERSION="$2"; shift 2 ;;
    -q|--qt) QT_STATIC="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Default: ../Zero; if absent, ../ZeroLinux. Binaries in src/
if [ -z "$ZERO_DIR" ]; then
  ZERO_BASE="../Zero"
  [ -d "$ZERO_BASE" ] || ZERO_BASE="../ZeroLinux"
  ZERO_DIR="$ZERO_BASE/src"
fi
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
QT_STATIC="${QT_STATIC:-$REPO_ROOT/qt5-static}"

[ ! -d "$QT_STATIC" ] || [ ! -x "$QT_STATIC/bin/qmake" ] && err "QT_STATIC not found at $QT_STATIC. Run ./src/scripts/build-qt-static.sh first, or set -q/--qt."

# Version defaults: APP from src/version.h, PREV from git tag (vN.N.N or N.N.N). If same, .h not updated: use git for -p, bump patch for -v.
valid_semver() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }
get_app_from_h() { grep -E '^#define APP_VERSION "[0-9]+\.[0-9]+\.[0-9]+"' src/version.h 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'; }
get_git_tag()  { git describe --tags --abbrev=0 2>/dev/null | sed 's/^[vV]//' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1; }
patch_plus1()  { echo "$1" | awk -F. -v OFS=. '{$3++; print}'; }
patch_minus1() { echo "$1" | awk -F. -v OFS=. '{c=$3-1; if(c<0){c=0; $2--}; if($2<0)$2=0; print $1,$2,c}'; }

APP_H=$(get_app_from_h)
GIT_V=$(get_git_tag)

if [ -z "$APP_VERSION" ]; then
  [ -z "$APP_H" ] && err "src/version.h has no valid #define APP_VERSION \"X.Y.Z\". Use -v."
  if [ -n "$GIT_V" ] && [ "$APP_H" = "$GIT_V" ]; then
    APP_VERSION=$(patch_plus1 "$APP_H")
    PREV_VERSION="${PREV_VERSION:-$GIT_V}"
    notice "version.h unchanged ($APP_H == git tag); using -v $APP_VERSION -p $GIT_V"
  else
    APP_VERSION="$APP_H"
    PREV_VERSION="${PREV_VERSION:-$(patch_minus1 "$APP_H")}"
    [ -n "$GIT_V" ] && notice "version.h updated ($APP_H); using -v $APP_VERSION -p $PREV_VERSION (git: $GIT_V)"
  fi
fi
valid_semver "$APP_VERSION" || err "APP_VERSION invalid format (need X.Y.Z): $APP_VERSION"
[ -z "$PREV_VERSION" ] && PREV_VERSION=$(patch_minus1 "$APP_VERSION")
valid_semver "$PREV_VERSION" || err "PREV_VERSION invalid format (need X.Y.Z): $PREV_VERSION"

[ ! -f "$ZERO_DIR/zerod" ] && err "zerod not found in $ZERO_DIR. Build Zero first."
[ ! -f "$ZERO_DIR/zero-cli" ] && err "zero-cli not found in $ZERO_DIR. Build Zero first."

# Replace the version number in the .pro file so it gets picked up everywhere
sed -i "s/${PREV_VERSION}/${APP_VERSION}/g" zero-qt-wallet.pro > /dev/null
sed -i "s/${PREV_VERSION}/${APP_VERSION}/g" README.md > /dev/null
step_done "Version files"

rm -rf bin/*
rm -rf artifacts/*
make distclean >/dev/null 2>&1
step_done "Cleaning"

section "Linux ($(lsb_release -rs 2>/dev/null || echo 'build'))"

./src/scripts/dotranslations.sh >/dev/null
$QT_STATIC/bin/qmake zero-qt-wallet.pro -spec linux-clang CONFIG+=release > /dev/null
step_done "Configuring"

rm -rf bin/zero-qt-wallet* > /dev/null
rm -rf bin/zerowallet* > /dev/null
make clean > /dev/null
make -j${JOBS:-2} > /dev/null
step_done "Building"

if [[ $(ldd zerowallet | grep -i "Qt") ]]; then
    err "release build requires static Qt; found dynamic Qt linkage"
fi
step_done "Static link"

mkdir bin/zerowallet-v$APP_VERSION > /dev/null
strip zerowallet

cp zerowallet                     bin/zerowallet-v$APP_VERSION > /dev/null
cp $ZERO_DIR/zerod               bin/zerowallet-v$APP_VERSION > /dev/null
cp $ZERO_DIR/zero-cli            bin/zerowallet-v$APP_VERSION > /dev/null
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

strip $ZERO_DIR/zerod
strip $ZERO_DIR/zero-cli

cp $ZERO_DIR/zerod             $debdir/usr/local/bin/zerod
cp $ZERO_DIR/zero-cli          $debdir/usr/local/bin/zero-cli

mkdir -p                        $debdir/usr/share/pixmaps/
cp res/zero.xpm                 $debdir/usr/share/pixmaps/

mkdir -p                        $debdir/usr/share/applications
cp src/scripts/desktopentry     $debdir/usr/share/applications/zerowallet.desktop

dpkg-deb --build                $debdir >/dev/null
cp $debdir.deb                  artifacts/linux-zerowallet-v$APP_VERSION.deb
step_done "Building deb"
