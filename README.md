Desktop wallet for Zero Currency ($ZER) that runs on Linux, Windows and MacOS.

# Installation

Releases page has the latest [installers and binaries](https://github.com/zerocurrencycoin/zerowallet/releases).

## zerod

zerowallet needs `zerod`, Zero full node process running. If one is not already running, zerowallet will start it.

If this is the first time you're running `zerowallet`, it will download the Zcash cryptographic params (~1.7 GB) and configure desktop user defaults in `zero.conf`.
`
Option `--no-embedded` forces zerowallet to connect to a running `zerod` full node process.

## Compiling from source

zerowallet is written in C++ 14, and can be compiled with g++/clang++/visual c++. It also depends on Qt5, [available from](https://www.qt.io/download). Note that building zerod from source [is a separate task](https://github.com/zerocurrencycoin/Zero#-building).

### Building on Linux

```
sudo apt-get install qt5-default qt5-qmake libqt5websockets5-dev
git clone https://github.com/zerocurrencycoin/zerowallet.git
cd zerowallet
qmake zero-qt-wallet.pro CONFIG+=debug
make -j$(nproc)

./zerowallet
```

### Building on Windows

You need Visual Studio 2017 (The free C++ Community Edition works just fine).

From the VS Tools command prompt
```
git clone  https://github.com/zerocurrencycoin/zerowallet.git
cd zerowallet
c:\Qt5\bin\qmake.exe zero-qt-wallet.pro -spec win32-msvc CONFIG+=debug
nmake

debug\zerowallet.exe
```

To create the Visual Studio project files, in order to compile and run in Visual Studio:
```
c:\Qt5\bin\qmake.exe zero-qt-wallet.pro -tp vc CONFIG+=debug
```

### Building on MacOS

Install the Xcode app with the command line tools first, and then install Qt.

```
git clone https://github.com/zerocurrencycoin/zerowallet.git
cd zerowallet
qmake zero-qt-wallet.pro CONFIG+=debug
make

./zerowallet.app/Contents/MacOS/zerowallet
```

#### Emulating the embedded node

In binary releases, zerowallet will launch `zerod` executable in the current directory.
To simulate this in a developer setup on Linux, assuming zerowallet and zero git repos are in the same directory, place symbolic links in `zerowallet/src`

```
    ln -s ../zero/src/zerod
    ln -s ../zero/src/zero-cli
```

### Support

For support or other questions, Join [Discord](https://discordapp.com/invite/Jq5knn5), or tweet at [@zerocurrencies](https://twitter.com/zerocurrencies) or [file an issue](https://github.com/zerocurrencycoin/zerowallet/issues).

🔒 Security Warnings
-----------------
[Backup your wallet](https://github.com/zerocurrencycoin/Zero/wiki/Wallet-Backup) often and keep it safe and secret.

See important [Security Information](https://z.cash/support/security/).

**Zero is very much experimental and a work in progress.** Use it at your own risk.
