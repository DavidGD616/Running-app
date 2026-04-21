import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
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
