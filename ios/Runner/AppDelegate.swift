import Flutter
import Intents
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  static var shared: AppDelegate { UIApplication.shared.delegate as! AppDelegate }

  /// The one Flutter engine, owned by the app rather than by the phone
  /// window's view controller. CarPlay can launch the app with no phone scene
  /// at all (phone locked, icon tapped on the car display), and the Dart side
  /// — audio_service handler, servers, the Quick Connect tunnel — must be up
  /// for that. The phone scene attaches a FlutterViewController to this engine
  /// whenever it connects (SceneDelegate); the CarPlay scene talks to it over
  /// a method channel (CarPlay.swift). Never create a second engine: two Dart
  /// isolates would split the audio state.
  private(set) var engine: FlutterEngine!
  private(set) var carPlay: CarPlayBridge!
  private(set) var siri: SiriMediaHandler!

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeDownloadsFromBackup()
    let engine = FlutterEngine(name: "mstream")
    engine.run(withEntrypoint: nil)
    GeneratedPluginRegistrant.register(with: engine)
    self.engine = engine
    carPlay = CarPlayBridge(messenger: engine.binaryMessenger)
    siri = SiriMediaHandler(bridge: carPlay)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// SiriKit media intents are handled in-app (iOS 14+): "play <X> on
  /// mStream" resolves against the library and plays through the audio
  /// handler, with the app launched in the background if it was not running.
  override func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
    if intent is INPlayMediaIntent { return siri }
    return nil
  }

  // Keep downloaded music out of iCloud backups: it's re-fetchable from the
  // user's server and can run to many GB (App Review checks for exactly this).
  // The flag is set on the downloads directory — the backup daemon skips the
  // whole subtree — and re-applied every launch because the app container
  // (and therefore the URL the flag was set on) moves across app updates.
  // Scoped to Documents/media, NOT all of Documents, so app databases stay
  // backed up.
  private func excludeDownloadsFromBackup() {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    var media = docs.appendingPathComponent("media", isDirectory: true)
    try? FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? media.setResourceValues(values)
  }
}
