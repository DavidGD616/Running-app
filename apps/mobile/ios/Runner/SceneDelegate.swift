import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // Handle Live Activity URL delivered on first tap after engine suspension.
    // iOS routes the URL through connectionOptions.urlContexts here instead of
    // openURLContexts when the Dart engine / scene was suspended or terminated.
    if connectionOptions.urlContexts.contains(where: { openActiveRunURL($0.url) }) {
      // Still call super so Flutter engine initialises normally.
      super.scene(scene, willConnectTo: session, options: connectionOptions)
      return
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    if URLContexts.contains(where: { openActiveRunURL($0.url) }) {
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  private func openActiveRunURL(_ url: URL) -> Bool {
    guard url.scheme == "striviq",
          url.host == "active-run" else {
      return false
    }
    (UIApplication.shared.delegate as? AppDelegate)?.focusActiveRun()
    return true
  }
}
