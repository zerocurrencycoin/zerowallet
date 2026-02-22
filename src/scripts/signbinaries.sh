#!/bin/bash

# Parse args (env vars override). Same -v/--version as mkrelease scripts.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version) APP_VERSION="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$APP_VERSION" ]; then echo "APP_VERSION is not set. Use -v/--version or set env."; exit 1; fi

# Store the hash and signatures here
rm -rf release/signatures
mkdir -p release/signatures

cd artifacts

# Remove previous signatures/hashes
rm -f sha256sum-v$APP_VERSION.txt
rm -f signatures-v$APP_VERSION.tar.gz

# sha256sum the binaries
sha256sum *$APP_VERSION* > sha256sum-v$APP_VERSION.txt

for i in $( ls *zerowallet-v$APP_VERSION* sha256sum-v$APP_VERSION* ); do
  echo "Signing" $i
  gpg --batch --output ../release/signatures/$i.sig --detach-sig $i
done

mv sha256sum-v$APP_VERSION.txt ../release/signatures/
cp ../res/SIGNATURES_README ../release/signatures/README

cd ../release/signatures
#tar -czf signatures-v$APP_VERSION.tar.gz *
zip signatures-v$APP_VERSION.zip *
mv signatures-v$APP_VERSION.zip ../../artifacts
