#!/bin/bash
# Run from repo root. Builds libsodium for Windows (MXE).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src/scripts"
ME="buildlibsodium-win"
. "$SCRIPT_DIR/lib-log.sh"

[ -f res/libsodium.a ] && rm res/libsodium.a

notice "Building libsodium..."

# Go into the lib sodium directory
cd res/libsodium
if [ ! -f libsodium-1.0.21.tar.gz ]; then
    wget https://download.libsodium.org/libsodium/releases/libsodium-1.0.21.tar.gz
fi

if [ ! -d win ]; then
    mkdir win
    tar -C ./win -xf libsodium-1.0.21.tar.gz
else
    rm -r win/libsodium-1.0.21
    tar -C ./win -xf libsodium-1.0.21.tar.gz
fi

# Now build it
cd ./win/libsodium-1.0.21

export HOST=x86_64-w64-mingw32
CXX=x86_64-w64-mingw32-g++-posix
CC=x86_64-w64-mingw32-gcc-posix
PREFIX="$(pwd)/depends/$HOST"

LIBS="" ./configure --prefix="${PREFIX}" --host=x86_64-w64-mingw32 CC="${CC} -g " CXX="${CXX} -g " > /dev/null

make clean > /dev/null 2>&1
make > /dev/null 2>&1

cd ..
cd ..

# copy the library to the parents's res/ folder
cp win/libsodium-1.0.21/src/libsodium/.libs/libsodium.a ../
