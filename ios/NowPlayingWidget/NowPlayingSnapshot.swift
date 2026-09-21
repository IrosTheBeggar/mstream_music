import Foundation
import UIKit

/// What the app last published, read from the App Group container the plugin
/// (packages/now_playing_widget, iOS side) writes into. The extension never
/// runs Dart: this file is the whole of what it knows.
struct NowPlayingSnapshot {
  static let appGroup = "group.mstream.music"
  static let file = "snapshot.json"

  var hasTrack = false
  var title = ""
  var artist = ""
  var album = ""
  var playing = false
  var durationMs = 0
  var positionMs = 0
  /// Epoch ms at which `positionMs` was true; the progress bar runs from there.
  var positionAtMs = 0
  var speed = 1.0
  var shuffle = false
  /// "none", "all" or "one".
  var repeatMode = "none"
  var artFile = ""

  /// The second line: artist, else album, else nothing.
  var subtitle: String { artist.isEmpty ? album : artist }

  static var container: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
  }

  static func load() -> NowPlayingSnapshot {
    guard let dir = container,
      let data = try? Data(contentsOf: dir.appendingPathComponent(file)),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return NowPlayingSnapshot() }
    var s = NowPlayingSnapshot()
    s.hasTrack = json["hasTrack"] as? Bool ?? false
    s.title = json["title"] as? String ?? ""
    s.artist = json["artist"] as? String ?? ""
    s.album = json["album"] as? String ?? ""
    s.playing = json["playing"] as? Bool ?? false
    s.durationMs = (json["durationMs"] as? NSNumber)?.intValue ?? 0
    s.positionMs = (json["positionMs"] as? NSNumber)?.intValue ?? 0
    s.positionAtMs = (json["positionAtMs"] as? NSNumber)?.intValue ?? 0
    s.speed = (json["speed"] as? NSNumber)?.doubleValue ?? 1.0
    s.shuffle = json["shuffle"] as? Bool ?? false
    s.repeatMode = json["repeat"] as? String ?? "none"
    s.artFile = json["artFile"] as? String ?? ""
    return s
  }

  var art: UIImage? {
    guard !artFile.isEmpty, let dir = NowPlayingSnapshot.container else { return nil }
    return UIImage(contentsOfFile: dir.appendingPathComponent(artFile).path)
  }

  /// Where playback is now: the fix, advanced while playing, never past the end.
  func position(at now: Date = Date()) -> Int {
    guard hasTrack else { return 0 }
    var p = positionMs
    if playing && positionAtMs > 0 {
      let elapsed = now.timeIntervalSince1970 * 1000 - Double(positionAtMs)
      if elapsed > 0 { p += Int(elapsed * speed) }
    }
    if durationMs > 0 { p = min(p, durationMs) }
    return max(0, p)
  }

  /// The interval a live progress bar runs over: from where the track started
  /// (in wall-clock terms) to where it ends, at the current speed.
  var progressInterval: ClosedRange<Date>? {
    guard hasTrack, durationMs > 0, speed > 0 else { return nil }
    let now = Date()
    let start = now.addingTimeInterval(-Double(position(at: now)) / 1000 / speed)
    let end = start.addingTimeInterval(Double(durationMs) / 1000 / speed)
    return start...end
  }

  static func formatTime(_ ms: Int) -> String {
    let total = max(0, ms / 1000)
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
  }
}
