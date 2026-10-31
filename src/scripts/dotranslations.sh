#!/bin/bash
# Copyright 2026 Zero Developers
# Compile .ts → .qm (lrelease), then merge Qt base translations (lconvert).
# .qm files are platform-independent; used by all mkrelease builds.
# Default: skipped by mkrelease (reuse res/*.qm). Use -t (mkrelease) to rebuild.
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="dotranslations"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

[ -z "${QT_PREFIX:-}" ] && err 'QT_PREFIX not set. Use mkrelease -t with -q PATH, or install qtbase5-dev-tools.'

LRELEASE="${QT_LRELEASE:-$QT_PREFIX/bin/lrelease}"
LCONVERT="${QT_LCONVERT:-$QT_PREFIX/bin/lconvert}"
QT_TRANSLATIONS_DIR="${QT_TRANSLATIONS_DIR:-$QT_PREFIX/translations}"
[ -x "$LRELEASE" ] || err "lrelease not found (QT_PREFIX=${QT_PREFIX})"
[ -x "$LCONVERT" ] || LCONVERT="$(command -v lconvert 2>/dev/null || true)"
[ -x "$LCONVERT" ] || err "lconvert not found"

rm -f res/*.qm
"$LRELEASE" zero-qt-wallet.pro

# Merge Qt base translations into app translations
for qm in res/*.qm; do
  [ -e "$qm" ] || continue
  language="$(echo "$qm" | awk -F '[_.]' '{print $4}')"
  if [ -f "$QT_TRANSLATIONS_DIR/qtbase_${language}.qm" ]; then
    "$LCONVERT" -o "res/zero_qt_wallet_${language}.qm" "$QT_TRANSLATIONS_DIR/qtbase_${language}.qm" "res/zero_qt_wallet_${language}.qm"
  fi
done
