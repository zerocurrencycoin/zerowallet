#!/bin/bash
cd "$(dirname "$0")/../.."
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src/scripts"
ME="buildlibsodium"
. "$SCRIPT_DIR/lib-log.sh"

[ -f res/libsodium.a ] && { rm res/libsodium.a; rm -rf res/libsodium/libsodium-1.0.21; }

notice "Building libsodium..."

# Go into the lib sodium directory
cd res/libsodium
if [ ! -f libsodium-1.0.21.tar.gz ]; then
    wget https://download.libsodium.org/libsodium/releases/libsodium-1.0.21.tar.gz
fi

if [ ! -d libsodium-1.0.21 ]; then
    tar xf libsodium-1.0.21.tar.gz
fi

# Now build it
cd libsodium-1.0.21
LIBS="" ./configure > /dev/null
make clean > /dev/null 2>&1
if [[ "$OSTYPE" == "darwin"* ]]; then
    make CFLAGS="-mmacosx-version-min=10.11" CPPFLAGS="-mmacosx-version-min=10.11" > /dev/null 2>&1
else
    make > /dev/null 2>&1
fi
cd ..

# copy the library to res/ folder
if [ -f libsodium-1.0.21/src/libsodium/.libs/libsodium.a ]; then
    cp libsodium-1.0.21/src/libsodium/.libs/libsodium.a ../
elif [ -f libsodium-1.0.21/.libs/libsodium.a ]; then
    cp libsodium-1.0.21/.libs/libsodium.a ../
else
    err "libsodium.a not found after build"
fi
