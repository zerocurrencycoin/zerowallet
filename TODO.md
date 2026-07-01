# TODO

Selection of items and issues from project documentation ([UpdateWallet](UpdateWallet.md)). User-facing content is moved to README/BUILD where appropriate; see [SCOPE](SCOPE.md) for content policy. To contribute, see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Active

### Build scripts — `port-linuxwin` (status 2026-07-01)

Ported the mac-working build scripts to Linux + Windows and hardened them. On branch
`port-linuxwin` (off `upstream-port`); commits pushed to `origin/port-linuxwin`.

**Done + validated:**

- Linux dev + release (static Qt, `.tgz` + `.deb`) — built, exit 0, artifacts. ✅
- Windows dev + release (MXE cross-build on Linux) — `.exe` + `.zip`, stripped. ✅
- `-j`/`JOBS`: default `min(CPUs,4)`, `-j` overrides, env `JOBS` wins. ✅
- Versioning: `version.h` single source of truth; qmake imports it; `-v` writes it;
  git/auto-bump/`-p`/`apply_version_sed` removed. ✅ (see [UpdateWallet §Versioning](UpdateWallet.md#versioning-srcversionh-is-the-single-source-of-truth))
- libsodium `sodium_archive_kind`: all 4 transitions (missing→build, match→reuse,
  unix↔win wrong-target→rebuild) verified. ✅
- Logging unified: `init_logging`, timestamped, full-capture, single method. ✅
- `set -e` exit-code bug (`[ ] && { }` trailing) fixed; standardized to `if..fi`. ✅
- mkdev-linux: `sudo apt-get install` → **check-and-hint** (no auto-sudo). ✅
- Dead code removed (`sodium_archive_ok`, `resolve_zero_dirs_linuxwin`, `info`, dup URL_BASE).

**Next:**

- **macOS: validate** — not yet run on a Mac. Follow [BUILD §macOS validation](BUILD.md#macos-validation).
  Then mark done and merge `port-linuxwin` → `upstream-port`.
- `check_version_mismatch` is now a no-op — remove or repurpose ([UpdateWallet §Versioning](UpdateWallet.md#versioning-srcversionh-is-the-single-source-of-truth)).
- Logs accumulate (no rotation) — postponed.

### Upstream ports (`upstream-port`)

- Build/run smoke test before first commit.
- Params open questions → Zero repo / release (§Zcash proving parameters).
- Optional: sendtab balance guards → **POST-SEND**.

### Version upgrades (UpdateWallet §Version Upgrade Plan)

- nlohmann/json: 3.6.1 → 3.12.0 (low risk/effort).
- SingleApplication: 3.0.14 → 3.5.4 (submodule or copy).
- Nayuki QR-Code: unversioned → v1.8.0 (replace 6 files with 2; update .pro).
- Qt: **5.15.18** in static release — no bump unless critical; 5.15.19 commercial-only.
- libsodium: **1.0.21** — done.

### Security / behavior (active, not postponed)

- Credentials: rpcuser/rpcpassword in QSettings plain text (`settings.cpp`) → see **POST-CRED** when prioritized.
- RPC: same-host `127.0.0.1` model documented.

### Build / cross-reference

- Review safewallet/SevenSeas build script fixes separately from P0 ports.
- Verify ZERO_DIR layout: mkrelease default `../Zero/src` vs platform output dirs.

---

## Postponed backlog

Full table: [UpdateWallet §Postponed backlog](UpdateWallet.md#postponed-backlog-no-scheduled-work).

| ID | Summary |
|----|---------|
| **POST-RPC** | Unified `doRPCEx` / `RpcErrorPolicy`; absorb `invokeRpcCallbackSafe` as `SafeCallback` policy | `connection.cpp` refactor |
| **POST-WIF** | P2-wif: `importprivkey` with account `""`, not rescan as 2nd arg (`cd4832d`) |
| **POST-ZBOARD** | z-board.net: HTTP `listTopics`, post UI — disable or HTTPS |
| **POST-TLS** | TLS for wallet↔zerod |
| **POST-CRED** | Encrypt / keychain for RPC creds in QSettings |
| **POST-DOCKER** | Docker 16→24; OpenSSL 1.0.2→1.1.1 |
| **POST-UI** | Market tab, translations merge, Midnight theme |
| **POST-PARAMS** | macOS param bundle, STAB-4, `-paramsdir` |
| **POST-BATCH** | `doBatchRPC` completion timeout |
| **POST-NAME** | Rename `ezcashd` variable to `embeddedZerod` |
| **POST-SEND** | Extra sendtab `getAllBalances` guards |

### Deprioritized

- Mobile / WebSocket — UI removed (§Mobile).

---

## Completed (`upstream-port`)

- SEC-1/2: memo phishing, `QUrlQuery`.
- KEY-1: TZU private-key export (`getAllPrivKeys`).
- STAB-1/2: `QProcess::start(prog, QStringList())`, `QFile::exists(zerod)`.
- STAB-3: params download to home.
- RPC: `doRPC` parse/JSON-RPC error gate; `checkForUpdate` exception catch.
- RPC: `doRPCIgnoreErrorSafe` on poll paths; `doBatchRPC` JSON-RPC error on batch items.
- RPC: `invokeRpcCallbackSafe` on main poll `getinfo` (`getInfoThenRefresh`); shared with `doRPCIgnoreErrorSafe`.
- `getAllBalances` guards: Receive, view-all, Z-board from, `updateTAddrCombo`.

### Earlier completed

- **qt-report.sh:** Unified message format; unknown platform single warn; Linux summary conditional (qt5-static/MXE).
- **Linux release:** `-S`/`--systemqt` for system Qt; resolve_qt, static-link check skip.
- **Option naming:** `--systemqt`, `--nostrip` in scripts and docs.
- **BUILD.md:** System status, artifacts, Linux release Qt, build outcomes, binary check, signing.
- **mkrelease-mac:** `-T`/`--tgz`; explicit `|| err` for critical steps.
- **Helpers:** fbuild sourcing (qt-report, install_mxe, mkrelease, mkdev); check_file, get_app_from_h; LICENSE removed from packages.
- **libsodium 1.0.21** vendored and build scripts updated.
