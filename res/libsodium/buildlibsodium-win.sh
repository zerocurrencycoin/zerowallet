#!/bin/bash
set -e -u -o pipefail
# Run from repo root. Builds libsodium for Windows (MXE).
# Matches Zero depends/packages/libsodium.mk: 1.0.21, same URLs.
# Optional: ZERO_DEPENDS=/path/to/Zero/depends to copy from Zero's build (skip rebuild).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src/scripts"
ME="buildlibsodium-win"
. "$SCRIPT_DIR/fbuild.sh"

[ -f res/libsodium.a ] && rm res/libsodium.a

# Share with Zero: copy from Zero's depends if available
if [ -n "${ZERO_DEPENDS:-}" ] && [ -f "$ZERO_DEPENDS/x86_64-w64-mingw32/lib/libsodium.a" ]; then
    notice "Copying libsodium from Zero depends ($ZERO_DEPENDS)"
    cp "$ZERO_DEPENDS/x86_64-w64-mingw32/lib/libsodium.a" res/
    cp res/libsodium.a res/libsodiumd.a
    cp res/libsodium.a res/liblibsodium.a
    cp res/libsodiumd.a res/liblibsodiumd.a
    exit 0
fi

notice "Building libsodium..."

cd res/libsodium
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/res/libsodium/libsodium-common.sh"
libsodium_download

if [ ! -d win ]; then
    mkdir win
    tar -C ./win -xf "$LIBSODIUM_TAR"
else
    rm -rf win/libsodium-${LIBSODIUM_VER}
    tar -C ./win -xf "$LIBSODIUM_TAR"
fi

# Now build it
cd "./win/libsodium-${LIBSODIUM_VER}"

export HOST=x86_64-w64-mingw32
# MXE: x86_64-w64-mingw32.static-gcc (not Debian gcc-posix)
CC=$(command -v x86_64-w64-mingw32.static-gcc 2>/dev/null)
[ -n "$CC" ] || { echo "buildlibsodium-win: x86_64-w64-mingw32.static-gcc not found. MXE in PATH?" >&2; exit 1; }
CXX="${CC%gcc}g++"
PREFIX="$(pwd)/depends/$HOST"

LIBS="" ./configure --prefix="${PREFIX}" --host=x86_64-w64-mingw32 CC="${CC} -g" CXX="${CXX} -g" > /dev/null

make clean > /dev/null 2>&1
make > /dev/null 2>&1

cd ..
cd ..

# copy the library to the parent's res/ folder
cp "win/libsodium-${LIBSODIUM_VER}/src/libsodium/.libs/libsodium.a" ../
# debug build links -llibsodiumd; provide libsodiumd.a (same lib)
cp ../libsodium.a ../libsodiumd.a
# MinGW -llibsodium looks for liblibsodium.a
cp ../libsodium.a ../liblibsodium.a
cp ../libsodiumd.a ../liblibsodiumd.a
