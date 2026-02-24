# Build and Release Guide

Build and release workflow for zerowallet. Supports local builds and [GitHub Actions](.github/workflows/).

## Terminology (first use)

| Term | Definition |
|------|------------|
| **zerod** | Zero Currency daemon; blockchain node and wallet backend. Built from [Zero](https://github.com/zerocurrencycoin/zero). |
| **DMG** | Disk image (`.dmg`) — macOS installer format. Users mount it and drag the app to Applications. |
| **macdeployqt** | Qt's macOS deployment tool; copies Qt frameworks and plugins into the app bundle. |
| **ZERO_DIR** | Directory containing built `zerod` and `zero-cli` binaries (not the Zero source tree). |

## Script Reference

| Script | Platform | Output |
|--------|----------|--------|
| `src/scripts/mkrelease.sh` | Linux + Windows | Both in one run |
| `src/scripts/mkrelease-linux.sh` | Linux | `artifacts/linux-zerowallet-v$APP_VERSION.tar.gz`, `.deb` |
| `src/scripts/mkrelease-win.sh` | Windows | `artifacts/Windows-zerowallet-v$APP_VERSION.zip` |
| `src/scripts/mkrelease-mac.sh` | macOS | `artifacts/macOS-zerowallet-v$APP_VERSION.dmg` |
| `src/scripts/signbinaries.sh` | Any | GPG signatures and sha256sums |

### Unified Arguments

| Flag | Env | Default | Description |
|------|-----|---------|-------------|
| `-z`, `--zero` | `ZERO_DIR` | `../Zero/src` | Directory with zerod binaries |
| `-v`, `--version` | `APP_VERSION` | — | Release version (must match `src/version.h`). Required every run; no default. |
| `-p`, `--prev` | `PREV_VERSION` | — | Previous version (for sed in .pro/README) |
| `-q`, `--qt` | `QT_STATIC` | see below | Qt path |
| `-m`, `--mxe` | `MXE_PATH` | see below | MXE `usr/bin` path (Windows) |

### Path Defaults

**ZERO_DIR:** Default `../Zero/src` — Zero repo as sibling of zerowallet, binaries in `Zero/src/` after `./zcutil/build.sh`. Override with `-z` or `ZERO_DIR`.

**QT_STATIC:**
- **macOS:** `brew --prefix qt@5` when Qt is installed via Homebrew. Override with `-q` if using a custom Qt install (e.g. Qt online installer).
- **Linux:** No default. Static Qt is built from source; workflows use a cached tarball. Set `-q` or `QT_STATIC`.
- **Windows:** MXE provides Qt. Set `-m` or `MXE_PATH`.

**MXE_PATH:** `$HOME/mxe/usr/bin`, else `$HOME/github/mxe/usr/bin`. Override with `-m` for custom MXE location (e.g. `/opt/mxe/usr/bin`).

---

## Platform Notes

### macOS

- **Qt:** Homebrew `qt@5` or Qt online installer. Default `brew --prefix qt@5` works for Homebrew installs.
- **zerod:** Build from [Zero](https://github.com/zerocurrencycoin/zero) with `./zcutil/build.sh`; binaries in `Zero/src/`.
- **DMG:** Disk image (`.dmg`) — macOS installer format. Users mount it and drag the app to Applications. Requires `create-dmg` (`brew install create-dmg`). `mkrelease-mac.sh` runs `macdeployqt`, copies zerod/zero-cli into the app bundle, ad-hoc signs, creates DMG.
- **Signing:** Default ad-hoc (local/testing). For distribution: Developer ID + notarization. See [macOS App Signing](#macos-app-signing-and-distribution) below.

### macOS Build Details

**Homebrew Qt vs repo-local:** macOS dev and release builds use Homebrew Qt (`brew install qt@5`) by default. Repo-local (vendored) Qt is not used on macOS; Linux uses static Qt from tarball, Windows uses MXE. Rationale: Homebrew provides a maintained Qt 5.15.x, avoids large vendored binaries, and matches typical macOS dev workflow. Override with `-q` for a custom Qt (e.g. Qt online installer).

**macdeployqt:** Qt's macOS deployment tool. Run after build; it copies Qt frameworks into `app/Contents/Frameworks/`, copies platform/other plugins into `app/Contents/PlugIns/`, and adjusts `install_name` so the app uses the bundled Qt. Produces a self-contained app that runs on machines without Qt installed. Only handles Qt; zerod/zero-cli are copied separately.

**Move into artifacts:** After `create-dmg`, `ZeroWallet.app` is moved to `artifacts/`. This keeps the project root clean so a later `make` (dev build) does not reuse the deployed app. Without the move, `zerowallet.app` and `ZeroWallet.app` share the same directory on a case-insensitive filesystem; a dev build would overwrite the binary but leave Frameworks/PlugIns, causing duplicate Qt load at runtime.

**Dev is a subset of Release:** A dev build is exactly what Release does up to and including `make` — i.e. after `make distclean`, a dev `make` produces the same binary that Release then deploys. Release adds: macdeployqt, zerod/zero-cli copy, codesign, DMG. So `make distclean && make` = Release's build step; `mkrelease-mac.sh` = that plus deploy and packaging.

**Rebuild levels:**

| Build | Trigger | Clean | Output |
|-------|---------|-------|--------|
| Dev | `make` | `clean-app-deploy` removes Frameworks/PlugIns only | `zerowallet.app` with symlink to Homebrew plugins |
| Full dev | `make distclean && make` | Removes app, objects, Makefile | Fresh `zerowallet.app` (same as Release's build) |
| Release | `mkrelease-mac.sh` | `make distclean`, `rm -rf zerowallet.app ZeroWallet.app` | DMG + `artifacts/ZeroWallet.app` |

**Validation:** After dev build, run `./zerowallet.app/Contents/MacOS/zerowallet` — should launch without duplicate-Qt or missing-plugin errors. After release, run `open /Volumes/ZeroWallet-vX.Y.Z/ZeroWallet.app` from the mounted DMG.

**No Qt installed (user scenario):** Do not test the dev build without Qt; it uses a symlink to Homebrew plugins and will fail. Test the Release build instead: `artifacts/ZeroWallet.app` or the app inside the DMG is self-contained. Generate: `./src/scripts/mkrelease-mac.sh -z $ZERO_DIR -v X.Y.Z`. Distribute: upload `artifacts/macOS-zerowallet-vX.Y.Z.dmg` to the GitHub Release; users mount the DMG and drag ZeroWallet.app to Applications.

**Clean VM testing:** Use a macOS VM with no Homebrew or Qt installed. Copy the DMG or `artifacts/ZeroWallet.app` into the VM and run it. This verifies the bundled Qt and zerod work on a clean system.

**VM options:**

| Option | Pros | Cons |
|--------|------|------|
| **UTM** | Free, open source, Apple Silicon native | Slower; requires macOS guest image |
| **VMware Fusion** | Mature, good performance | Commercial (free for personal use) |
| **Parallels** | Fast, polished | Commercial |
| **Apple Virtualization.framework** (e.g. OrbStack, Lima) | Native, lightweight | Limited macOS guest support |
| **Separate partition / external drive** | Real hardware, no VM overhead | Requires spare disk; slower to switch |

**Recommendation:** UTM for free, reproducible testing; VMware Fusion or Parallels if you already have a license and want faster runs. Use a minimal macOS install (no Xcode, no Homebrew) to simulate an end-user machine.

### Windows (cross-build from Linux)

- **MXE:** [M Cross Environment](https://mxe.cc/) provides MinGW + static Qt. Clone to `~/mxe` or `~/github/mxe`; `make MXE_TARGETS='x86_64-w64-mingw32.static' qt5` (2–4 hours).
- **zerod:** Build with `./zcutil/build-win.sh` in Zero repo; outputs `zerod.exe`, `zero-cli.exe` in `Zero/src/`.
- **Stripping:** TBD.

### Linux

- **Qt:** Static Qt 5.15.x from [Qt archives](https://download.qt.io/archive/qt/5.15/5.15.18/single/). No system default; build or use CI cache.
- **zerod:** `./zcutil/build.sh` in Zero repo. Binaries stripped before packaging.

---

## Attaching zerod Binaries

zerowallet packages copy zerod binaries at build time. No zerod source in zerowallet.

### ZERO_DIR

Directory containing built `zerod` and `zero-cli` (or `zerod.exe`, `zero-cli.exe` on Windows). Not the Zero source tree.

### Default layout

```bash
# Layout: zerowallet/ and Zero/ in same parent
cd zerowallet
(cd ../Zero && ./zcutil/build.sh -j$(nproc))

# ZERO_DIR defaults to ../Zero/src
./src/scripts/mkrelease-linux.sh -v 2.1.0 -p 2.0.0 -q /path/to/qt5-static
```

### Explicit path

```bash
./src/scripts/mkrelease-linux.sh -z /path/to/zerod/binaries -v 2.1.0 -p 2.0.0 -q $QT_STATIC
```

---

## Signing

### macOS App Signing and Distribution

Concepts, use cases, and operator steps for signing and distributing ZeroWallet on macOS.

#### Three Levels of Signing

| Level | What it does | User experience | Requirement |
|-------|--------------|-----------------|-------------|
| **Ad-hoc** | Signs app with local identity; proves integrity only | First launch: right-click → Open or System Settings → Open Anyway. After that, normal double-click. | None (built into macOS) |
| **Developer ID** | Signs with Apple-issued certificate; Gatekeeper trusts the developer | Double-click works; no "unidentified developer" prompt | Apple Developer Program ($99/year) |
| **Notarization** | Apple scans app for malware; staples ticket to binary | No Gatekeeper quarantine on download; smooth install | Developer ID + Apple ID + app-specific password |

#### How They Differ

- **Ad-hoc vs Developer ID:** Ad-hoc uses `-` (no certificate). Developer ID uses `"Developer ID Application: Name (TEAM_ID)"`. Both produce a valid signature; only Developer ID is trusted by Gatekeeper for downloads from the internet.

- **Developer ID vs Notarization:** Developer ID signs the app. Notarization is a separate step: you upload the signed app/DMG to Apple; Apple scans it; you staple the ticket. Notarization is required for macOS 10.15+ when apps are downloaded (e.g. from a browser or GitHub Releases). Without it, users may see "app is damaged" or similar.

#### Use Cases

| Use case | Signing | Notarization |
|----------|---------|--------------|
| Local testing, DMG on your Mac | Ad-hoc | No |
| Share DMG with colleagues (same network) | Ad-hoc | No (they use right-click → Open) |
| GitHub Releases, website download | Developer ID | Yes |
| Mac App Store | Distribution certificate | Yes (different flow) |

#### Operator Steps: Ad-hoc (Current Default)

**Prerequisites:** `create-dmg`, `codesign` (built-in), zerod built.

```bash
cd ~/Work/ZK/zerowalletmac

# 1. Ensure version matches
grep APP_VERSION src/version.h   # e.g. "2.1.0"

# 2. Build zerod if needed
cd ~/Work/ZK/ZeroMac && ./zcutil/build.sh -j$(sysctl -n hw.ncpu)
cd ~/Work/ZK/zerowalletmac

# 3. Run release script (uses ad-hoc codesign internally)
./src/scripts/mkrelease-mac.sh -z ~/Work/ZK/ZeroMac/src -v 2.1.0

# 4. Output: artifacts/macOS-zerowallet-v2.1.0.dmg
```

**Verify signature:**

```bash
hdiutil attach artifacts/macOS-zerowallet-v2.1.0.dmg -nobrowse -quiet
codesign -dv --verbose=2 "/Volumes/ZeroWallet-v2.1.0/ZeroWallet.app"
# Expect: Signature=adhoc
hdiutil detach "/Volumes/ZeroWallet-v2.1.0"
```

**Test launch:**

```bash
hdiutil attach artifacts/macOS-zerowallet-v2.1.0.dmg -nobrowse -quiet
open "/Volumes/ZeroWallet-v2.1.0/ZeroWallet.app"
# Window should appear. If first launch blocked: right-click → Open.
```

#### Operator Steps: Developer ID

**Prerequisites:** Apple Developer Program membership, Developer ID Application certificate installed in Keychain.

**Find your identity:**

```bash
security find-identity -v -p codesigning
# Look for: "Developer ID Application: Your Name (TEAM_ID)"
```

**Option B: Script support**

Add to `mkrelease-mac.sh` (around line 69):

```bash
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
codesign --force --deep --sign "$CODESIGN_IDENTITY" ZeroWallet.app
```

Then:

```bash
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
./src/scripts/mkrelease-mac.sh -z ~/Work/ZK/ZeroMac/src -v 2.1.0
```

**Verify:**

```bash
codesign -dv --verbose=2 "/Volumes/ZeroWallet-v2.1.0/ZeroWallet.app"
# Expect: Signature=... (not adhoc), TeamIdentifier=TEAM_ID
```

#### Operator Steps: Notarization

**Prerequisites:** Developer ID, Apple ID, app-specific password stored in Keychain.

**Create app-specific password:**

1. Apple ID → Sign-In and Security → App-Specific Passwords
2. Generate password; name it e.g. "AC_NOTARY"
3. Store in Keychain:

```bash
xcrun notarytool store-credentials AC_NOTARY \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

**Notarize DMG (after build + Developer ID sign):**

```bash
# 1. Submit
xcrun notarytool submit artifacts/macOS-zerowallet-v2.1.0.dmg \
  --keychain-profile AC_NOTARY \
  --wait

# 2. Staple ticket to DMG
xcrun stapler staple artifacts/macOS-zerowallet-v2.1.0.dmg
```

**Verify:**

```bash
xcrun stapler validate artifacts/macOS-zerowallet-v2.1.0.dmg
```

#### Before You Have Apple Developer ID

You can do these now:

| Task | Command | Purpose |
|------|---------|---------|
| Install tools | `brew install create-dmg` | DMG creation |
| Run ad-hoc release | `./src/scripts/mkrelease-mac.sh -z $ZERO_DIR -v 2.1.0` | Build, sign (ad-hoc), create DMG |
| Verify signature | `codesign -dv --verbose=2 /path/to/ZeroWallet.app` | Confirm ad-hoc or Developer ID |
| Test launch | `open /path/to/ZeroWallet.app` | Confirm app runs |
| Check notarytool | `xcrun notarytool --help` | Verify CLI exists (Xcode CLT) |
| Check stapler | `xcrun stapler --help` | Verify stapler exists |

**Cannot do without Developer ID:** Sign with Developer ID, Notarize.

**Can prepare:** Create Apple ID if needed; read [Apple Developer Notarization](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution); store app-specific password in Keychain after enrolling.

#### Testing Checklist

| Step | Action | Expected |
|------|--------|----------|
| 1 | Build DMG | `artifacts/macOS-zerowallet-vX.Y.Z.dmg` exists |
| 2 | Mount DMG | `hdiutil attach ...` succeeds |
| 3 | Verify signature | `codesign -dv` shows Signature=adhoc or Developer ID |
| 4 | Launch | `open /Volumes/ZeroWallet-vX.Y.Z/ZeroWallet.app` |
| 5 | Window appears | zerowallet UI visible |
| 6 | First-launch bypass (ad-hoc only) | If blocked: right-click → Open or System Settings → Open Anyway |
| 7 | Copy to Applications | Drag app to Applications; verify it runs from there |
| 8 | Unmount | `hdiutil detach "/Volumes/ZeroWallet-vX.Y.Z"` |

#### References

- [Apple: Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Apple: Signing a Mac product](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow)

### GPG Signatures (artifacts)

GPG signatures and sha256 hashes let users verify release integrity and authenticity.

**Prerequisites:** GPG installed; release signing key (separate from commit signing recommended); public key published (e.g. `public_key.asc` in repo).

```bash
./src/scripts/signbinaries.sh -v 2.1.0
```

Produces `sha256sum-v$APP_VERSION.txt` and `*.sig` in `artifacts/`, packaged as `signatures-v$APP_VERSION.zip`. See `res/SIGNATURES_README` for user verification steps.

**Note:** `signbinaries.sh` auto-detects: uses `sha256sum` on Linux, `shasum -a 256` on macOS.

---

## CI (GitHub Actions)

Workflows [`.github/workflows/Zero Wallet Linux.yml`](.github/workflows/Zero Wallet Linux.yml) and [`.github/workflows/Zero Wallet Windows.yml`](.github/workflows/Zero Wallet Windows.yml):

- Clone Zero, build zerod, set `ZERO_DIR`
- Build static Qt (Linux) or MXE (Windows), cache
- Run `mkrelease-linux.sh` or `mkrelease-win.sh`
- Upload artifacts: `zerowallet-linux-deb`, `zerowallet-linux-tar`, `zerowallet-windows`

Update `APP_VERSION` and `PREV_VERSION` in workflow `env` when cutting releases.

---

## Rolling Releases

1. Update `src/version.h` to new `APP_VERSION`
2. Build: `./src/scripts/mkrelease-linux.sh -v X.Y.Z -p X.Y.(Z-1) -q $QT_STATIC` (and win/mac as needed)
3. **macOS:** `./src/scripts/mkrelease-mac.sh -z $ZERO_DIR -v X.Y.Z`; use Developer ID + notarization for distribution
4. Sign: `./src/scripts/signbinaries.sh -v X.Y.Z`
5. Tag: `git tag -a vX.Y.Z -m "Release X.Y.Z"`
6. Push tag, create GitHub Release, upload artifacts and signatures
