#!/bin/bash
set -e -u -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034
ME="dotranslations"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/fbuild.sh"

[ -z "$QT_PREFIX" ] && err "QT_PREFIX not set. Set Qt install prefix, or run from mkrelease script."

rm -f res/*.qm
"$QT_PREFIX/bin/lrelease" zero-qt-wallet.pro

# Then update the qt base translations. First, get all languages
for qm in res/*.qm; do
  [ -e "$qm" ] || continue
  language=$(echo "$qm" | awk -F '[_.]' '{print $4}')
  if [ -f "$QT_PREFIX/translations/qtbase_${language}.qm" ]; then
    "$QT_PREFIX/bin/lconvert" -o "res/zero_qt_wallet_${language}.qm" "$QT_PREFIX/translations/qtbase_${language}.qm" "res/zero_qt_wallet_${language}.qm"
  fi
done
