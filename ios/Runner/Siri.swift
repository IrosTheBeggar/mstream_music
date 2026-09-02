import Foundation
import Intents

/// "Hey Siri, play <X> on mStream." SiriKit media intent, handled in-app
/// (AppDelegate.application(_:handlerFor:)). Resolution is the browse tree's
/// search over the `mstream/carplay` channel — tracks, then albums, then
/// artists — and the chosen node plays through the same path a CarPlay tap
/// uses, so Auto DJ, the Quick Connect tunnel and offline copies all apply.
final class SiriMediaHandler: NSObject, INPlayMediaIntentHandling {
  private let bridge: CarPlayBridge
  /// Siri may ask for up to this many candidates; the first is what plays.
  private static let maxCandidates = 5

  init(bridge: CarPlayBridge) {
    self.bridge = bridge
  }

  // MARK: - INPlayMediaIntentHandling

  func resolveMediaItems(
    for intent: INPlayMediaIntent,
    with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void
  ) {
    let search = intent.mediaSearch
    let query = [search?.mediaName, search?.albumName, search?.artistName]
      .compactMap { $0 }.first { !$0.isEmpty } ?? ""
    guard !query.isEmpty else {
      NSLog("[siri] resolve: nothing to search for")
      completion([INPlayMediaMediaItemResolutionResult.unsupported()])
      return
    }
    bridge.call("searchMedia", query) { payload in
      let rows = payload as? [[String: Any]] ?? []
      let items = rows.prefix(SiriMediaHandler.maxCandidates).compactMap(SiriMediaHandler.mediaItem)
      NSLog("[siri] resolve(\"%@\"): %d candidates", query, items.count)
      if items.isEmpty {
        completion([INPlayMediaMediaItemResolutionResult.unsupported()])
      } else {
        completion(INPlayMediaMediaItemResolutionResult.successes(with: items))
      }
    }
  }

  func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
    guard let item = intent.mediaItems?.first, let id = item.identifier else {
      NSLog("[siri] handle: no media item")
      completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
      return
    }
    NSLog("[siri] handle: %@", item.title ?? id)
    bridge.call("playMedia", id) { _ in
      completion(INPlayMediaIntentResponse(code: .success, userActivity: nil))
    }
  }

  // MARK: - Helpers

  private static func mediaItem(_ row: [String: Any]) -> INMediaItem? {
    guard let id = row["id"] as? String, let title = row["title"] as? String else { return nil }
    let type: INMediaItemType
    switch row["kind"] as? String {
    case "album": type = .album
    case "artist": type = .artist
    case "track": type = .song
    default: type = .music
    }
    return INMediaItem(identifier: id, title: title, type: type, artwork: nil, artist: row["subtitle"] as? String)
  }

  #if DEBUG
  /// The Siri flow without speech: resolve `query`, then handle the resolved
  /// items the way Siri would. Reports the candidate titles and the response.
  func dryRun(query: String, completion: @escaping ([String: Any]) -> Void) {
    let search = INMediaSearch(
      mediaType: .music, sortOrder: .unknown, mediaName: query, artistName: nil, albumName: nil,
      genreNames: nil, moodNames: nil, releaseDate: nil, reference: .unknown, mediaIdentifier: nil)
    let intent = INPlayMediaIntent(
      mediaItems: nil, mediaContainer: nil, playShuffled: nil, playbackRepeatMode: .unknown,
      resumePlayback: nil, playbackQueueLocation: .unknown, playbackSpeed: nil, mediaSearch: search)
    bridge.call("searchMedia", query) { payload in
      let rows = payload as? [[String: Any]] ?? []
      let items = rows.prefix(SiriMediaHandler.maxCandidates).compactMap(SiriMediaHandler.mediaItem)
      self.resolveMediaItems(for: intent) { results in
        guard !items.isEmpty else {
          completion(["candidates": [], "resolutions": results.count, "response": "not found"])
          return
        }
        let resolved = INPlayMediaIntent(
          mediaItems: items, mediaContainer: nil, playShuffled: nil, playbackRepeatMode: .unknown,
          resumePlayback: nil, playbackQueueLocation: .unknown, playbackSpeed: nil, mediaSearch: search)
        self.handle(intent: resolved) { response in
          completion([
            "candidates": items.map { "\($0.type.rawValue):\($0.title ?? "")" },
            "resolutions": results.count,
            "response": response.code.rawValue,
          ])
        }
      }
    }
  }
  #endif
}
