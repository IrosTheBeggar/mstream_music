// swift-tools-version: 5.9
// Vends the prebuilt Rust visualizer audio sidecar (rust/viz_decoder) to
// Runner as a dynamic xcframework. Flutter's SwiftPM integration links it
// into the app and Xcode embeds + signs it automatically. Rebuild the binary
// with rust/viz_decoder/build-ios.sh (the xcframework is committed to git).
import PackageDescription

let package = Package(
    // MUST match the pubspec plugin name — flutter_tools emits
    // .package(name: "viz_decoder_native", path: <symlink>).
    name: "viz_decoder_native",
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
        // flutter_tools depends on .product(name: "viz-decoder-native", ...).
        .library(name: "viz-decoder-native", targets: ["viz_decoder"])
    ],
    targets: [
        // The path must stay inside this package directory — the Flutter tool
        // symlinks the package into ios/Flutter/ephemeral, so ../ escapes
        // would resolve against the symlink location.
        .binaryTarget(
            name: "viz_decoder",
            path: "Frameworks/viz_decoder.xcframework"
        )
    ]
)
