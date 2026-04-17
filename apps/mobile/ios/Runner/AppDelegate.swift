import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let liveActivityManager = RunLiveActivityManager()
  private let liveActivityChannelName = "com.davidgd616.striviq/live_activity"

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

  private func openActiveRunURL(_ url: URL) -> Bool {
    guard url.scheme == "striviq",
          url.host == "active-run" else {
      return false
    }
    pushActiveRunRoute()
    return true
  }

  private func pushActiveRunRoute() {
    if let controller = window?.rootViewController as? FlutterViewController {
      controller.pushRoute("/active-run")
      return
    }

    let activeWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }
    if let controller = activeWindow?.rootViewController as? FlutterViewController {
      controller.pushRoute("/active-run")
    }
  }
}
