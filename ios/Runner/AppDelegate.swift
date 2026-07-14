import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeDownloadsFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
