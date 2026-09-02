import Flutter
import UIKit

/// The phone window. Builds its own window around a FlutterViewController on
/// the app-owned engine (no storyboard: the storyboard would create a second,
/// implicit engine) and registers that engine for scene life-cycle events by
/// hand — with UIApplicationSupportsMultipleScenes on (a CarPlay requirement)
/// Flutter no longer does that automatically.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let engine = AppDelegate.shared.engine!
    let window = UIWindow(windowScene: windowScene)
    if engine.viewController == nil {
      window.rootViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
      _ = registerSceneLifeCycle(with: engine)
    } else {
      // iPad "New Window": the engine already renders in another window and a
      // second FlutterViewController on one engine is not supported. Show why,
      // and ask the system to take this window down again.
      window.rootViewController = AlreadyOpenViewController()
      UIApplication.shared.requestSceneSessionDestruction(session, options: nil, errorHandler: nil)
    }
    self.window = window
    window.makeKeyAndVisible()
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    super.sceneDidDisconnect(scene)
    guard let engine = AppDelegate.shared.engine,
      window?.rootViewController is FlutterViewController
    else { return }
    _ = unregisterSceneLifeCycle(with: engine)
    // Let go of the view controller so the next phone scene can attach a fresh
    // one; the engine — and the music — keep running.
    engine.viewController = nil
  }
}

/// Placeholder for a second phone window (iPad multitasking).
final class AlreadyOpenViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    let label = UILabel()
    label.text = "mStream is already open in another window."
    label.textAlignment = .center
    label.numberOfLines = 0
    label.textColor = .secondaryLabel
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
    ])
  }
}
