#!/usr/bin/env bash
# Build viz_decoder.xcframework for macOS (arm64) and stage it into the
# viz_decoder_native plugin's macos/ side, where Flutter's SwiftPM support
# links it into Runner and embeds + signs it automatically.
#
# Same model as build-ios.sh: the xcframework is COMMITTED to git (release CI
# has no Rust toolchain and ships the committed binary). RULE: after changing
# rust/viz_decoder/, re-run this script and commit the updated xcframework.
#
# Prereqs: the host Rust toolchain (the build targets the host arch) and
# Xcode command line tools. Apple-silicon only, matching the iOS script —
# arm64 macs are the shop's floor, and an Intel slice can be added to the
# -create-xcframework call later if ever needed.
set -euo pipefail
cd "$(dirname "$0")"

# arm64 macOS floor — LC_BUILD_VERSION minos. (The Xcode project's 10.15
# deployment target is an x86-era default; arm64 hardware starts at 11.)
export MACOSX_DEPLOYMENT_TARGET=11.0
unset SDKROOT

FW=viz_decoder
VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1)"
DEST="../../packages/viz_decoder_native/macos/viz_decoder_native/Frameworks"
STAGE="target/macos-stage"

cargo build --release --lib --target aarch64-apple-darwin

# Assemble a VERSIONED macOS framework (unlike iOS's shallow layout, macOS
# frameworks need the Versions/A + symlink structure or codesign/embedding
# rejects the bundle shape).
fwdir="$STAGE/macos-arm64/$FW.framework"
rm -rf "$fwdir"
mkdir -p "$fwdir/Versions/A/Resources"
cp "target/aarch64-apple-darwin/release/lib$FW.dylib" "$fwdir/Versions/A/$FW"
# Load-bearing: rustc leaves LC_ID_DYLIB as the build path; Runner records it
# at link time and the app would fail to load the framework without this.
install_name_tool -id "@rpath/$FW.framework/Versions/A/$FW" "$fwdir/Versions/A/$FW"
cat > "$fwdir/Versions/A/Resources/Info.plist" <<EOF
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
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>LSMinimumSystemVersion</key><string>$MACOSX_DEPLOYMENT_TARGET</string>
</dict>
</plist>
EOF
ln -sfn A "$fwdir/Versions/Current"
ln -sfn Versions/Current/$FW "$fwdir/$FW"
ln -sfn Versions/Current/Resources "$fwdir/Resources"
# install_name_tool invalidated the linker's ad-hoc signature; re-sign so the
# binary stays loadable. Xcode re-signs on embed.
codesign --force --sign - "$fwdir"

mkdir -p "$DEST"
rm -rf "$DEST/$FW.xcframework"
xcodebuild -create-xcframework \
  -framework "$fwdir" \
  -output "$DEST/$FW.xcframework"

# Smoke-check: all 7 C ABI symbols must be exported.
n=$(xcrun dyld_info -exports "$DEST/$FW.xcframework/macos-arm64/$FW.framework/$FW" | grep -c ' _mstream_vizdec_')
[ "$n" -eq 7 ] || { echo "ERROR: exports $n/7 mstream_vizdec_ symbols"; exit 1; }
echo "staged: $DEST/$FW.xcframework"
echo "remember: commit the updated xcframework — builds ship the committed binary."
