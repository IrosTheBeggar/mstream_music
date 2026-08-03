import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// The window frame's corner radius. The empty toolbar below puts the
  /// window in macOS 26's very-round "toolbar window" appearance class;
  /// there's no public NSWindow API for the radius, so the theme frame's
  /// layer is masked back to this tighter curve (plain CALayer properties —
  /// worst case a future OS ignores it and corners revert to system).
  private let frameCornerRadius: CGFloat = 10

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // The app draws its own 52px title band (window_manager hides the native
    // title bar — see DesktopIntegration.init). An empty unified toolbar makes
    // the invisible titlebar that tall, which is what vertically centers the
    // traffic-light buttons in the band; without it they hug the window's top
    // edge at the standard 28px titlebar position.
    let toolbar = NSToolbar(identifier: "band")
    toolbar.showsBaselineSeparator = false
    self.toolbar = toolbar
    if #available(macOS 11.0, *) {
      self.toolbarStyle = .unified
    }

    // Transparent window surface so the corners clipped by the frame mask
    // show the desktop through; the shadow re-derives from the drawn shape.
    self.isOpaque = false
    self.backgroundColor = .clear

    // Re-apply whenever AppKit might have rebuilt or resized the frame view
    // (window_manager mutates styleMask after this method runs), and lift
    // the mask in fullscreen where corners must be square.
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(applyFrameCornerMask),
      name: NSWindow.didResizeNotification, object: self)
    center.addObserver(
      self, selector: #selector(applyFrameCornerMask),
      name: NSWindow.didBecomeKeyNotification, object: self)
    center.addObserver(
      self, selector: #selector(removeFrameCornerMask),
      name: NSWindow.willEnterFullScreenNotification, object: self)
    center.addObserver(
      self, selector: #selector(applyFrameCornerMask),
      name: NSWindow.didExitFullScreenNotification, object: self)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    applyFrameCornerMask()
  }

  @objc private func applyFrameCornerMask() {
    guard styleMask.contains(.fullScreen) == false,
          let frameView = contentView?.superview else { return }
    frameView.wantsLayer = true
    frameView.layer?.cornerRadius = frameCornerRadius
    frameView.layer?.cornerCurve = .continuous
    frameView.layer?.masksToBounds = true
    invalidateShadow()
  }

  @objc private func removeFrameCornerMask() {
    guard let frameView = contentView?.superview else { return }
    frameView.layer?.cornerRadius = 0
    frameView.layer?.masksToBounds = false
    invalidateShadow()
  }
}
