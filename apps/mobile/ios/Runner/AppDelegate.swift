import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let liveActivityManager = RunLiveActivityManager()
  private let liveActivityChannelName = "com.davidgd616.striviq/live_activity"
  private var liveActivityChannel: FlutterMethodChannel?

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if openActiveRunURL(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerLiveActivityChannel(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
  }

  private func registerLiveActivityChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: liveActivityChannelName,
      binaryMessenger: binaryMessenger
    )
    liveActivityChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "startActivity":
        if let data = call.arguments as? [String: Any] {
          liveActivityManager.startActivity(data: data)
        }
        result(nil)
      case "updateActivity":
        if let data = call.arguments as? [String: Any] {
          liveActivityManager.updateActivity(data: data)
        }
        result(nil)
      case "endActivity":
        liveActivityManager.endActivity()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Asks the Dart side to bring the active-run screen into focus without
  /// restarting it. Safe to call from SceneDelegate via UIApplication.shared.delegate.
  func focusActiveRun() {
    liveActivityChannel?.invokeMethod("focusActiveRun", arguments: nil)
  }

  private func openActiveRunURL(_ url: URL) -> Bool {
    guard url.scheme == "striviq",
          url.host == "active-run" else {
      return false
    }
    focusActiveRun()
    return true
  }
}
