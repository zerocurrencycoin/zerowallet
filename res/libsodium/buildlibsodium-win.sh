#!/bin/bash

# First thing to do is see if libsodium.a exists in the res folder. If it does, then there's nothing to do
if [ -f res/libsodium.a ]; then
    rm res/libsodium.a
fi

echo "Building libsodium"

# Go into the lib sodium directory
cd res/libsodium
if [ ! -f libsodium-1.0.16.tar.gz ]; then
    wget https://download.libsodium.org/libsodium/releases/old/libsodium-1.0.16.tar.gz
fi

if [ ! -d win ]; then
    mkdir win
    tar -C ./win -xf libsodium-1.0.16.tar.gz
fi

# Now build it
cd ./win/libsodium-1.0.16

export HOST=x86_64-w64-mingw32
CXX=x86_64-w64-mingw32-g++-posix
CC=x86_64-w64-mingw32-gcc-posix
PREFIX="$(pwd)/depends/$HOST"

LIBS="" ./configure --prefix="${PREFIX}" --host=x86_64-w64-mingw32 CC="${CC} -g " CXX="${CXX} -g " > /dev/null

make clean > /dev/null
make > /dev/null

cd ..
cd ..

# copy the library to the parents's res/ folder
cp win/libsodium-1.0.16/src/libsodium/.libs/libsodium.a ../
