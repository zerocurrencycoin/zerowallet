#!/bin/bash
# Copyright 2026 Zero Developers
# Compile .ts → .qm (lrelease), then merge Qt base translations (lconvert).
# .qm files are platform-independent; used by all mkrelease builds.
# Rebuild by default. Use -t/--tran (mkrelease) or DOTRANSLATIONS_SKIP=1 to turn translations off.
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="dotranslations"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

[ -z "${QT_PREFIX:-}" ] && err "QT_PREFIX not set. Set -q/--qt or QT_PREFIX, or run from mkrelease script."

# Skip only when -t/--tran (DOTRANSLATIONS_SKIP) and .qm are fresh
if [ -n "${DOTRANSLATIONS_SKIP:-}" ]; then
  need_rebuild=0
  for ts in res/zero_qt_wallet_*.ts; do
    [ -f "$ts" ] || continue
    qm="${ts%.ts}.qm"
    if [ ! -f "$qm" ] || [ "$ts" -nt "$qm" ]; then
      need_rebuild=1
      break
    fi
  done
  if [ "$need_rebuild" = 0 ] && ls res/*.qm 1>/dev/null 2>&1; then
    notice "Translations off, skipping lrelease (-t/--tran)"
    exit 0
  fi
fi

rm -f res/*.qm
"$QT_PREFIX/bin/lrelease" zero-qt-wallet.pro

# Merge Qt base translations into app translations
for qm in res/*.qm; do
  [ -e "$qm" ] || continue
  language="$(echo "$qm" | awk -F '[_.]' '{print $4}')"
  if [ -f "$QT_PREFIX/translations/qtbase_${language}.qm" ]; then
    "$QT_PREFIX/bin/lconvert" -o "res/zero_qt_wallet_${language}.qm" "$QT_PREFIX/translations/qtbase_${language}.qm" "res/zero_qt_wallet_${language}.qm"
  fi
done
