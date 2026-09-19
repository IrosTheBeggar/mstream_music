/// iOS packaging shell for the Rust iroh tunnel — no Dart API.
///
/// This package exists so Flutter's Swift Package Manager support links and
/// embeds the prebuilt `iroh_tunnel.xcframework` (built by
/// a mstream-iroh-tunnel release, staged by `tool/fetch-iroh-tunnel.sh`) into the iOS Runner. The actual FFI
/// bindings live in the app at `lib/native/iroh_tunnel.dart`, which loads
/// the embedded framework via
/// `DynamicLibrary.open('iroh_tunnel.framework/iroh_tunnel')`.
///
/// Android does not use this package: the same crate ships as a committed
/// `libiroh_tunnel.so` in `android/app/src/main/jniLibs/` (see
/// the same fetch script).
library iroh_tunnel_native;
