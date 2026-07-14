// swift-tools-version: 5.9
// Vends the prebuilt Rust iroh tunnel (rust/iroh_tunnel) to Runner as a
// dynamic xcframework. Flutter's SwiftPM integration links it into the app
// and Xcode embeds + signs it automatically. Rebuild the binary with
// rust/iroh_tunnel/build-ios.sh (the xcframework is committed to git).
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
        // The path must stay inside this package directory — the Flutter tool
        // symlinks the package into ios/Flutter/ephemeral, so ../ escapes
        // would resolve against the symlink location.
        .binaryTarget(
            name: "iroh_tunnel",
            path: "Frameworks/iroh_tunnel.xcframework"
        )
    ]
)
