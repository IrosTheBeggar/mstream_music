import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
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

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
