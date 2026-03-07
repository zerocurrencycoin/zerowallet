#!/bin/bash
# Copyright 2026 Zero Developers
set -e -u -o pipefail
# Wrapper: run mkdev-<platform>.sh. Pass all args through.
# Linux -> mkdev-linux, macOS -> mkdev-mac, else -> mkdev-win (Windows target, cross-build from Linux)
# shellcheck disable=SC2034
ME="mkdev"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
case "$(uname -s)" in
  Linux)  exec "$SCRIPT_DIR/mkdev-linux.sh" "$@" ;;
  Darwin) exec "$SCRIPT_DIR/mkdev-mac.sh" "$@" ;;
  *)      exec "$SCRIPT_DIR/mkdev-win.sh" "$@" ;;
esac
