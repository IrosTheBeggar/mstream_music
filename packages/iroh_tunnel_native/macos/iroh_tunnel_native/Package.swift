// swift-tools-version: 5.9
// Vends the prebuilt Rust iroh tunnel (rust/iroh_tunnel) to the
// macOS Runner as a dynamic xcframework — the macOS twin of the ios/ package.
// Flutter's SwiftPM integration links it into the app and Xcode embeds +
// signs it automatically. Rebuild the binary with
// rust/iroh_tunnel/build-macos.sh (the xcframework is committed to git).
import PackageDescription

let package = Package(
    // MUST match the pubspec plugin name — flutter_tools emits
    // .package(name: "iroh_tunnel_native", path: <symlink>).
    name: "iroh_tunnel_native",
    platforms: [
        // Match FlutterGeneratedPluginSwiftPackage's default so a direct
        // `flutter pub get` never leaves the graph unbuildable (the same
        // lesson as the iOS package — see its comment). The binary itself is
        // arm64-only with an 11.0 minos; 10.15 here only sets the SPM floor.
        .macOS("10.15")
    ],
    products: [
        // Product name MUST be the pubspec name with '_' -> '-'.
        .library(name: "iroh-tunnel-native", targets: ["iroh_tunnel"])
    ],
    targets: [
        .binaryTarget(
            name: "iroh_tunnel",
            path: "Frameworks/iroh_tunnel.xcframework"
        )
    ]
)
