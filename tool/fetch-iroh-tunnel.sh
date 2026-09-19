#!/usr/bin/env bash
# Stage the prebuilt iroh tunnel binaries from a tagged release of the shared
# client crate (github.com/IrosTheBeggar/mstream-iroh-tunnel) into the places
# this app packages them from — the same places the crate's build scripts used
# to write into when it lived under rust/iroh_tunnel here.
#
#   tool/fetch-iroh-tunnel.sh            # the version in tool/iroh-tunnel.version
#   tool/fetch-iroh-tunnel.sh v0.2.0     # a bump: stages it and records it there
#
# Downloads the assets for this checkout — Android always, iOS always, macOS
# and Windows when their packaging directories exist here — verifies them
# against the release's SHA256SUMS, and installs them. The binaries stay
# COMMITTED (the release CI has no Rust toolchain and ships what is in git),
# so after a bump: review the diff, run the smoke suites, commit. A stale
# committed binary is the one failure the packaging checks cannot catch.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="IrosTheBeggar/mstream-iroh-tunnel"
VERSION_FILE="tool/iroh-tunnel.version"
VERSION="${1:-$(cat "$VERSION_FILE")}"
BASE="https://github.com/$REPO/releases/download/$VERSION"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch() {
  echo "fetching $1"
  curl -fsSL --retry 3 --retry-delay 2 -o "$TMP/$1" "$BASE/$1"
}

sha256_of() {
  if command -v shasum > /dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else sha256sum "$1" | cut -d' ' -f1; fi
}

# Unpack a zip preserving symlinks (a macOS framework has them).
unpack() {
  if command -v ditto > /dev/null 2>&1; then ditto -x -k "$1" "$2"
  else unzip -q -o "$1" -d "$2"; fi
}

ANDROID="iroh_tunnel-$VERSION-android.zip"
IOS="iroh_tunnel-$VERSION-ios.xcframework.zip"
MACOS="iroh_tunnel-$VERSION-macos.xcframework.zip"
WINDOWS="iroh_tunnel-$VERSION-windows-x86_64.zip"

IOS_DEST="packages/iroh_tunnel_native/ios/iroh_tunnel_native/Frameworks"
MACOS_DEST="packages/iroh_tunnel_native/macos/iroh_tunnel_native/Frameworks"
WINDOWS_DEST="windows/iroh"

want=("$ANDROID" "$IOS")
[ -d "$MACOS_DEST" ] && want+=("$MACOS")
[ -d "$WINDOWS_DEST" ] && want+=("$WINDOWS")

fetch SHA256SUMS
for asset in "${want[@]}"; do
  fetch "$asset"
  expected="$(grep " $asset\$" "$TMP/SHA256SUMS" | cut -d' ' -f1 || true)"
  [ -n "$expected" ] || { echo "ERROR: $asset is not listed in SHA256SUMS"; exit 1; }
  actual="$(sha256_of "$TMP/$asset")"
  [ "$expected" = "$actual" ] || { echo "ERROR: checksum mismatch for $asset"; exit 1; }
done
echo "checksums verified"

# Android: one .so per ABI, exactly where the Gradle build packages them from.
unpack "$TMP/$ANDROID" "$TMP/android"
for abi in arm64-v8a x86_64; do
  install -m 644 "$TMP/android/$abi/libiroh_tunnel.so" "android/app/src/main/jniLibs/$abi/libiroh_tunnel.so"
done

# iOS: the xcframework the SwiftPM package vends to Runner.
rm -rf "$IOS_DEST/iroh_tunnel.xcframework"
unpack "$TMP/$IOS" "$IOS_DEST"

if [ -d "$MACOS_DEST" ]; then
  rm -rf "$MACOS_DEST/iroh_tunnel.xcframework"
  unpack "$TMP/$MACOS" "$MACOS_DEST"
fi

if [ -d "$WINDOWS_DEST" ]; then
  unpack "$TMP/$WINDOWS" "$TMP/windows"
  install -m 644 "$TMP/windows/iroh_tunnel.dll" "$WINDOWS_DEST/iroh_tunnel.dll"
fi

echo "$VERSION" > "$VERSION_FILE"
echo "staged $VERSION:"
ls -l android/app/src/main/jniLibs/*/libiroh_tunnel.so
ls -d "$IOS_DEST"/iroh_tunnel.xcframework/*/iroh_tunnel.framework
[ -d "$MACOS_DEST" ] && ls -d "$MACOS_DEST"/iroh_tunnel.xcframework/*/iroh_tunnel.framework
[ -d "$WINDOWS_DEST" ] && ls -l "$WINDOWS_DEST/iroh_tunnel.dll"
echo "now: review the diff, run the smoke suites, commit."
