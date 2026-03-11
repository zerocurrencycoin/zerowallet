# Changelog

All notable changes to zerowallet (desktop) are recorded here. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (X.Y.Z). For the Zero full node and chain parameters, see the Zero repo and ZeroChain.md.

---

## [Unreleased]

### Added
- **Linux release:** Option to build with system Qt (dynamic link): `-S`/`--systemqt` and `USE_SYSTEM_QT`. Use when static Qt is not required.
- **macOS release:** Option to also produce `.tgz` of app bundle: `-T`/`--tgz` and `MAKE_TGZ`. Output: `artifacts/macOS-zerowallet-vX.Y.Z.tgz`.
- **qt-report.sh:** Unified message format (repo path, platform, qmake/qt5-static/MXE, one-line summary). Unknown platform: single warning; no multi-platform dump. Linux summary conditional on qt5-static and MXE readiness.
- **Helpers:** Scripts now source `fbuild.sh` for shared logic: qt-report, install_mxe, mkrelease.sh, mkdev.sh. `check_file` in fbuild; package-verify uses it. signbinaries uses `get_app_from_h` when APP_VERSION unset (version from `src/version.h`).
- **Practice scripts:** `build-qt-static-modular.sh` (modular download: qtbase + qtwebsockets only, ~50MB). `build-qt-static-skip-extra.sh` (single tarball with extra `-skip` to build only qtbase + qtwebsockets). Output dirs: `qt5-static-modular/install`, `qt5-static-skip/install`.

### Changed
- **Option naming:** Long options `--systemqt`, `--nostrip` (replacing `--system-qt`, `--no-strip`) in scripts and docs.
- **Packages:** LICENSE no longer included in release packages (tgz, deb, zip). Contents: zerowallet binary, zerod, zero-cli, README.md.
- **mkrelease.sh / mkdev.sh:** Source fbuild.sh; use SCRIPT_DIR from fbuild. Dispatch wording in docs (no "by host").
- **Error handling (mkrelease-mac):** Explicit `|| err '...'` for cp zerod/zero-cli, mv app, macdeployqt, codesign, create-dmg, and tgz steps.

### Documentation
- **BUILD.md:** System status table; Helpers row; Artifacts table with Linux release Qt subsection (-q static path, -S system Qt); Build outcomes (mkdev); checking Linux binaries (stripped, ldd, five Qt libs, .pro vs ldd); explicit link list vs ldd; signing (version from -v or version.h).
- **UpdateWallet.md:** Linux Qt (static or system Qt, release flow); modular vs single Qt (download/build); practice scripts and how to test; Windows example without LICENSE.
- **ZeroChain.md:** Format and content guidelines proposed (chain history, parameters, performance, audiences).

---

## [4.0.0]

(Existing release; add versioned entries here when tagging. Example:)

### Added
- Desktop wallet for Zero Currency (Linux, macOS, Windows). Bundles zerod; Qt5 UI.

---

## Guidelines for maintainers

- **Scope:** zerowallet (desktop) only. Zero full node changes belong in the Zero repo changelog.
- **Sections:** Use Added, Changed, Deprecated, Removed, Fixed, Security, Build & Release, Documentation as needed. Omit empty sections.
- **Platform releases:** When cutting Linux/macOS/Windows releases, ensure CHANGELOG [Unreleased] is moved into a versioned section and tagged (e.g. v4.0.1).
- **Concision:** One line per item where possible; link to BUILD.md or UpdateWallet.md for detail.
