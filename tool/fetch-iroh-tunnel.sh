#!/usr/bin/env bash
# Pin this app to a tagged release of the shared tunnel crate
# (github.com/IrosTheBeggar/mstream-iroh-tunnel). The binaries are not
# committed: the Android build downloads its zip (a Gradle task in
# android/app/build.gradle, checked against the SHA-256 in
# tool/iroh-tunnel.properties) and the iOS build resolves a SwiftPM remote
# binaryTarget (packages/iroh_tunnel_native/ios/iroh_tunnel_native/Package.swift,
# checked against its checksum). This script moves the pin:
#
#   tool/fetch-iroh-tunnel.sh v0.3.0     # a bump: verify the release, write the pins
#   tool/fetch-iroh-tunnel.sh            # re-verify the pinned release, seed the Gradle cache
#
# It downloads the release's SHA256SUMS and SWIFTPM-CHECKSUMS.txt, downloads
# the Android zip and checks it, checks the iOS zip's SwiftPM checksum where
# `swift` is available, writes tool/iroh-tunnel.properties (tag + the Android
# SHA-256) and the url + checksum lines of the iOS Package.swift, and drops the
# verified Android zip into ~/.gradle/caches/mstream-iroh-tunnel/ so the next
# build does not fetch it again. The macOS xcframework and the Windows DLL
# (the desktop branch) are still staged as committed files where their
# directories exist.
#
# After a bump: review the diff, run the smoke suites, commit.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="IrosTheBeggar/mstream-iroh-tunnel"
LOCK="tool/iroh-tunnel.properties"
IOS_MANIFEST="packages/iroh_tunnel_native/ios/iroh_tunnel_native/Package.swift"
MACOS_DEST="packages/iroh_tunnel_native/macos/iroh_tunnel_native/Frameworks"
WINDOWS_DEST="windows/iroh"

pinned="$(sed -n 's/^tag=//p' "$LOCK" 2>/dev/null || true)"
VERSION="${1:-$pinned}"
[ -n "$VERSION" ] || { echo "usage: $0 <tag>   (nothing pinned in $LOCK yet)"; exit 2; }
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

listed() { # <checksum file> <asset> → the checksum, or fails
  local sum
  sum="$(grep " $2\$" "$TMP/$1" | cut -d' ' -f1 || true)"
  [ -n "$sum" ] || { echo "ERROR: $2 is not listed in $1 for $VERSION"; exit 1; }
  echo "$sum"
}

verified_download() { # <asset>: fetched and checked against SHA256SUMS
  local expected actual
  fetch "$1"
  expected="$(listed SHA256SUMS "$1")"
  actual="$(sha256_of "$TMP/$1")"
  [ "$expected" = "$actual" ] || { echo "ERROR: checksum mismatch for $1"; exit 1; }
}

ANDROID="iroh_tunnel-$VERSION-android.zip"
IOS="iroh_tunnel-$VERSION-ios.xcframework.zip"
MACOS="iroh_tunnel-$VERSION-macos.xcframework.zip"
WINDOWS="iroh_tunnel-$VERSION-windows-x86_64.zip"

fetch SHA256SUMS
fetch SWIFTPM-CHECKSUMS.txt
verified_download "$ANDROID"
android_sha="$(listed SHA256SUMS "$ANDROID")"
ios_checksum="$(listed SWIFTPM-CHECKSUMS.txt "$IOS")"

# The published SwiftPM checksum against the asset itself, when a Swift
# toolchain is here to compute it (Xcode does the same check at resolution).
if command -v swift > /dev/null 2>&1; then
  verified_download "$IOS"
  computed="$(swift package compute-checksum "$TMP/$IOS")"
  [ "$computed" = "$ios_checksum" ] || { echo "ERROR: SWIFTPM-CHECKSUMS.txt says $ios_checksum for $IOS but it computes to $computed"; exit 1; }
  echo "iOS SwiftPM checksum verified"
fi
echo "checksums verified"

# The pins.
cat > "$LOCK" <<LOCKEOF
# The release of the shared tunnel crate (github.com/IrosTheBeggar/mstream-iroh-tunnel)
# this app packages, and the SHA-256 the Android build pins its download to.
# Written by tool/fetch-iroh-tunnel.sh <tag>. The iOS checksum lives in
# packages/iroh_tunnel_native/ios/iroh_tunnel_native/Package.swift, which the
# same script rewrites.
tag=$VERSION
android.sha256=$android_sha
LOCKEOF
perl -pi -e 's{(url: ")[^"]*(")}{${1}'"$BASE/$IOS"'${2}}; s{(checksum: ")[^"]*(")}{${1}'"$ios_checksum"'${2}}' "$IOS_MANIFEST"
grep -q "$IOS\"" "$IOS_MANIFEST" && grep -q "$ios_checksum" "$IOS_MANIFEST" \
  || { echo "ERROR: could not rewrite the url/checksum lines of $IOS_MANIFEST"; exit 1; }

# Seed the Gradle cache with the zip just verified, so the build's download
# task finds it and skips the network.
GRADLE_CACHE="${GRADLE_USER_HOME:-$HOME/.gradle}/caches/mstream-iroh-tunnel"
mkdir -p "$GRADLE_CACHE"
install -m 644 "$TMP/$ANDROID" "$GRADLE_CACHE/$ANDROID"

# The desktop branch's platforms still commit their binaries.
if [ -d "$MACOS_DEST" ]; then
  verified_download "$MACOS"
  rm -rf "$MACOS_DEST/iroh_tunnel.xcframework"
  unpack "$TMP/$MACOS" "$MACOS_DEST"
fi
if [ -d "$WINDOWS_DEST" ]; then
  verified_download "$WINDOWS"
  unpack "$TMP/$WINDOWS" "$TMP/windows"
  install -m 644 "$TMP/windows/iroh_tunnel.dll" "$WINDOWS_DEST/iroh_tunnel.dll"
fi

echo "pinned $VERSION:"
cat "$LOCK" | grep -v '^#'
grep -E 'url:|checksum:' "$IOS_MANIFEST"
echo "Gradle cache: $GRADLE_CACHE/$ANDROID"
[ -d "$MACOS_DEST" ] && ls -d "$MACOS_DEST"/iroh_tunnel.xcframework/*/iroh_tunnel.framework
[ -d "$WINDOWS_DEST" ] && ls -l "$WINDOWS_DEST/iroh_tunnel.dll"
echo "now: review the diff, run the smoke suites, commit."
