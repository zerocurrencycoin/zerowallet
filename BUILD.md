# Build and Release Guide

Build and release workflow for zerowallet. Platforms: Linux, macOS, Windows.

## Quick Start

**System prerequisites:**

- **Linux:** `sudo apt install build-essential qtbase5-dev qtbase5-dev-tools libqt5websockets5-dev`
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
| **Linux** | Static Qt 5.15.18+ from [Qt archives](https://download.qt.io/archive/qt/5.15/5.15.18/single/) | Build from source |
| **macOS** | Homebrew `qt@5` | `brew install qt@5`. Default: `$(brew --prefix qt@5)`. |
| **Windows** | MXE (cross-build) | See [Windows](#windows) below. |

---

## Script Reference

| Script | Platform | Output |
|--------|----------|--------|
| `mkrelease-linux.sh` | Linux | `artifacts/linux-zerowallet-vX.Y.Z.tgz`, `.deb` |
| `mkrelease-mac.sh` | macOS | `artifacts/macOS-zerowallet-vX.Y.Z.dmg` |
| `mkrelease-win.sh` | Windows | `artifacts/Windows-zerowallet-vX.Y.Z.zip` |
| `mkrelease.sh` | Linux + Windows | Both in one run (requires MXE for Windows) |
| `mkdev.sh` | Linux, macOS, Windows | Dev build; `-c` clean, `-r` release, `-L` log |
| `signbinaries.sh` | Any | GPG signatures and sha256sums |

### Unified Arguments

| Flag | Env | Default | Description |
|------|-----|---------|-------------|
| `-z`, `--zero` | `ZERO_DIR` | `../Zero/src` | Directory with zerod binaries; see [ZERO_DIR](#zero_dir) below |
| `-v`, `--version` | `APP_VERSION` | — | Release version. Must match `src/version.h`. Required. See [APP_VERSION](#app_version) below. |
| `-p`, `--prev` | `PREV_VERSION` | — | Previous version. Required for Linux/Windows. Not used by macOS. See [PREV](#prev) below. |
| `-q`, `--qt` | `QT_PREFIX` | see Qt table | Qt prefix (mkdev/mkrelease) |
| `-P`, `--no-strip` | — | — | Skip stripping release binaries (larger artifacts; symbols kept). Default: strip on Linux, macOS, Windows. |
| `-N`, `--no-sign` | — | — | Ad-hoc sign only (macOS; no developer identity). App is always signed so it runs; default uses `CODESIGN_IDENTITY` or ad-hoc. |
| `-L`, `--log` | `LOG_FILE` | script-specific | Capture build/release log (e.g. `logs/mkrelease-mac.log`). mkdev and mkrelease support `-L` or `-L=PATH`. |
| `-m`, `--mxe` | `MXE_PATH` | — | MXE `usr/bin` (Windows only) |

### APP_VERSION

Can extract from `src/version.h` (run from repo root):

```
APP_VERSION=$(grep -o '"[0-9.]*"' src/version.h | tr -d '"')
```

Canonical tag format `vN.N.N` is trivial to recognize; `git describe --tags --abbrev=0` or `git tag -l 'v*.*.*' | tail -1` for tag-based extraction.

### ZERO_DIR

Directory containing built `zerod` and `zero-cli` (or `.exe` on Windows). **Default:** `../Zero/src`. If that directory is missing or empty, fallback by platform: **mac** → `../ZeroMac/src`, **linux** → `../ZeroLinux/src`, **win** → `../ZeroWin/src`. Override with `-z` or `ZERO_DIR`. zerowallet packages copy binaries at build time; no zerod source in zerowallet. **Stripping:** Linux, macOS, and Windows strip by default (copies only; originals in `ZERO_DIR` unchanged); `-P`/`--no-strip` to skip.

### PREV

Linux and Windows scripts use `sed` to replace the previous version with the new one in `zero-qt-wallet.pro`, `README.md`, and (Linux) `src/scripts/control` before packaging. macOS does not: `mkrelease-mac.sh` reads `version.h` for the DMG name only and does not modify those files.

---

## Platform Notes

### Linux

Build zerod: `cd ../Zero && ./zcutil/build.sh`. Then:

```bash
./src/scripts/mkrelease-linux.sh -v X.Y.Z -p X.Y.(Z-1) -q "$QT_PREFIX"
```

**Tarball:** Staged in `bin/tgz/linux-zerowallet-vX.Y.Z/`; output `artifacts/linux-zerowallet-vX.Y.Z.tgz`.

**Deb behavior:** mkrelease-linux produces both a .tgz and a .deb. Staging: `bin/deb/zerowallet-vX.Y.Z/`. Contents: `DEBIAN/control`, `usr/local/bin/` (zerowallet, zerod, zero-cli), README.md (from repo root), `usr/share/pixmaps/`, .desktop file. Binaries are stripped in place when not using `-P`. Output: `artifacts/linux-zerowallet-vX.Y.Z.deb`.

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

For distribution without notarization. Script: clean → qmake → make → copy zerod/zero-cli into app → macdeployqt → strip (unless `-P`) → codesign (always; ad-hoc if `-N` or unset) → move app to `artifacts/` → create-dmg. The script prints signing mode (`Signing (ad-hoc)` or `Signing (identity: …)`). Use `-N` for ad-hoc-only; without `-N`, set `CODESIGN_IDENTITY` for Developer ID. Use `-L` to capture log.

```bash
./src/scripts/mkrelease-mac.sh -v X.Y.Z
# or with logging:
./src/scripts/mkrelease-mac.sh -L -N -v X.Y.Z
```

Output: `artifacts/ZeroWallet.app`, `artifacts/macOS-zerowallet-vX.Y.Z.dmg`. The script prints DMG format and size (e.g. `DMG: UDZO, 24MB`); format should be **UDZO** (compressed). If the DMG is unexpectedly large or format is not UDZO, ensure zerod in `ZERO_DIR` was built release and stripped. If create-dmg fails, the app is already in `artifacts/`; re-run with `CREATE_DMG_VERBOSE=1` to see full output.

**Test before distribute:**
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
./src/scripts/mkrelease-mac.sh -v X.Y.Z
```

**Notarize:**
```bash
# One-time: create keychain profile (app-specific password from appleid.apple.com)
xcrun notarytool store-credentials --apple-id <email> --team-id <id> --password <app-specific-password>

# Submit, wait for approval, staple
xcrun notarytool submit artifacts/macOS-zerowallet-vX.Y.Z.dmg --keychain-profile <profile>
# ... wait ...
xcrun stapler staple artifacts/macOS-zerowallet-vX.Y.Z.dmg
```

**User install:** Mount DMG → drag to Applications. No Gatekeeper override needed.

[Notarizing](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution) · [Developer ID](https://developer.apple.com/developer-id/) · [Gatekeeper](https://developer.apple.com/documentation/security/gatekeeper_and_notarization)

### Windows

**Status: tentative; subject to change.** Cross-build from Linux or WSL; both require test and validation. Build zerod: `cd ../Zero && ./zcutil/build-win.sh`. Run `mkrelease-win.sh` with `-z`, `-v`, `-p`, `-m` (MXE path). Requires [MXE](#mxe).

#### MXE

[MXE](https://mxe.cc/) (M Cross Environment) for MinGW + static Qt. Clone to `~/mxe`; `make MXE_TARGETS='x86_64-w64-mingw32.static' qtbase qtwebsockets` (2–4 h). Set `MXE_PATH` to `usr/bin`. Build: `./src/scripts/mkrelease-win.sh -z $ZERO_DIR -v X.Y.Z -p X.Y.(Z-1) -m $MXE_PATH`

---

## Troubleshooting

| Issue | Platform | Solution |
|-------|----------|----------|
| `__OPTIMIZE__ predefined macro was enabled in PCH file but is currently disabled` | macOS | PCH built with different CONFIG (debug vs release). Run `./src/scripts/mkdev.sh -c -L` to force clean and rebuild. |
| DMG not created / create-dmg fails | macOS | By default create-dmg runs with `--hdiutil-quiet`. To see full hdiutil/create-dmg stderr, re-run with `CREATE_DMG_VERBOSE=1` (e.g. `CREATE_DMG_VERBOSE=1 ./src/scripts/mkrelease-mac.sh -L -N`). Check disk space and "File exists" (remove existing `artifacts/macOS-zerowallet-v*.dmg`); app is in `artifacts/ZeroWallet.app` if create-dmg failed. |

---

## Signing

### GPG (all platforms)

Run `./src/scripts/signbinaries.sh -v X.Y.Z`; produces `sha256sum-vX.Y.Z.txt` and `*.sig` in `artifacts/`, packaged as `signatures-vX.Y.Z.zip`. Verification: `sha256sum -c sha256sum-vX.Y.Z.txt`; `gpg --verify <file.sig> <file>`. Import key from `public_key.asc` on GitHub. See `res/SIGNATURES_README`.

### Package verification

After mkrelease, run `./src/scripts/package-verify.sh` to check archive contents (required files present, structure). Use `-v X.Y.Z` to verify artifacts for that version, or `--linux` / `--windows` / `--mac` with a path. See script `-h` for options.


