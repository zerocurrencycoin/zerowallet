#!/bin/bash
# Copyright 2026 Zero Developers
set -e -u -o pipefail
# Wrapper: run mkrelease-<platform>.sh. Pass all args through.
# Linux -> mkrelease-linux, macOS -> mkrelease-mac, else -> mkrelease-win (Windows target, cross-build from Linux)
# shellcheck disable=SC2034
ME="mkrelease"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
case "$(uname -s)" in
  Linux)  exec "$SCRIPT_DIR/mkrelease-linux.sh" "$@" ;;
  Darwin) exec "$SCRIPT_DIR/mkrelease-mac.sh" "$@" ;;
  *)      exec "$SCRIPT_DIR/mkrelease-win.sh" "$@" ;;
esac
