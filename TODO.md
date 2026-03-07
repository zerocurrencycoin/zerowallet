# TODO

User-facing items decided for implementation, with clear design and timelines. To contribute, see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Active

*None at this time.*

---

## Completed

- **qt-report.sh:** Unified message format (repo, platform, qmake/qt5-static/MXE lines, one-line summary). Unknown platform: single warn, no multi-platform dump. Linux summary conditional (Linux/Windows target ready; mkrelease-linux vs mkrelease-win).
- **Linux release:** Option to build with system Qt: `-S`/`--systemqt` and `USE_SYSTEM_QT`; `resolve_qt` uses system qmake and `QT_INSTALL_PREFIX`; mkrelease-linux skips static-link check when set.
- **Option naming:** Long options `--systemqt`, `--nostrip` (docs and help aligned).
- **BUILD.md:** System status table; Qt table and unified args updated for Linux system Qt and `--nostrip`.
- **qt-report:** Validated (syntax, run on macOS in zerowalletmac).
- **mkrelease-mac:** Reviewed strip (optional via `SKIP_STRIP`), signing (always; `SKIP_SIGN` → ad-hoc), DMG (explicit err on failure). Added `-T`/`--tgz` / `MAKE_TGZ` to also produce `artifacts/macOS-zerowallet-vX.Y.Z.tgz` (dir: ZeroWallet.app, README.md, LICENSE). Explicit `|| err '...'` for cp zerod/zero-cli, mv app, macdeployqt, codesign, create-dmg; tgz steps (mkdir, cp, tar) and post-DMG check. Error/warning/success: fmessage.sh err/warn/notice/step_done; critical file/command failures now call err() for clear messages; set -e remains for remaining commands.
