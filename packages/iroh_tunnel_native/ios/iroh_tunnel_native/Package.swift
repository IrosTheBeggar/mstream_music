// swift-tools-version: 5.9
// Vends the prebuilt Rust iroh tunnel (the mstream-iroh-tunnel crate) to Runner as a
// dynamic xcframework. Flutter's SwiftPM integration links it into the app
// and Xcode embeds + signs it automatically. The binary is not committed: it
// is a remote binaryTarget on a tagged release of the crate, which Xcode
// downloads at package resolution and checks against the checksum below
// (`swift package compute-checksum`, published with the release as
// SWIFTPM-CHECKSUMS.txt). tool/fetch-iroh-tunnel.sh <tag> rewrites the url
// and checksum lines on a bump.
import PackageDescription

let package = Package(
    // MUST match the pubspec plugin name — flutter_tools emits
    // .package(name: "iroh_tunnel_native", path: <symlink>).
    name: "iroh_tunnel_native",
    platforms: [
        // Floor matches FlutterGeneratedPluginSwiftPackage's default. Do NOT
        // raise to 15: `flutter pub get` regenerates the root package at 13.0
        // and only `flutter build/run` raises it to the project's target, so
        // declaring 15 here breaks direct-Xcode builds right after a pub get.
        // The real floor is enforced by Runner's IPHONEOS_DEPLOYMENT_TARGET
        // and the binary's LC_BUILD_VERSION minos (both 15.0).
        .iOS("13.0")
    ],
    products: [
        // Product name MUST be the pubspec name with '_' -> '-':
        // flutter_tools depends on .product(name: "iroh-tunnel-native", ...).
        .library(name: "iroh-tunnel-native", targets: ["iroh_tunnel"])
    ],
    targets: [
        // The zip holds iroh_tunnel.xcframework at its root (device + simulator
        // arm64 slices); the target name must be the framework's.
        .binaryTarget(
            name: "iroh_tunnel",
            url: "https://github.com/IrosTheBeggar/mstream-iroh-tunnel/releases/download/v0.2.0/iroh_tunnel-v0.2.0-ios.xcframework.zip",
            checksum: "9f8e4c869b170359e2a8b8d2b78ababa28da6398f4fd109adb2c639b27fd0e19"
        )
    ]
)
