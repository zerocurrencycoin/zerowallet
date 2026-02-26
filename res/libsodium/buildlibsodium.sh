#!/bin/bash
cd "$(dirname "$0")/../.."
set -e -u -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src/scripts"
ME="buildlibsodium"
. "$SCRIPT_DIR/fbuild.sh"
. "res/libsodium/libsodium-common.sh"

[ -f res/libsodium.a ] && { rm res/libsodium.a; rm -rf res/libsodium/libsodium-${LIBSODIUM_VER}; }

notice "Building libsodium..."

cd res/libsodium
libsodium_download

if [ ! -d "libsodium-${LIBSODIUM_VER}" ]; then
    tar xf "$LIBSODIUM_TAR"
fi

cd "libsodium-${LIBSODIUM_VER}"
LIBS="" ./configure > /dev/null
make clean > /dev/null 2>&1
if [[ "$OSTYPE" == "darwin"* ]]; then
    make CFLAGS="-mmacosx-version-min=10.11" CPPFLAGS="-mmacosx-version-min=10.11" > /dev/null 2>&1
else
    make > /dev/null 2>&1
fi
cd ..

if [ -f "libsodium-${LIBSODIUM_VER}/src/libsodium/.libs/libsodium.a" ]; then
    cp "libsodium-${LIBSODIUM_VER}/src/libsodium/.libs/libsodium.a" ../
elif [ -f "libsodium-${LIBSODIUM_VER}/.libs/libsodium.a" ]; then
    cp "libsodium-${LIBSODIUM_VER}/.libs/libsodium.a" ../
else
    err "libsodium.a not found after build"
fi
