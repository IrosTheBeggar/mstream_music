#!/usr/bin/env bash
# Build viz_decoder.xcframework (device arm64 + simulator arm64) and stage it
# into the viz_decoder_native plugin, where Flutter's SwiftPM support links it
# into Runner and embeds + signs it automatically.
#
# Same model as rust/iroh_tunnel/build-ios.sh: the xcframework is COMMITTED to
# git (release CI has no Rust toolchain and ships the committed binary).
# RULE: after changing rust/viz_decoder/, re-run this script and commit the
# updated xcframework.
#
# Prereqs (one-time):
#   rustup target add aarch64-apple-ios aarch64-apple-ios-sim
#   Xcode command line tools (xcodebuild / install_name_tool / codesign)
#
# Intel-simulator support is deliberately not shipped (Apple-silicon shop).
set -euo pipefail
cd "$(dirname "$0")"

# Match ios/Runner's IPHONEOS_DEPLOYMENT_TARGET; lands in LC_BUILD_VERSION minos.
export IPHONEOS_DEPLOYMENT_TARGET=15.0
# If this ever runs from an Xcode script phase, SDKROOT points at the macOS
# SDK and poisons the cross-build. The script is meant to be run manually —
# scrub it anyway.
unset SDKROOT

FW=viz_decoder
VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1)"
DEST="../../packages/viz_decoder_native/ios/viz_decoder_native/Frameworks"
STAGE="target/ios-stage" # under target/ -> already gitignored

# The release profile in Cargo.toml (opt-level=z, thin LTO, strip) applies;
# rustc strips cdylibs with `strip -x`, which keeps the exported C symbols.
cargo build --release --lib --target aarch64-apple-ios
cargo build --release --lib --target aarch64-apple-ios-sim

# Assemble a shallow iOS framework around the raw cdylib. The two slices are
# staged in separate dirs (both are named viz_decoder.framework; xcodebuild
# -create-xcframework is what reconciles them).
make_framework() { # 1=rust triple  2=stage slice dir  3=CFBundleSupportedPlatforms
  local triple="$1" slice="$2" platform="$3"
  local fwdir="$STAGE/$slice/$FW.framework"
  rm -rf "$fwdir"
  mkdir -p "$fwdir"
  cp "target/$triple/release/lib$FW.dylib" "$fwdir/$FW"
  # Load-bearing: rustc leaves LC_ID_DYLIB as the build path; Runner records
  # it at link time and the app would crash at launch without this fixup.
  install_name_tool -id "@rpath/$FW.framework/$FW" "$fwdir/$FW"
  cat > "$fwdir/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>$FW</string>
  <key>CFBundleIdentifier</key><string>mstream.music.viz-decoder</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$FW</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
  <key>MinimumOSVersion</key><string>$IPHONEOS_DEPLOYMENT_TARGET</string>
</dict>
</plist>
EOF
  # install_name_tool invalidated the linker's ad-hoc signature; re-sign
  # ad-hoc so the binary stays loadable (arm64 sim refuses unsigned code).
  # Xcode re-signs with the real identity when it embeds the framework.
  codesign --force --sign - "$fwdir/$FW"
}

make_framework aarch64-apple-ios ios-arm64 iPhoneOS
make_framework aarch64-apple-ios-sim ios-arm64-simulator iPhoneSimulator

mkdir -p "$DEST"
rm -rf "$DEST/$FW.xcframework" # -create-xcframework refuses to overwrite
xcodebuild -create-xcframework \
  -framework "$STAGE/ios-arm64/$FW.framework" \
  -framework "$STAGE/ios-arm64-simulator/$FW.framework" \
  -output "$DEST/$FW.xcframework"

# Smoke-check: all 7 C ABI symbols must be exported from both slices (the
# export trie is authoritative — dyld_info, not nm).
for slice in ios-arm64 ios-arm64-simulator; do
  n=$(xcrun dyld_info -exports "$DEST/$FW.xcframework/$slice/$FW.framework/$FW" | grep -c ' _mstream_vizdec_')
  [ "$n" -eq 7 ] || {
    echo "ERROR: $slice exports $n/7 mstream_vizdec_ symbols"
    exit 1
  }
done
echo "staged: $DEST/$FW.xcframework"
echo "remember: commit the updated xcframework — builds ship the committed binary."
