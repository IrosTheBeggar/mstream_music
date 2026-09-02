import CarPlay
import Flutter
import UIKit

/// The CarPlay scene. CarPlay hands us an interface controller; everything the
/// car shows comes from the Dart browse tree (lib/media/auto_browse.dart — the
/// same tree Android Auto renders) over the `mstream/carplay` method channel
/// (lib/native/carplay_bridge.dart). Now Playing is CarPlay's own template,
/// fed by the MPNowPlayingInfoCenter / remote-command state audio_service
/// already publishes.
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    AppDelegate.shared.carPlay.attach(interfaceController)
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnectInterfaceController interfaceController: CPInterfaceController
  ) {
    AppDelegate.shared.carPlay.detach()
  }
}

/// Lives for the whole process (created with the engine in AppDelegate), so it
/// is there whether the car connects before or after the Dart side is ready.
final class CarPlayBridge: NSObject {
  /// Audio apps get a template stack this deep (root included); a deep Files
  /// tree would overflow it, so at the limit the top level is swapped instead
  /// of the push failing.
  static let maxDepth = 5

  private let channel: FlutterMethodChannel
  private let art = CarPlayArtLoader()
  private var interfaceController: CPInterfaceController?
  private var rootTemplate: CPListTemplate?
  private var dartReady = false
  private var observingNowPlaying = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "mstream/carplay", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "ready":
        // Dart booted and registered its handler: (re)load the root. On a
        // CarPlay-only cold launch the car connected seconds before this.
        self?.dartReady = true
        NSLog("[carplay] dart ready (car connected: %d)", self?.interfaceController == nil ? 0 : 1)
        self?.loadRoot()
        result(nil)
      default:
        #if DEBUG
        if self?.handleDebug(call, result: result) == true { return }
        #endif
        result(FlutterMethodNotImplemented)
      }
    }
  }

  #if DEBUG
  /// Test hooks (debug builds only), driven from Dart's `ext.mstream.carplay`
  /// service extension: the Simulator's CarPlay window does not take
  /// synthetic taps, so automated runs select rows through the same handlers a
  /// real tap would invoke.
  private func handleDebug(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
    switch call.method {
    case "debugState":
      let ic = interfaceController
      let top = ic?.topTemplate
      var state: [String: Any] = [
        "connected": ic != nil,
        "dartReady": dartReady,
        "depth": ic?.templates.count ?? 0,
        "top": top.map { String(describing: type(of: $0)) } ?? "none",
      ]
      if let list = top as? CPListTemplate {
        state["title"] = list.title ?? ""
        state["items"] = list.sections.flatMap { $0.items }.map {
          ($0 as? CPListItem)?.text ?? String(describing: $0)
        }
      }
      result(state)
    case "debugTap":
      guard let ic = interfaceController, let list = ic.topTemplate as? CPListTemplate else {
        result(FlutterError(code: "no-list", message: "top template is not a list", details: nil))
        return true
      }
      let index = call.arguments as? Int ?? 0
      let items = list.sections.flatMap { $0.items }
      guard index < items.count, let item = items[index] as? CPListItem, let handler = item.handler else {
        result(FlutterError(code: "no-item", message: "no tappable row \(index) of \(items.count)", details: nil))
        return true
      }
      handler(item) { result(nil) }
    case "debugBack":
      guard let ic = interfaceController else { result(nil); return true }
      ic.popTemplate(animated: false) { _, _ in result(nil) }
    case "debugUpNext":
      showQueue()
      result(nil)
    default:
      return false
    }
    return true
  }
  #endif

  // MARK: - Scene attach / detach

  func attach(_ ic: CPInterfaceController) {
    interfaceController = ic
    let root = CPListTemplate(title: "mStream", sections: [])
    root.emptyViewTitleVariants = ["Loading…"]
    root.emptyViewSubtitleVariants = ["Starting mStream"]
    rootTemplate = root
    ic.setRootTemplate(root, animated: false, completion: nil)
    configureNowPlaying()
    NSLog("[carplay] connected (dart ready: %d)", dartReady ? 1 : 0)
    if dartReady { loadRoot() }
  }

  func detach() {
    NSLog("[carplay] disconnected")
    interfaceController = nil
    rootTemplate = nil
  }

  // MARK: - Templates

  private func loadRoot() {
    guard let root = rootTemplate else { return }
    invoke("getChildren", "root") { [weak self] payload in
      guard let self = self, let root = self.rootTemplate, root === self.rootTemplate else { return }
      let rows = payload as? [[String: Any]] ?? []
      root.emptyViewTitleVariants = ["Nothing to show"]
      root.emptyViewSubtitleVariants = ["Open mStream on your phone and add a server"]
      root.updateSections([CPListSection(items: self.listItems(rows))])
      NSLog("[carplay] root: %d rows", rows.count)
    }
  }

  private func browse(id: String, title: String, completion: @escaping () -> Void) {
    invoke("getChildren", id) { [weak self] payload in
      guard let self = self, let ic = self.interfaceController else { completion(); return }
      let rows = payload as? [[String: Any]] ?? []
      let template = CPListTemplate(
        title: title, sections: [CPListSection(items: self.listItems(rows))])
      template.emptyViewTitleVariants = ["Nothing here"]
      self.push(template, on: ic, completion: completion)
    }
  }

  private func play(id: String, completion: @escaping () -> Void) {
    invoke("play", id) { [weak self] _ in
      guard let self = self, let ic = self.interfaceController else { completion(); return }
      let nowPlaying = CPNowPlayingTemplate.shared
      if ic.topTemplate === nowPlaying {
        completion()
      } else {
        self.push(nowPlaying, on: ic, completion: completion)
      }
    }
  }

  private func push(_ template: CPTemplate, on ic: CPInterfaceController,
                    completion: @escaping () -> Void) {
    if ic.templates.count >= CarPlayBridge.maxDepth {
      NSLog("[carplay] template stack at %d — replacing the top level", ic.templates.count)
      ic.popTemplate(animated: false) { _, _ in
        ic.pushTemplate(template, animated: true) { _, _ in completion() }
      }
    } else {
      ic.pushTemplate(template, animated: true) { _, _ in completion() }
    }
  }

  /// Rows the Dart side serialised (CarPlayBridge.encodeItem): id, title,
  /// subtitle, artUri, playable, notice.
  private func listItems(_ rows: [[String: Any]]) -> [CPListItem] {
    let capped = rows.prefix(CPListTemplate.maximumItemCount)
    return capped.map { row in
      let id = row["id"] as? String ?? ""
      let title = row["title"] as? String ?? ""
      let subtitle = row["subtitle"] as? String
      let playable = row["playable"] as? Bool ?? false
      let notice = row["notice"] as? Bool ?? false
      let item = CPListItem(text: title, detailText: subtitle)
      item.accessoryType = (playable || notice) ? .none : .disclosureIndicator
      if notice { item.isEnabled = false }
      if let uri = row["artUri"] as? String, let url = URL(string: uri) {
        art.load(url) { image in item.setImage(image) }
      }
      item.handler = { [weak self] _, done in
        guard let self = self, !notice else { done(); return }
        if playable {
          self.play(id: id, completion: done)
        } else {
          self.browse(id: id, title: title, completion: done)
        }
      }
      return item
    }
  }

  // MARK: - Now Playing (Up Next = the queue)

  private func configureNowPlaying() {
    let nowPlaying = CPNowPlayingTemplate.shared
    nowPlaying.isUpNextButtonEnabled = true
    nowPlaying.upNextTitle = "Queue"
    if !observingNowPlaying {
      nowPlaying.add(self)
      observingNowPlaying = true
    }
  }

  private func showQueue() {
    invoke("getQueue", nil) { [weak self] payload in
      guard let self = self, let ic = self.interfaceController,
        let dict = payload as? [String: Any]
      else { return }
      let rows = dict["items"] as? [[String: Any]] ?? []
      let current = dict["index"] as? Int ?? -1
      let items = rows.prefix(CPListTemplate.maximumItemCount).enumerated().map {
        (index, row) -> CPListItem in
        let item = CPListItem(
          text: row["title"] as? String ?? "", detailText: row["subtitle"] as? String)
        item.isPlaying = index == current
        if let uri = row["artUri"] as? String, let url = URL(string: uri) {
          self.art.load(url) { image in item.setImage(image) }
        }
        item.handler = { [weak self] _, done in
          self?.invoke("skipToQueueItem", index) { _ in
            // Back to Now Playing, which is one level down.
            self?.interfaceController?.popTemplate(animated: true, completion: nil)
            done()
          }
        }
        return item
      }
      let template = CPListTemplate(title: "Queue", sections: [CPListSection(items: items)])
      template.emptyViewTitleVariants = ["The queue is empty"]
      self.push(template, on: ic) {}
    }
  }

  // MARK: - Channel

  /// Swift → Dart. Results land on the main thread; a Dart-side failure is
  /// logged and delivered as nil so the car never hangs on a spinner.
  private func invoke(_ method: String, _ arguments: Any?,
                      completion: @escaping (Any?) -> Void) {
    channel.invokeMethod(method, arguments: arguments) { result in
      if let error = result as? FlutterError {
        NSLog("[carplay] %@ failed: %@ %@", method, error.code, error.message ?? "")
        completion(nil)
      } else if let sentinel = result as? NSObject, sentinel === FlutterMethodNotImplemented {
        NSLog("[carplay] %@: Dart side not ready", method)
        completion(nil)
      } else {
        completion(result)
      }
    }
  }
}

extension CarPlayBridge: CPNowPlayingTemplateObserver {
  func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
    showQueue()
  }
}

/// Album art for list rows: fetched straight from the URL the Dart side hands
/// over (they self-authenticate — a token in the query, or the loopback tunnel
/// port), downscaled to CarPlay's row size, cached for the session.
final class CarPlayArtLoader {
  private let cache = NSCache<NSString, UIImage>()
  private let session = URLSession(configuration: .ephemeral)

  func load(_ url: URL, into apply: @escaping (UIImage) -> Void) {
    let key = url.absoluteString as NSString
    if let cached = cache.object(forKey: key) {
      apply(cached)
      return
    }
    session.dataTask(with: url) { [weak self] data, _, _ in
      guard let data = data, let raw = UIImage(data: data) else { return }
      let image = CarPlayArtLoader.fit(raw, into: CPListItem.maximumImageSize)
      self?.cache.setObject(image, forKey: key)
      DispatchQueue.main.async { apply(image) }
    }.resume()
  }

  private static func fit(_ image: UIImage, into size: CGSize) -> UIImage {
    guard image.size.width > size.width || image.size.height > size.height else { return image }
    let scale = min(size.width / image.size.width, size.height / image.size.height)
    let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    return UIGraphicsImageRenderer(size: target).image { _ in
      image.draw(in: CGRect(origin: .zero, size: target))
    }
  }
}
