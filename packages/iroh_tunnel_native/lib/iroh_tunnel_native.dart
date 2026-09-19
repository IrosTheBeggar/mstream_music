/// iOS packaging shell for the Rust iroh tunnel — no Dart API.
///
/// This package exists so Flutter's Swift Package Manager support downloads,
/// links and embeds the prebuilt `iroh_tunnel.xcframework` of a
/// mstream-iroh-tunnel release (a remote binaryTarget: url + checksum in
/// `Package.swift`, moved by `tool/fetch-iroh-tunnel.sh`) into the iOS
/// Runner. The actual FFI bindings live in the app at
/// `lib/native/iroh_tunnel.dart`, which loads the embedded framework via
/// `DynamicLibrary.open('iroh_tunnel.framework/iroh_tunnel')`.
///
/// Android does not use this package: the same release's `libiroh_tunnel.so`
/// is fetched at build time by a Gradle task in `android/app/build.gradle`,
/// pinned by `tool/iroh-tunnel.properties`.
library iroh_tunnel_native;
