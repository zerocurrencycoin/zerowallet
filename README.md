Desktop wallet for Zero Currency ($ZER) that runs on Linux, Windows and MacOS.

# Installation

Releases page has the latest [installers and binaries](https://github.com/zerocurrencycoin/zerowallet/releases). See [BUILD.md](BUILD.md) for building and publishing binary releases.

## zerod

zerowallet needs running `zerod`, Zero full node process. If one is not already running, zerowallet will start it.  If not already present, it will configure full node defaults in `zero.conf`.

Before connecting, zerowallet checks the three proving parameter files `zerod` loads in the platform parameter directory (`~/.zcash-params`, `~/Library/Application Support/ZcashParams`, or `%APPDATA%\ZcashParams`): sizes on every start, SHA-256 once per file. On first run it downloads them (about 741 MiB), retrying interrupted downloads; if a download cannot complete, it says why and offers Retry. `zerod`, not the wallet, uses them.

Option `--no-embedded` forces zerowallet to connect to a running `zerod` full node process.

## Compiling from source

zerowallet is C++14 on Qt 5. Build and release: [BUILD.md](BUILD.md).

## Documentation

Documents maintained for zerowallet; those under `singleapplication/` are upstream's.

| Document | Readers | Purpose |
|----------|---------|---------|
| README.md | Users | Install, run, first start, support, this map |
| [BUILD.md](BUILD.md) | Developers, porters | Setup, dev and release builds, signing, logs, troubleshooting |
| [TODO.md](TODO.md) | Contributors, maintainers | Open work and postponed items |
| [AGENTS.md](AGENTS.md) | Agents and humans editing the tree | Scope, git, file, and documentation rules |
| [src/scripts/Bashrules.md](src/scripts/Bashrules.md) | Script authors | Conventions for the build scripts |

## Support

For support or to meet the community, join [Discord](https://discordapp.com/invite/Jq5knn5) or [file an issue](https://github.com/zerocurrencycoin/zerowallet/issues).

🔒 Security Warnings
-----------------
[Backup your wallet](https://github.com/zerocurrencycoin/Zero/wiki/Wallet-Backup) often and keep it safe and secret.

See important [Security Information from Zcash](https://z.cash/support/security/).

**Zero is very much experimental and a work in progress.** Use it at your own risk.
