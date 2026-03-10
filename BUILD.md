# Build and Release Guide

Build and release workflow for zerowallet. Platforms: Linux, macOS, Windows.

For release preparation: see [CHANGELOG.md](CHANGELOG.md) (versioned changes), [ZeroChain.md](ZeroChain.md) and [ZeroCoin.md](ZeroCoin.md) (chain/coin reference formats). Scope and document policy: [SCOPE.md](SCOPE.md).

## System status

| Area | Status |
|------|--------|
| **Platforms** | Linux (native), macOS (native), Windows (cross-build from Linux via MXE). |
| **Qt — Linux** | Dev: system Qt (mkdev-linux). Release: default static Qt (qt5-static from build-qt-static.sh); optional system Qt with `-S`/`--systemqt`. |
| **Qt — macOS** | Dev and release: system Qt (Homebrew qt@5). macdeployqt bundles Qt; no static build. |
| **Qt — Windows** | MXE only (Linux host). Target selected by script: `mkrelease-linux` vs `mkrelease-win`. |
| **Options** | Env overrides CLI. Key: `QT_PREFIX`, `USE_SYSTEM_QT`, `MXE_PATH`, `ZERO_DIR`, `SKIP_STRIP`, `SKIP_SIGN`, `MAKE_TGZ`, `LOG_FILE`, `JOBS`. Long options: `--systemqt`, `--nostrip`, `--tgz`. |
| **Helpers** | `fbuild.sh`: SCRIPT_DIR, REPO_ROOT, err/warn/notice/step_done, check_file, check_zero_binaries, resolve_qt, get_app_from_h, resolve_version, parse_mkrelease_args, etc. qt-report, install_mxe, mkrelease.sh, mkdev.sh source fbuild; signbinaries uses get_app_from_h when APP_VERSION unset. |
| **Reporting** | `./src/scripts/qt-report.sh` — Qt setup per platform (repo path, qmake/qt5-static/MXE, one-line summary). |

## Quick Start

**System prerequisites:**

- **Linux:** Dev: `sudo apt install build-essential qtbase5-dev qtbase5-dev-tools libqt5websockets5-dev`. Release: static Qt (see [UpdateWallet](UpdateWallet.md) §Linux Qt packaging and modules).
- **macOS:** `brew install create-dmg qt@5`
- **Windows:** Cross-build from Linux; see [Windows](#windows) below.

Build zerod in the Zero repo, then run the platform mkrelease script. See [ZERO_DIR](#zero_dir) and [Platform Notes](#platform-notes).

---

## Dependencies

| Component | Version / Source | Notes |
|-----------|------------------|-------|
| Qt | 5.15.18 or later | See [Qt](#qt) below. |
| zerod | Zero | Built from [Zero](https://github.com/zerocurrencycoin/zero); binaries in `ZERO_DIR` |
| libsodium | 1.0.21 | Vendored in `res/` |
| nlohmann/json | 3.6.1 | Vendored in `src/3rdparty/` |
| SingleApplication | v3.5.4 vendored | `singleapplication/`; single-instance, URI forwarding |

Qt is the only versioned external dependency; others are vendored.

### Qt

One-time install per platform. Custom path via `-q` or `QT_PREFIX` when needed.

| Platform | Source | Install |
|----------|--------|---------|
| **Linux** | Static Qt or system Qt | Release: default static (build-qt-static → qt5-static); optional `-S`/`--systemqt` for system Qt (dynamic). See [UpdateWallet](UpdateWallet.md) §Linux Qt. |
| **macOS** | Homebrew `qt@5` | `brew install qt@5`. Default: `$(brew --prefix qt@5)`. |
| **Windows** | MXE (cross-build) | See [Windows](#windows) below. |

---

## Script Reference

| Script | Platform | Output |
|--------|----------|--------|
| `mkrelease-linux.sh` | Linux | `artifacts/linux-zerowallet-vX.Y.Z.tgz`, `.deb` |
| `mkrelease-mac.sh` | macOS | `artifacts/macOS-zerowallet-vX.Y.Z.dmg`; optional `-T`/`--tgz` → also `artifacts/macOS-zerowallet-vX.Y.Z.tgz` |
| `mkrelease-win.sh` | Windows | `artifacts/Windows-zerowallet-vX.Y.Z.zip` |
| `mkrelease.sh` | — | Dispatches to `mkrelease-linux.sh`, `mkrelease-mac.sh`, or `mkrelease-win.sh` |
| `mkdev.sh` | — | Dispatches to `mkdev-{linux,mac,win}.sh` |
| `signbinaries.sh` | Any | GPG signatures and sha256sums |

### Artifacts (mkrelease)

| Script | Artifacts (X.Y.Z = APP_VERSION) |
|--------|----------------------------------|
| **mkrelease-linux.sh** | `artifacts/linux-zerowallet-vX.Y.Z.tgz` (dir: zerowallet, zerod, zero-cli, README.md); `artifacts/linux-zerowallet-vX.Y.Z.deb`. Qt: see [Linux release Qt](#linux-release-qt) below. |
| **mkrelease-mac.sh** | `artifacts/macOS-zerowallet-vX.Y.Z.dmg` (signed app bundle). With `-T`/`--tgz`: `artifacts/macOS-zerowallet-vX.Y.Z.tgz` (dir: ZeroWallet.app, README.md). |
| **mkrelease-win.sh** | `artifacts/Windows-zerowallet-vX.Y.Z.zip` (dir: zerowallet.exe, zerod.exe, zero-cli.exe, README.md). |

### Build outcomes (mkdev)

| Script | Output | Notes |
|--------|--------|--------|
| **mkdev-linux.sh** | `zerowallet` (repo root) | System Qt, CONFIG+=debug by default; `-r` → release. Run: `./zerowallet`. |
| **mkdev-mac.sh** | `ZeroWallet.app` (repo root) | System Qt, debug or release. Dev build leaves object files in `bin/`; final binary is ZeroWallet.app. Run: `open ZeroWallet.app`. |
| **mkdev-win.sh** | `debug/zerowallet.exe` or `release/zerowallet.exe` | Default debug; `-r` → release. Requires MXE on Linux host. Run: `wine …/zerowallet.exe`. |

#### Linux release Qt {#linux-release-qt}

Default: **static Qt** used for the release binary. Either (1) build it in-repo with `./src/scripts/build-qt-static.sh` (creates `qt5-static/`), or (2) point to an existing static Qt with **`-q` / `QT_PREFIX`** — e.g. `mkrelease-linux.sh -q /path/to/qt5-static` (any prefix where `bin/qmake` and the static libs exist). The script uses that Qt’s `qmake` to build; the resulting zerowallet is statically linked to Qt.

With **`-S` / `--systemqt`** (or **`USE_SYSTEM_QT=1`**): use **system Qt** (installed via package manager, e.g. `apt install qtbase5-dev`). The script uses `qmake` from `PATH` and sets `QT_PREFIX` from `qmake -query QT_INSTALL_PREFIX` for lrelease/translations. The release binary is dynamically linked to Qt; the static-link check is skipped.

### Unified Arguments

| Flag | Env | Default | Description |
|------|-----|---------|-------------|
| `-z`, `--zero` | `ZERO_DIR` | `../Zero/src` | Directory with zerod binaries; see [ZERO_DIR](#zero_dir) below |
| `-v`, `--version` | `APP_VERSION` | from `version.h` / git | Release version (X.Y.Z). Override when not using default. See [APP_VERSION](#app_version) below. |
| `-p`, `--prev` | `PREV_VERSION` | derived from `-v` or `version.h` | Previous version (Linux/Windows sed). Not used by macOS. See [PREV](#prev) below. |
| `-q`, `--qt` | `QT_PREFIX` | see Qt table | Qt prefix (mkdev/mkrelease) |
| `-S`, `--systemqt` | `USE_SYSTEM_QT` | — | Linux release with system Qt (dynamic link). Default: static Qt (qt5-static or -q). |
| `-P`, `--nostrip` | — | — | Skip stripping release binaries (larger artifacts; symbols kept). Default: strip on Linux, macOS, Windows. |
| `-N`, `--no-sign` | — | — | Ad-hoc sign only (macOS; no developer identity). App is always signed so it runs; default uses `CODESIGN_IDENTITY` or ad-hoc. |
| `-L`, `--log` | `LOG_FILE` | script-specific | Capture build/release log (e.g. `logs/mkrelease-mac.log`). mkdev and mkrelease support `-L` or `-L=PATH`. |
| `-T`, `--tgz` | `MAKE_TGZ` | — | Also create .tgz of app bundle (macOS only). |
| `-m`, `--mxe` | `MXE_PATH` | — | MXE `usr/bin` (Windows only) |

### APP_VERSION

Can extract from `src/version.h` (run from repo root):

```
APP_VERSION=$(grep -o '"[0-9.]*"' src/version.h | tr -d '"')
```

Canonical tag format `vN.N.N` is trivial to recognize; `git describe --tags --abbrev=0` or `git tag -l 'v*.*.*' | tail -1` for tag-based extraction.

### ZERO_DIR

Directory containing built `zerod` and `zero-cli` (or `.exe` on Windows). **Default:** `../Zero/src`. If that directory is missing or empty, fallback by platform: **mac** → `../ZeroMac/src`, **linux** → `../ZeroLinux/src`, **win** → `../ZeroWin/src`. Override with `-z` or `ZERO_DIR`. zerowallet packages copy binaries at build time; no zerod source in zerowallet. **Stripping:** Linux, macOS, and Windows strip by default (copies only; originals in `ZERO_DIR` unchanged); `-P`/`--nostrip` to skip.

### PREV

Linux and Windows scripts use `sed` to replace the previous version with the new one in `zero-qt-wallet.pro`, `README.md`, and (Linux) `src/scripts/control` before packaging. macOS does not: `mkrelease-mac.sh` reads `version.h` for the DMG name only and does not modify those files.

---

## Platform Notes

### Linux

Build zerod: `cd ../Zero && ./zcutil/build.sh`. Then run `./src/scripts/mkrelease-linux.sh`. **Qt for release:** default is static Qt built locally — run `./src/scripts/build-qt-static.sh` once (creates qt5-static/) or pass `-q /path/to/qt-prefix`; or use `-S`/`--systemqt` for system Qt (installed via package manager, not built in repo; dynamic link). Output: `artifacts/linux-zerowallet-vX.Y.Z.tgz`, `artifacts/linux-zerowallet-vX.Y.Z.deb`. Full Linux Qt build, packaging options, and module list: [UpdateWallet](UpdateWallet.md) §Linux Qt packaging and modules.

**Checking Linux binaries (stripped, linking, Qt):** Extract the tgz or use the built binary in repo root. **Stripped:** `file zerowallet` — reports `stripped` or `not stripped`. **Dynamic libraries:** `ldd zerowallet` — lists all shared libs. When linked to Qt dynamically the executable depends directly on **five** Qt5 libs: `libQt5Core.so.5`, `libQt5Gui.so.5`, `libQt5Network.so.5`, `libQt5WebSockets.so.5`, `libQt5Widgets.so.5`. Everything else in `ldd` (libGL, libpng, libicu, libharfbuzz, libxcb, etc.) is either a transitive dependency of those or the C/runtime (libc, libstdc++, ld-linux). Paths in `ldd` are the runtime Qt libs (e.g. `/lib/x86_64-linux-gnu/` = system Qt). If linked to Qt statically there are no `libQt5*` lines. **Which Qt (static):** determined at build time (qt5-static or `-q`).

**Explicit link list vs ldd:** In `zero-qt-wallet.pro` no Qt libraries are listed in `LIBS`. Qt is declared only as **QT += core gui network widgets websockets** (five modules); qmake adds the corresponding `-lQt5Core -lQt5Gui -lQt5Network -lQt5WebSockets -lQt5Widgets`. The only library explicitly in `LIBS` is **libsodium** (`-L$$PWD/res/ -lsodium` on Unix; vendored `res/libsodium.a`). So the five Qt libs in `ldd` match the five `QT +=` modules; all other `ldd` entries are transitive (from Qt or system) or runtime.

### macOS

**Prerequisites:** `brew install create-dmg qt@5`. zerod built in Zero repo. `ZERO_DIR` defaults to `../Zero/src` if non-empty, else `../ZeroMac/src`; override with `-z` when Zero is elsewhere.

**Tooling:** Qt from Homebrew (`$(brew --prefix qt@5)`). `macdeployqt` copies Qt frameworks/plugins into the app bundle. `create-dmg` builds the DMG. `codesign` signs the app (ad-hoc or Developer ID). `xcrun notarytool` and `xcrun stapler` for notarization.

---

**1. Dev build**

For development. Produces `ZeroWallet.app` (in repo root) with symlinks to Homebrew Qt; not standalone. Run from repo root.

```bash
./src/scripts/mkdev.sh
open ZeroWallet.app
# or: ./ZeroWallet.app/Contents/MacOS/ZeroWallet
```

Or: `make distclean && make` (after qmake). Use `mkdev.sh -c` to force clean before build.

Test a Release build (`artifacts/ZeroWallet.app` or DMG) for standalone verification.

---

**2. Release (ad-hoc signing)**

For distribution without notarization. Script: clean → qmake → make → copy zerod/zero-cli into app → macdeployqt → strip (unless `-P`) → codesign (always; ad-hoc if `-N` or unset) → move app to `artifacts/` → create-dmg. The script prints signing mode (`Signing (ad-hoc)` or `Signing (identity: …)`). Ad-hoc is the default; set `CODESIGN_IDENTITY` for Developer ID. Use `-L` to capture log.

```bash
./src/scripts/mkrelease-mac.sh
```

To pin version: `-v X.Y.Z`. To capture log: `-L`.

Output: `artifacts/ZeroWallet.app`, `artifacts/macOS-zerowallet-vX.Y.Z.dmg`. Use `-T`/`--tgz` to also create `artifacts/macOS-zerowallet-vX.Y.Z.tgz`. The script prints DMG format and size (e.g. `DMG: UDZO, 24MB`); format should be **UDZO** (compressed). If the DMG is unexpectedly large or format is not UDZO, ensure zerod in `ZERO_DIR` was built release and stripped. If create-dmg fails, the app is already in `artifacts/`; re-run with `CREATE_DMG_VERBOSE=1` to see full output.

**Test before distribute:** (replace X.Y.Z with the version just built)
```bash
hdiutil attach artifacts/macOS-zerowallet-vX.Y.Z.dmg -nobrowse -quiet
codesign -dv --verbose=2 "/Volumes/ZeroWallet-vX.Y.Z/ZeroWallet.app"
open "/Volumes/ZeroWallet-vX.Y.Z/ZeroWallet.app"
# If Gatekeeper blocks: right-click → Open. Drag to Applications, verify.
hdiutil detach "/Volumes/ZeroWallet-vX.Y.Z"
```

**User install:** Mount DMG → drag app to Applications → if blocked, right-click → Open.

---

**3. Developer ID + notarization**

For distribution that passes Gatekeeper without user override. Requires Apple Developer account.

**Build and sign:**
```bash
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
./src/scripts/mkrelease-mac.sh
```
Optional: `-v X.Y.Z` to pin version.

**Notarize:**
```bash
# One-time: create keychain profile (app-specific password from appleid.apple.com)
xcrun notarytool store-credentials --apple-id <email> --team-id <id> --password <app-specific-password>

# Submit, wait for approval, staple (replace X.Y.Z with your version)
xcrun notarytool submit artifacts/macOS-zerowallet-vX.Y.Z.dmg --keychain-profile <profile>
# ... wait ...
xcrun stapler staple artifacts/macOS-zerowallet-vX.Y.Z.dmg
```

**User install:** Mount DMG → drag to Applications. No Gatekeeper override needed.

[Notarizing](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution) · [Developer ID](https://developer.apple.com/developer-id/) · [Gatekeeper](https://developer.apple.com/documentation/security/gatekeeper_and_notarization)

### Windows

**Status: tentative; subject to change.** Cross-build from Linux or WSL; both require test and validation. Build zerod: `cd ../Zero && ./zcutil/build-win.sh`. Requires [MXE](#mxe); pass `-m $MXE_PATH` (MXE `usr/bin`). Override zerod path with `-z`, version with `-v`/`-p`.

#### MXE

[MXE](https://mxe.cc/) (M Cross Environment) for MinGW + static Qt. Clone to `~/mxe`; `make MXE_TARGETS='x86_64-w64-mingw32.static' qtbase qtwebsockets` (2–4 h). Set `MXE_PATH` to `usr/bin`. Build: `./src/scripts/mkrelease-win.sh -m $MXE_PATH`

---

## Troubleshooting

| Issue | Platform | Solution |
|-------|----------|----------|
| `__OPTIMIZE__ predefined macro was enabled in PCH file but is currently disabled` | macOS | PCH built with different CONFIG (debug vs release). Run `./src/scripts/mkdev.sh -c -L` to force clean and rebuild. |
| DMG not created / create-dmg fails | macOS | By default create-dmg runs with `--hdiutil-quiet`. To see full hdiutil/create-dmg stderr, re-run with `CREATE_DMG_VERBOSE=1 ./src/scripts/mkrelease-mac.sh`. Check disk space and "File exists" (remove existing `artifacts/macOS-zerowallet-v*.dmg`); app is in `artifacts/ZeroWallet.app` if create-dmg failed. |

---

## Signing

### GPG (all platforms)

Run `./src/scripts/signbinaries.sh` (version from `-v X.Y.Z` or `src/version.h`); produces `sha256sum-vX.Y.Z.txt` and `*.sig` in `artifacts/`, packaged as `signatures-vX.Y.Z.zip`. Verification: `sha256sum -c sha256sum-vX.Y.Z.txt`; `gpg --verify <file.sig> <file>`. Import key from `public_key.asc` on GitHub. See `res/SIGNATURES_README`.

### Package verification

After mkrelease, run `./src/scripts/package-verify.sh` to check archive contents (required files present, structure). Use `-v X.Y.Z` to verify artifacts for that version, or `--linux` / `--windows` / `--mac` with a path. See script `-h` for options.


