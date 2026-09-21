import CryptoKit
import Flutter
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

/// `mstream/now_playing_widget` on iOS.
///
/// Dart pushes a snapshot ("publish"); this writes it as JSON into the App
/// Group container the WidgetKit extension (ios/NowPlayingWidget) reads,
/// fetches the cover into the same container, and asks WidgetKit to reload.
/// The extension never runs Dart: it draws whatever is in the container.
///
/// The buttons come back the other way. On iOS 17+ they are App Intents
/// conforming to AudioPlaybackIntent, which the system runs IN THIS PROCESS
/// (launching the app in the background when it is not running); the intent
/// calls [perform], which hands the action to Dart over the channel. A cold
/// launch has the intent arriving before the Dart side has registered its
/// handler, so an action waits for the "ready" handshake — the same idea as
/// the Android side holding a tap until the handler is up.
public class NowPlayingWidgetPlugin: NSObject, FlutterPlugin {
  /// Shared with the extension's entitlements and its code.
  public static let appGroup = "group.mstream.music"
  public static let widgetKind = "NowPlayingWidget"
  static let snapshotFile = "snapshot.json"
  static let maxArtPx: CGFloat = 512
  /// Covers kept on disk (the latest plus a few for a back-and-forth skip).
  static let keepArt = 6
  /// An action that waited longer than this for Dart is stale.
  static let pendingTtl: TimeInterval = 30

  private static weak var current: NowPlayingWidgetPlugin?
  private static var pending: (action: String, at: Date)?

  private let channel: FlutterMethodChannel
  private let session = URLSession(configuration: .ephemeral)
  private var dartReady = false
  private var generation = 0

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "mstream/now_playing_widget", binaryMessenger: registrar.messenger())
    let instance = NowPlayingWidgetPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    current = instance
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "publish":
      publish(call.arguments as? [String: Any] ?? [:])
      result(nil)
    case "ready":
      dartReady = true
      flushPending()
      result(nil)
    case "requestPin":
      result(false)  // no such API on iOS: the user adds widgets from the home screen
    case "debugForceLayout":
      result("auto")
    case "debugState":
      result(debugState())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Intents → Dart

  /// An App Intent, running in this process, asks for a transport action:
  /// `play`, `pause`, `next`, `previous`, `shuffle`, `repeat`.
  public static func perform(_ action: String) {
    if let plugin = current, plugin.dartReady {
      plugin.channel.invokeMethod("action", arguments: action)
      NSLog("[widget] %@: sent", action)
    } else {
      pending = (action, Date())
      NSLog("[widget] %@: Dart not up yet, holding", action)
    }
  }

  private func flushPending() {
    guard let p = NowPlayingWidgetPlugin.pending else { return }
    NowPlayingWidgetPlugin.pending = nil
    if Date().timeIntervalSince(p.at) > NowPlayingWidgetPlugin.pendingTtl {
      NSLog("[widget] %@: held too long, dropped", p.action)
      return
    }
    channel.invokeMethod("action", arguments: p.action)
    NSLog("[widget] %@: sent after the handshake", p.action)
  }

  // MARK: - Snapshot → container

  static var container: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
  }

  private func publish(_ snapshot: [String: Any]) {
    guard let dir = NowPlayingWidgetPlugin.container else {
      NSLog("[widget] no App Group container (entitlement missing?)")
      return
    }
    generation += 1
    let gen = generation
    var json = snapshot.filter { JSONSerialization.isValidJSONObject([$0.value]) }
    // The art URL carries the server's session token: it stays in this
    // process; the container gets the cover's file name only.
    json.removeValue(forKey: "artUrl")
    json["updatedAt"] = Date().timeIntervalSince1970
    let hasTrack = snapshot["hasTrack"] as? Bool ?? false
    let artUrl = snapshot["artUrl"] as? String ?? ""
    let key = (hasTrack && !artUrl.isEmpty) ? NowPlayingWidgetPlugin.artKey(artUrl) : ""
    let artName = key.isEmpty ? "" : "art-\(key).jpg"
    let cached = !artName.isEmpty && FileManager.default.fileExists(atPath: dir.appendingPathComponent(artName).path)
    // Draw at once with the cover already on disk (or none), then again once
    // a missing cover has been fetched. The art URL itself never lands in the
    // container: it carries the server's session token.
    json["artFile"] = cached ? artName : ""
    write(json, to: dir)
    NowPlayingWidgetPlugin.reload()
    if cached || artName.isEmpty { return }
    fetchArt(artUrl) { [weak self] image in
      guard let self = self, gen == self.generation, let image = image else { return }
      guard let data = image.jpegData(compressionQuality: 0.88) else { return }
      let file = dir.appendingPathComponent(artName)
      do {
        try data.write(to: file, options: .atomic)
      } catch {
        NSLog("[widget] art write failed: %@", error.localizedDescription)
        return
      }
      NowPlayingWidgetPlugin.prune(dir, keep: artName)
      json["artFile"] = artName
      self.write(json, to: dir)
      NowPlayingWidgetPlugin.reload()
    }
  }

  private func write(_ json: [String: Any], to dir: URL) {
    do {
      let data = try JSONSerialization.data(withJSONObject: json, options: [])
      try data.write(to: dir.appendingPathComponent(NowPlayingWidgetPlugin.snapshotFile), options: .atomic)
    } catch {
      NSLog("[widget] snapshot write failed: %@", error.localizedDescription)
    }
  }

  static func reload() {
    #if canImport(WidgetKit)
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
    #endif
  }

  // MARK: - Art

  /// The cover, sized for the widget: capped at [maxArtPx] on the longer side.
  private func fetchArt(_ url: String, completion: @escaping (UIImage?) -> Void) {
    guard let u = URL(string: url) else { return completion(nil) }
    let finish: (Data?) -> Void = { data in
      let image = data.flatMap(UIImage.init(data:)).map(NowPlayingWidgetPlugin.fit)
      DispatchQueue.main.async { completion(image) }
    }
    if u.isFileURL {
      finish(try? Data(contentsOf: u))
      return
    }
    // Plain URLSession, like CarPlay's art loader: a self-signed server's
    // cover is not fetched here (the app's own trust override is Dart-side).
    session.dataTask(with: u) { data, response, error in
      if let error = error {
        NSLog("[widget] art fetch failed for %@: %@", u.host ?? "?", error.localizedDescription)
        return finish(nil)
      }
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        return finish(nil)
      }
      finish(data)
    }.resume()
  }

  static func fit(_ image: UIImage) -> UIImage {
    let longest = max(image.size.width, image.size.height)
    guard longest > maxArtPx, longest > 0 else { return image }
    let scale = maxArtPx / longest
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }

  /// Token-blind: the URL without its query, plus the `compress` size — the
  /// same stable part the Android side and ArtContentProvider key on.
  static func artKey(_ url: String) -> String {
    let parts = url.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
    let base = String(parts.first ?? "")
    let compress = parts.count > 1
      ? parts[1].split(separator: "&").first { $0.hasPrefix("compress=") }.map(String.init) ?? ""
      : ""
    let digest = Insecure.MD5.hash(data: Data("\(base)?\(compress)".utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private static func prune(_ dir: URL, keep: String) {
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
    let art = names.filter { $0.hasPrefix("art-") && $0.hasSuffix(".jpg") && $0 != keep }
    let dated = art.map { name -> (String, Date) in
      let attrs = try? FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent(name).path)
      return (name, attrs?[.modificationDate] as? Date ?? .distantPast)
    }.sorted { $0.1 > $1.1 }
    for (name, _) in dated.dropFirst(keepArt - 1) {
      try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
    }
  }

  // MARK: - Debug

  private func debugState() -> [String: Any] {
    var state: [String: Any] = ["dartUp": dartReady, "pending": NowPlayingWidgetPlugin.pending?.action ?? ""]
    guard let dir = NowPlayingWidgetPlugin.container else {
      state["container"] = false
      return state
    }
    state["container"] = true
    if let data = try? Data(contentsOf: dir.appendingPathComponent(NowPlayingWidgetPlugin.snapshotFile)),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      state["snapshot"] = json
      if let art = json["artFile"] as? String, !art.isEmpty {
        state["artCached"] = FileManager.default.fileExists(atPath: dir.appendingPathComponent(art).path)
      } else {
        state["artCached"] = false
      }
    }
    return state
  }
}
