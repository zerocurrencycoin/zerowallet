export QT_STATIC="/home/cryptoforge/Qt/static/5.14.2"
export APP_VERSION="1.0.0"
export PREV_VERSION="0.0.0"

export ZCASH_DIR_LINUX="/home/cryptoforge/Dev/zero_dev/zero/src"
export ZCASH_DIR_WINDOWS="/home/cryptoforge/Dev/zero_dev/zero_win/src"

export ZCASH_DIR="/home/cryptoforge/Dev/ZeroRelease"

export MXE_PATH="/home/cryptoforge/mxe/usr/bin"

cp $ZCASH_DIR_LINUX/zerod           $ZCASH_DIR/zerod
cp $ZCASH_DIR_LINUX/zero-cli        $ZCASH_DIR/zero-cli
cp $ZCASH_DIR_WINDOWS/zerod.exe     $ZCASH_DIR/zerod.exe
cp $ZCASH_DIR_WINDOWS/zero-cli.exe  $ZCASH_DIR/zero-cli.exe

strip $ZCASH_DIR/zerod
strip $ZCASH_DIR/zero-cli
strip $ZCASH_DIR/zerod.exe
strip $ZCASH_DIR/zero-cli.exe

./src/scripts/mkrelease.sh
