#!/bin/bash
set -e -u -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ME="dotranslations"
. "$SCRIPT_DIR/fbuild.sh"

[ -z "$QT_PREFIX" ] && err "QT_PREFIX not set. Set Qt install prefix, or run from mkrelease script."

rm -f res/*.qm
$QT_PREFIX/bin/lrelease zero-qt-wallet.pro

# Then update the qt base translations. First, get all languages
ls res/*.qm | awk -F '[_.]' '{print $4}' | while read -r language ; do
    if [ -f $QT_PREFIX/translations/qtbase_$language.qm ]; then
        $QT_PREFIX/bin/lconvert -o res/zero_qt_wallet_$language.qm $QT_PREFIX/translations/qtbase_$language.qm res/zero_qt_wallet_$language.qm
        #mv res/zero-qt-wallet_$language.qm res/zero-qt-wallet_$language.qm
    fi
done
