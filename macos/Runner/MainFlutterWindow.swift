import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Vertical center of the app-drawn 52px title band, in points from the
  /// window's top edge.
  private let bandCenterFromTop: CGFloat = 26

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // The app draws its own 52px title band (window_manager hides the native
    // title bar — see DesktopIntegration.init). The traffic lights stay
    // native but are re-centered on the band's midline by nudging their
    // frames (the Electron approach). An empty toolbar would center them for
    // free, but on macOS 26 a toolbar also reclassifies the window into the
    // extra-round corner appearance — plain-window corners, matching every
    // other app, win. AppKit re-lays the buttons out on resize/key changes,
    // so the nudge re-runs on those notifications.
    let center = NotificationCenter.default
    for name: Notification.Name in [
      NSWindow.didResizeNotification,
      NSWindow.didBecomeKeyNotification,
      NSWindow.didBecomeMainNotification,
      NSWindow.didExitFullScreenNotification,
    ] {
      center.addObserver(
        self, selector: #selector(centerTrafficLights),
        name: name, object: self)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    centerTrafficLights()
  }

  @objc private func centerTrafficLights() {
    guard !styleMask.contains(.fullScreen) else { return }
    let types: [NSWindow.ButtonType] = [
      .closeButton, .miniaturizeButton, .zoomButton,
    ]
    guard let container = standardWindowButton(.closeButton)?.superview
    else { return }
    // The buttons hang below the ~28pt titlebar container when centered in
    // the 52pt band; without this they'd be clipped at its edge.
    container.clipsToBounds = false
    for type in types {
      guard let button = standardWindowButton(type) else { continue }
      let y =
        container.frame.height - bandCenterFromTop - button.frame.height / 2
      button.setFrameOrigin(NSPoint(x: button.frame.origin.x, y: y))
    }
  }
}
