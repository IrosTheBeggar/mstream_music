#!/usr/bin/env bash
# Build libiroh_tunnel.so for the app's ABIs and stage it into the Flutter app's
# jniLibs so `flutter build apk --flavor <full|play>` packages it.
#
# The staged .so is COMMITTED to git (android/app/src/main/jniLibs/<abi>/), same as
# libprojectM-4.so — the release CI (ubuntu-latest) has no Rust/NDK toolchain, so it
# ships the committed binary. RULE: after changing anything under rust/iroh_tunnel/,
# re-run this script and commit the updated .so. (release.yml fails the build if the
# .so is missing from the artifacts, but it can't detect a stale one.)
#
# Prereqs (one-time):
#   rustup target add aarch64-linux-android x86_64-linux-android
#   cargo install cargo-ndk
#   export ANDROID_NDK_HOME=.../Android/Sdk/ndk/28.2.13676358
#
# Usage:  ./build-android.sh
set -euo pipefail
cd "$(dirname "$0")"

: "${ANDROID_NDK_HOME:?set ANDROID_NDK_HOME to your NDK, e.g. .../Android/Sdk/ndk/28.2.13676358}"

JNILIBS="../../android/app/src/main/jniLibs"

# --platform 26 matches the app's minSdk. The flag is --platform (NOT -p, which
# cargo passes through to cargo as --package).
cargo ndk -t arm64-v8a -t x86_64 --platform 26 build --release --lib

# Stage ONLY our cdylib. cargo-ndk's -o would also copy spurious dependency
# dylibs (libiroh-<hash>.so / libiroh_relay-<hash>.so) that libiroh_tunnel.so
# already statically links — dead weight in the APK.
for pair in "arm64-v8a:aarch64-linux-android" "x86_64:x86_64-linux-android"; do
  abi="${pair%%:*}"; triple="${pair##*:}"
  mkdir -p "$JNILIBS/$abi"
  cp "target/$triple/release/libiroh_tunnel.so" "$JNILIBS/$abi/libiroh_tunnel.so"
done

echo "staged:"
ls -lh "$JNILIBS"/*/libiroh_tunnel.so
echo "remember: commit the updated .so — release builds ship the committed binary."
