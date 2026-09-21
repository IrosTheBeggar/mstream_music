import AppIntents
import Foundation

/// The widget's buttons on iOS 17+. Each is an AudioPlaybackIntent, which the
/// system runs IN THE APP'S PROCESS (launching it in the background when it
/// is not running) rather than in the widget extension — the only place the
/// audio handler exists. This file is compiled into both targets: the
/// extension references the types for its buttons; the app performs them.
///
/// The app installs [NowPlayingIntentBridge.handler] (AppDelegate) to route a
/// performed intent into the plugin, which hands it to Dart; in the extension
/// the handler stays nil and `perform` is never called.
enum NowPlayingIntentBridge {
  static var handler: ((String) -> Void)?

  static func perform(_ action: String) {
    if let h = handler {
      h(action)
    } else {
      NSLog("[widget] %@: no handler in this process", action)
    }
  }
}

@available(iOS 17.0, *)
struct NowPlayingPlayIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "Play"
  func perform() async throws -> some IntentResult {
    NowPlayingIntentBridge.perform("play")
    return .result()
  }
}

@available(iOS 17.0, *)
struct NowPlayingPauseIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "Pause"
  func perform() async throws -> some IntentResult {
    NowPlayingIntentBridge.perform("pause")
    return .result()
  }
}

@available(iOS 17.0, *)
struct NowPlayingNextIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "Next track"
  func perform() async throws -> some IntentResult {
    NowPlayingIntentBridge.perform("next")
    return .result()
  }
}

@available(iOS 17.0, *)
struct NowPlayingPreviousIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "Previous track"
  func perform() async throws -> some IntentResult {
    NowPlayingIntentBridge.perform("previous")
    return .result()
  }
}

@available(iOS 17.0, *)
struct NowPlayingShuffleIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "Shuffle"
  func perform() async throws -> some IntentResult {
    NowPlayingIntentBridge.perform("shuffle")
    return .result()
  }
}

@available(iOS 17.0, *)
struct NowPlayingRepeatIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "Repeat"
  func perform() async throws -> some IntentResult {
    NowPlayingIntentBridge.perform("repeat")
    return .result()
  }
}
