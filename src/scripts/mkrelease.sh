#!/bin/bash
# Wrapper: run mkrelease-<platform>.sh. Pass all args through.
# Linux -> mkrelease-linux, macOS -> mkrelease-mac, else -> mkrelease-win (cross-build from Linux)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$(uname -s)" in
  Linux)  exec "$SCRIPT_DIR/mkrelease-linux.sh" "$@" ;;
  Darwin) exec "$SCRIPT_DIR/mkrelease-mac.sh" "$@" ;;
  *)      exec "$SCRIPT_DIR/mkrelease-win.sh" "$@" ;;
esac
