/// iOS packaging shell for the Rust visualizer audio sidecar — no Dart API.
///
/// This package exists so Flutter's Swift Package Manager support links and
/// embeds the prebuilt `viz_decoder.xcframework` (built by
/// `rust/viz_decoder/build-ios.sh`) into the iOS Runner. The actual FFI
/// bindings live in the app at `lib/native/viz_decoder.dart`, which loads
/// the embedded framework via
/// `DynamicLibrary.open('viz_decoder.framework/viz_decoder')`.
library;
