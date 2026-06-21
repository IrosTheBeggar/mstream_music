#!/usr/bin/env bash
# Build libiroh_tunnel.so for the app's ABIs and stage it into the Flutter app's
# jniLibs so `flutter build apk --flavor <full|play>` packages it.
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
