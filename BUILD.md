# Build and Release Guide

Build and release workflow for zerowallet. Supports local builds and [GitHub Actions](.github/workflows/). Platforms: Linux, macOS, Windows.

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
| **Linux** | Static Qt 5.15.18+ from [Qt archives](https://download.qt.io/archive/qt/5.15/5.15.18/single/) | `./src/scripts/build-qt-static.sh` (local) or CI cache |
| **macOS** | Homebrew `qt@5` | `brew install qt@5`. Default: `$(brew --prefix qt@5)`. |
| **Windows** | MXE (cross-build) | See [Windows](#windows) below. |

---

## Script Reference

### src/scripts inventory

| File | Purpose |
|------|---------|
| `lib-log.sh` | Shared logging: err, warn, info, notice, analyze_build_log |
| `mkdev.sh` | Wrapper: runs mkdev-linux/mac/win per platform |
| `mkdev-linux.sh` | Linux dev build → `./zerowallet`. `-r` `-j N` `-L` |
| `mkdev-mac.sh` | macOS dev build → `zerowallet.app`. `-r` `-j N` `-L` |
| `mkdev-win.sh` | Linux→Win dev (MXE) → `release/zerowallet.exe`. `-L` `-m` |
| `mkrelease.sh` | Wrapper: runs mkrelease-linux/mac/win per platform |
| `mkrelease-linux.sh` | Linux release → `artifacts/linux-zerowallet-vX.Y.Z.tar.gz`, `.deb` |
| `mkrelease-mac.sh` | macOS release → `artifacts/macOS-zerowallet-vX.Y.Z.dmg` |
| `mkrelease-win.sh` | Linux→Win release (MXE) → `artifacts/Windows-zerowallet-vX.Y.Z.zip` |
| `mkrelease-linuxwin.sh` | Linux host only: Linux + Windows in one run (requires MXE) |
| `build-qt-static.sh` | Linux: static Qt in `qt5-static/` (one-time) |
| `dotranslations.sh` | Qt lrelease for translations (requires QT_STATIC) |
| `signbinaries.sh` | GPG signatures and sha256sums. `-v X.Y.Z` |
| `control` | Debian package control template |
| `desktopentry` | Desktop entry for Linux .deb |

### Script summary

| Script | Platform | Output |
|--------|----------|--------|
| `mkdev.sh` | Any | Wrapper: runs mkdev-linux/mac/win per platform |
| `mkdev-linux.sh` | Linux | Dev: `./zerowallet`. `-r` `-j N` `-L` |
| `mkdev-mac.sh` | macOS | Dev: `zerowallet.app`. `-r` `-j N` `-L` |
| `mkdev-win.sh` | Linux→Win | Dev: `release/zerowallet.exe` (MXE cross-build). `-L` `-m` |
| `mkrelease.sh` | Any | Wrapper: runs mkrelease-linux/mac/win per platform |
| `mkrelease-linux.sh` | Linux | `artifacts/linux-zerowallet-vX.Y.Z.tar.gz`, `.deb` |
| `mkrelease-mac.sh` | macOS | `artifacts/macOS-zerowallet-vX.Y.Z.dmg` |
| `mkrelease-win.sh` | Linux→Win | `artifacts/Windows-zerowallet-vX.Y.Z.zip` |
| `mkrelease-linuxwin.sh` | Linux only | Linux + Windows in one run (requires MXE) |
| `build-qt-static.sh` | Linux | Static Qt in `qt5-static/` (one-time) |
| `signbinaries.sh` | Any | GPG signatures and sha256sums |

### Unified Arguments

| Flag | Env | Default | Description |
|------|-----|---------|-------------|
| `-z`, `--zero` | `ZERO_DIR` | `../Zero/src` | Directory with zerod binaries; see [ZERO_DIR](#zero_dir) below |
| `-v`, `--version` | `APP_VERSION` | from `src/version.h` | Release version. See [APP_VERSION](#app_version) below. |
| `-p`, `--prev` | `PREV_VERSION` | patch−1 of APP_VERSION | Previous version for sed. See [PREV](#prev) below. |
| `-q`, `--qt` | `QT_STATIC` | `./qt5-static/` (repo root) | Qt prefix for Linux release |
| `-m`, `--mxe` | `MXE_PATH` | — | MXE `usr/bin` (Windows only) |

### APP_VERSION / PREV_VERSION

Both from `src/version.h` and git tag (supports `vN.N.N` or `N.N.N`). Logic:
- **APP_H** = `#define APP_VERSION "X.Y.Z"` (strict)
- **GIT_V** = latest `git describe --tags --abbrev=0` (strip `v`)
- If APP_H == GIT_V: .h not updated → `-p` = GIT_V, `-v` = patch+1
- If APP_H ≠ GIT_V: .h updated → `-v` = APP_H, `-p` = patch−1 of APP_H
- Bad format / missing: `SCRIPT: ERROR: ...` to stderr, exit 1. All scripts use `lib-log.sh`: err, warn, info, notice.

### ZERO_DIR

Directory containing built `zerod` and `zero-cli` (or `.exe` on Windows). Not the Zero source tree. Default `../Zero/src` assumes Zero repo as sibling; Zero build outputs to `src/` on Linux (layout may differ on Windows). Override with `-z` or `ZERO_DIR`. zerowallet packages copy binaries at build time; no zerod source in zerowallet. Stripping: Linux and Windows scripts strip binaries before packaging; macOS not stripped.

### PREV

Used by `sed` to replace the previous version in `zero-qt-wallet.pro`, `README.md`, and (Linux) `src/scripts/control`. See [APP_VERSION](#app_version) for default logic. macOS: `mkrelease-mac.sh` reads `version.h` only for DMG name.

### Log capture and failure analysis

mkdev scripts support `-L` or `-L=path` to capture build output. Default: `logs/mkdev-<platform>.log`. On build failure, `analyze_build_log` prints errors and warnings from the log. Shared: `src/scripts/lib-log.sh` (err, warn, info, notice).

---

## Platform Notes

### Linux

**Dev build:** `./src/scripts/mkdev.sh` or `./src/scripts/mkdev-linux.sh`. Options: `-r` release config, `-j N` jobs, `-L` or `-L=path` capture log to `logs/mkdev-linux.log`. On failure with `-L`, run `analyze_build_log` (errors/warnings). Output: `./zerowallet`.

**Release build (local):**

1. Build static Qt (one-time, ~30–60 min): `./src/scripts/build-qt-static.sh`. Output: `qt5-static/` in repo root.
2. Build zerod: `cd ../Zero && ./zcutil/build.sh -j$(nproc)`.
3. Run mkrelease (defaults: `-v` from `src/version.h`, `-p` = patch−1, `-q` = `./qt5-static/`):

```bash
./src/scripts/mkrelease.sh
# or directly:
./src/scripts/mkrelease-linux.sh
```

To build Linux and Windows in one run (Linux host, requires MXE): `./src/scripts/mkrelease-linuxwin.sh`.

### macOS

**Dev build:** `./src/scripts/mkdev-mac.sh`. Uses Homebrew Qt. Options: `-r` `-j N` `-L`. Output: `zerowallet.app` → `open zerowallet.app`.

**Release prerequisites:** `brew install create-dmg qt@5`. zerod built in Zero repo. Default `ZERO_DIR=../Zero/src`; override with `-z` when Zero is elsewhere.

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

**Dev build (cross from Linux):** `./src/scripts/mkdev-win.sh`. Requires [MXE](#mxe) with qtbase, qtwebsockets. Options: `-L` `-m MXE_PATH`. Output: `release/zerowallet.exe`.

**Release:** Cross-build from Linux or WSL. Build zerod: `cd ../Zero && ./zcutil/build-win.sh`. Run `mkrelease-win.sh` with `-z`, `-v`, `-p`, `-m` (MXE path). Requires [MXE](#mxe).

#### MXE

[MXE](https://mxe.cc/) (M Cross Environment) for MinGW + static Qt. Clone to `~/mxe`; `make MXE_TARGETS='x86_64-w64-mingw32.static' qtbase qtwebsockets` (2–4 h). Set `MXE_PATH` to `usr/bin`. Build: `./src/scripts/mkrelease-win.sh -z $ZERO_DIR -v X.Y.Z -p X.Y.(Z-1) -m $MXE_PATH`

---

## Signing

### GPG (all platforms)

Run `./src/scripts/signbinaries.sh -v X.Y.Z`; produces `sha256sum-vX.Y.Z.txt` and `*.sig` in `artifacts/`, packaged as `signatures-vX.Y.Z.zip`. Verification: `sha256sum -c sha256sum-vX.Y.Z.txt`; `gpg --verify <file.sig> <file>`. Import key from `public_key.asc` on GitHub. See `res/SIGNATURES_README`.

---

## CI (GitHub Actions)

Workflows [Zero Wallet Linux](.github/workflows/Zero%20Wallet%20Linux.yml) and [Zero Wallet Windows](.github/workflows/Zero%20Wallet%20Windows.yml). **Status: tentative until verified.** Clone Zero, build zerod, run mkrelease scripts, upload artifacts. Update `APP_VERSION` and `PREV_VERSION` in workflow `env` when cutting releases.

