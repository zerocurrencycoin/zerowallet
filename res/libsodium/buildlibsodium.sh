#!/bin/bash
cd "$(dirname "$0")/../.."
set -e

# First thing to do is see if libsodium.a exists in the res folder. If it does, then there's nothing to do
if [ -f res/libsodium.a ]; then
    rm res/libsodium.a
    rm -rf res/libsodium/libsodium-1.0.21
fi

echo "Building libsodium"

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
    echo "ERROR: libsodium.a not found after build"
    exit 1
fi
