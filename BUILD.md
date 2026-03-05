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

One-time install per platform. Custom path via `-q` or `QT_STATIC` only when needed.

| Platform | Source | Install |
|----------|--------|---------|
| **Linux** | Static Qt 5.15.18+ from [Qt archives](https://download.qt.io/archive/qt/5.15/5.15.18/single/) | Build from source |
| **macOS** | Homebrew `qt@5` | `brew install qt@5`. Default: `$(brew --prefix qt@5)`. |
| **Windows** | MXE (cross-build) | See [Windows](#windows) below. |

---

## Script Reference

| Script | Platform | Output |
|--------|----------|--------|
| `mkrelease-linux.sh` | Linux | `artifacts/linux-zerowallet-vX.Y.Z.tar.gz`, `.deb` |
| `mkrelease-mac.sh` | macOS | `artifacts/macOS-zerowallet-vX.Y.Z.dmg` |
| `mkrelease-win.sh` | Windows | `artifacts/Windows-zerowallet-vX.Y.Z.zip` |
| `mkrelease.sh` | Linux + Windows | Both in one run (requires MXE for Windows) |
| `signbinaries.sh` | Any | GPG signatures and sha256sums |

### Unified Arguments

| Flag | Env | Default | Description |
|------|-----|---------|-------------|
| `-z`, `--zero` | `ZERO_DIR` | `../Zero/src` | Directory with zerod binaries; see [ZERO_DIR](#zero_dir) below |
| `-v`, `--version` | `APP_VERSION` | — | Release version. Must match `src/version.h`. Required. See [APP_VERSION](#app_version) below. |
| `-p`, `--prev` | `PREV_VERSION` | — | Previous version. Required for Linux/Windows. Not used by macOS. See [PREV](#prev) below. |
| `-q`, `--qt` | `QT_STATIC` | see Qt table | Qt prefix |
| `-m`, `--mxe` | `MXE_PATH` | — | MXE `usr/bin` (Windows only) |

### APP_VERSION

Can extract from `src/version.h` (run from repo root):

```
APP_VERSION=$(grep -o '"[0-9.]*"' src/version.h | tr -d '"')
```

Canonical tag format `vN.N.N` is trivial to recognize; `git describe --tags --abbrev=0` or `git tag -l 'v*.*.*' | tail -1` for tag-based extraction.

### ZERO_DIR

Directory containing built `zerod` and `zero-cli` (or `.exe` on Windows). Not the Zero source tree. Default `../Zero/src`; **macOS auto-detects** `../ZeroMac/src`, `../ZeroLinux/src`, `../ZeroWin/src` if `zerod` exists. Override with `-z` or `ZERO_DIR`. zerowallet packages copy binaries at build time; no zerod source in zerowallet. Scripts strip only the copies in the package dir; originals in `ZERO_DIR` are never modified. See [Stripping](#stripping).


### Stripping

- **Linux / Windows (zerowallet release):** mkrelease copies binaries into the package directory, then runs `strip` on those copies only. Originals in `ZERO_DIR` are never modified. Use `-s` or `--no-strip` to skip (larger packages).
- **macOS:** The system `strip` command removes symbol tables to reduce size; often used for release after debugging. mkrelease-mac optionally strips ZeroWallet.app/Contents/MacOS/* before signing (for experiments). For signed/notarized release use -s or --no-strip: stripping can complicate or invalidate code signatures. Default is to strip; use -s when building for distribution.
- **Direct zerod distribution (standalone node):** Whether and how to strip zerod/zero-cli for official node tarballs or installers is **TBD** (not yet documented or standardized here).

### PREV

Linux and Windows scripts use `sed` to replace the previous version with the new one in `zero-qt-wallet.pro`, `README.md`, and (Linux) `src/scripts/control` before packaging. macOS does not: `mkrelease-mac.sh` reads `version.h` for the DMG name only and does not modify those files.

---

## Platform Notes

### Linux

Build zerod: `cd ../Zero && ./zcutil/build.sh -j$(nproc)`. Then:

```bash
./src/scripts/mkrelease-linux.sh -v X.Y.Z -p X.Y.(Z-1) -q $QT_STATIC
```

### macOS

**Prerequisites:** `brew install create-dmg qt@5`. zerod built in Zero repo. `ZERO_DIR` auto-detects `../ZeroMac/src`, `../ZeroLinux/src`, `../ZeroWin/src`, or `../Zero/src`; override with `-z` when Zero is elsewhere.

**Tooling:** Qt from Homebrew (`$(brew --prefix qt@5)`). `macdeployqt` copies Qt frameworks/plugins into the app bundle. `create-dmg` builds the DMG. `codesign` signs the app (ad-hoc or Developer ID). `xcrun notarytool` and `xcrun stapler` for notarization.

---

**1. Dev build**

For development. Produces `zerowallet.app` with symlinks to Homebrew Qt; not standalone. Run from build dir.

```bash
make distclean && make
./zerowallet.app/Contents/MacOS/zerowallet
```

Test a Release build (`artifacts/ZeroWallet.app` or DMG) for standalone verification.

---

**2. Release (ad-hoc signing)**

For distribution without notarization. Script: clean → qmake → make → copy zerod/zero-cli into app → macdeployqt → codesign (ad-hoc) → create-dmg. Ad-hoc uses `CODESIGN_IDENTITY=-` or unset.

```bash
./src/scripts/mkrelease-mac.sh -v X.Y.Z
```

Output: `artifacts/macOS-zerowallet-vX.Y.Z.dmg`, `artifacts/ZeroWallet.app`.

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

**Status: tentative; subject to change.** Cross-build from Linux or WSL; both require test and validation. Build zerod: `cd ../Zero && ./zcutil/build-win.sh -j$(nproc)`. Run `mkrelease-win.sh` with `-z`, `-v`, `-p`, `-m` (MXE path). Requires [MXE](#mxe).

#### MXE

[MXE](https://mxe.cc/) (M Cross Environment) for MinGW + static Qt. Clone to `~/mxe`; `make MXE_TARGETS='x86_64-w64-mingw32.static' qtbase qtwebsockets` (2–4 h). Set `MXE_PATH` to `usr/bin`. Build: `./src/scripts/mkrelease-win.sh -z $ZERO_DIR -v X.Y.Z -p X.Y.(Z-1) -m $MXE_PATH`

### Precompiled headers (PCH)

**What `precompiled.h` does:** A precompiled header is a C++ header file (e.g. `src/precompiled.h`) that the compiler parses once and caches. All `.cpp` files that include it reuse that cache instead of re-parsing the same includes. This speeds up builds. Our `precompiled.h` pulls in common Qt headers (QApplication, QWidget, etc.), nlohmann/json, libsodium, and other shared includes. Source files include it via `#include "precompiled.h"` at the top.

**Where PRECOMPILED_HEADER is used:**

| Platform | .pro file | PCH |
|----------|------------|-----|
| Linux | `zero-qt-wallet.pro` | ✓ enabled |
| macOS | `zero-qt-wallet.pro` | ✓ enabled |
| Windows (MinGW) | `zero-qt-wallet-mingw.pro` (generated) | ✗ stripped |

**Why Windows strips it:** `mkdev-win.sh` and `mkrelease-win.sh` generate `zero-qt-wallet-mingw.pro` with `sed '/PRECOMPILED_HEADER/d'` to remove the `PRECOMPILED_HEADER = src/precompiled.h` line. PCH has historically caused issues with MinGW cross-compilation (include paths, defines, toolchain quirks). Stripping avoids those failures.

**Trying PCH with ZeroWin:** To test whether current MXE/Qt/MinGW supports PCH, one would stop stripping the PRECOMPILED_HEADER line and keep `precompile_header` in CONFIG when generating the mingw .pro. **Postponed** — no trial planned until needed.

---

## Signing

### GPG (all platforms)

Run `./src/scripts/signbinaries.sh -v X.Y.Z`; produces `sha256sum-vX.Y.Z.txt` and `*.sig` in `artifacts/`, packaged as `signatures-vX.Y.Z.zip`. Verification: `sha256sum -c sha256sum-vX.Y.Z.txt`; `gpg --verify <file.sig> <file>`. Import key from `public_key.asc` on GitHub. See `res/SIGNATURES_README`.


