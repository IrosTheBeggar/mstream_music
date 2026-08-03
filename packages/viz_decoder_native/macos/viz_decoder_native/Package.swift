// swift-tools-version: 5.9
// Vends the prebuilt Rust visualizer audio sidecar (rust/viz_decoder) to the
// macOS Runner as a dynamic xcframework — the macOS twin of the ios/ package.
// Flutter's SwiftPM integration links it into the app and Xcode embeds +
// signs it automatically. Rebuild the binary with
// rust/viz_decoder/build-macos.sh (the xcframework is committed to git).
import PackageDescription

let package = Package(
    // MUST match the pubspec plugin name — flutter_tools emits
    // .package(name: "viz_decoder_native", path: <symlink>).
    name: "viz_decoder_native",
    platforms: [
        // Match FlutterGeneratedPluginSwiftPackage's default so a direct
        // `flutter pub get` never leaves the graph unbuildable (the same
        // lesson as the iOS package — see its comment). The binary itself is
        // arm64-only with an 11.0 minos; 10.15 here only sets the SPM floor.
        .macOS("10.15")
    ],
    products: [
        // Product name MUST be the pubspec name with '_' -> '-'.
        .library(name: "viz-decoder-native", targets: ["viz_decoder"])
    ],
    targets: [
        .binaryTarget(
            name: "viz_decoder",
            path: "Frameworks/viz_decoder.xcframework"
        )
    ]
)
