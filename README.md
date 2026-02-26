Desktop wallet for Zero Currency ($ZER) that runs on Linux, Windows and MacOS.

# Installation

Releases page has the latest [installers and binaries](https://github.com/zerocurrencycoin/zerowallet/releases). See [BUILD.md](BUILD.md) for building and publishing binary releases.

## zerod

zerowallet needs running `zerod`, Zero full node process. If one is not already running, zerowallet will start it.  If not already present, it will configure full node defaults in `zero.conf`.

If this is the first time you're running `zerowallet`, it will download the Zcash cryptographic params (~1.7 GB).

Option `--no-embedded` forces zerowallet to connect to a running `zerod` full node process.

## Compiling from source

zerowallet is written in C++ 14 and depends on Qt5, [available from](https://www.qt.io/download).  See [BUILD.md](BUILD.md) for full build and release details.  Note that building zerod from source [is a separate task](https://github.com/zerocurrencycoin/Zero#-building).

## Support

For support or to meet the community, join [Discord](https://discordapp.com/invite/Jq5knn5) or [file an issue](https://github.com/zerocurrencycoin/zerowallet/issues).

🔒 Security Warnings
-----------------
[Backup your wallet](https://github.com/zerocurrencycoin/Zero/wiki/Wallet-Backup) often and keep it safe and secret.

See important [Security Information from Zcash](https://z.cash/support/security/).

**Zero is very much experimental and a work in progress.** Use it at your own risk.
