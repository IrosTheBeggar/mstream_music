// swift-tools-version: 5.9
// The iOS half of the home-screen widget plugin: what Dart publishes lands in
// the App Group container for the WidgetKit extension (ios/NowPlayingWidget),
// and the extension's App Intents come back through here. Shape follows
// `flutter create --template=plugin` for this Flutter version: the name must
// match the pubspec, the product name is the pubspec name with '_' -> '-'.
import PackageDescription

let package = Package(
    name: "now_playing_widget",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "now-playing-widget", targets: ["now_playing_widget"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "now_playing_widget",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
