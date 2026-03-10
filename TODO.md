# TODO

Selection of items and issues from project documentation ([UpdateWallet](UpdateWallet.md)). User-facing content is moved to README/BUILD where appropriate; see [SCOPE](SCOPE.md) for content policy. To contribute, see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Active

### Version upgrades (UpdateWallet §Version Upgrade Plan)
- nlohmann/json: 3.6.1 → 3.12.0 (low risk/effort).
- SingleApplication: 3.0.14 → 3.5.4 (submodule or copy).
- Nayuki QR-Code: unversioned → v1.8.0 (replace 6 files with 2; update .pro).
- Qt: 5.15.18 current; 5.15.19 commercial-only cherry-pick only if critical.
- Docker: ubuntu:16.04 → 24.04 (Dockerfile); OpenSSL 1.0.2 → 1.1.1 (medium risk/effort).

### Security / behavior (UpdateWallet §Detected Errors, §Security Vulnerability Report)
- Credentials: rpcuser/rpcpassword in QSettings plain text (`settings.cpp:242-243`). Target: OS credential store or encrypt.
- HTTP: `rpc.cpp:1538` z-board.net listTopics over HTTP. Prefer HTTPS if supported; else document risk.

### Futures and wants (UpdateWallet §Futures and Wants)
- Theme (Midnight, CSS), translations — keep Zero branding.
- Market data — evaluate for Zero.
- Mobile connectivity — verify with Zero mobile apps; Wormhole status TBD.
- TLS for zerod connections (upstream SilentDragon).
- Cross-compilation: MXE containers, 32-bit Windows, ARM64.

### Build / cross-reference
- Verify ZERO_DIR layout: mkrelease default `../Zero/src` vs zero_linux/src, zero_win/src output dirs in Zero repo.

---

## Completed

- **qt-report.sh:** Unified message format; unknown platform single warn; Linux summary conditional (qt5-static/MXE).
- **Linux release:** `-S`/`--systemqt` for system Qt; resolve_qt, static-link check skip.
- **Option naming:** `--systemqt`, `--nostrip` in scripts and docs.
- **BUILD.md:** System status, artifacts, Linux release Qt, build outcomes, binary check, signing.
- **mkrelease-mac:** `-T`/`--tgz`; explicit `|| err` for critical steps.
- **Helpers:** fbuild sourcing (qt-report, install_mxe, mkrelease, mkdev); check_file, get_app_from_h; LICENSE removed from packages.
- **CHANGELOG.md, ZeroChain.md, ZeroCoin.md, SCOPE.md:** Release prep and scope.
