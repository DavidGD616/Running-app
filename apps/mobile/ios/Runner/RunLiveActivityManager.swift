import ActivityKit
import Foundation

final class RunLiveActivityManager {
  private var implementation: Any?

  init() {
    if #available(iOS 16.1, *) {
      implementation = RunLiveActivityManagerImpl()
    }
  }

  func startActivity(data: [String: Any]) {
    if #available(iOS 16.1, *),
       let implementation = implementation as? RunLiveActivityManagerImpl {
      implementation.startActivity(data: data)
    }
  }

  func updateActivity(data: [String: Any]) {
    if #available(iOS 16.1, *),
       let implementation = implementation as? RunLiveActivityManagerImpl {
      implementation.updateActivity(data: data)
    }
  }

  func endActivity() {
    if #available(iOS 16.1, *),
       let implementation = implementation as? RunLiveActivityManagerImpl {
      implementation.endActivity()
    }
  }
}

@available(iOS 16.1, *)
private final class RunLiveActivityManagerImpl {
  private var activity: Activity<RunActivityAttributes>?

  func startActivity(data: [String: Any]) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

    let attributes = RunActivityAttributes(
      workoutName: stringValue("workoutName", in: data)
    )
    let state = makeContentState(from: data)

    Task {
      do {
        if let activity {
          if #available(iOS 16.2, *) {
            await activity.update(
              ActivityContent(state: state, staleDate: staleDate())
            )
          } else {
            await activity.update(using: state)
          }
          return
        }

        if #available(iOS 16.2, *) {
          activity = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: staleDate()),
            pushType: nil
          )
        } else {
          activity = try Activity.request(
            attributes: attributes,
            contentState: state,
            pushType: nil
          )
        }
      } catch {
        debugPrint("[RunLiveActivityManager] start failed: \(error)")
      }
    }
  }

  func updateActivity(data: [String: Any]) {
    let state = makeContentState(from: data)
    Task {
      guard let activity else { return }
      if #available(iOS 16.2, *) {
        await activity.update(
          ActivityContent(state: state, staleDate: staleDate())
        )
      } else {
        await activity.update(using: state)
      }
    }
  }

  func endActivity() {
    Task {
      guard let activity else { return }
      if #available(iOS 16.2, *) {
        await activity.end(nil, dismissalPolicy: .immediate)
      } else {
        await activity.end(dismissalPolicy: .immediate)
      }
      self.activity = nil
    }
  }

  private func makeContentState(
    from data: [String: Any]
  ) -> RunActivityAttributes.ContentState {
    let elapsedSeconds = intValue("elapsedSeconds", in: data)
    let isPaused = boolValue("isPaused", in: data)
    let timerStartedAt = isPaused
      ? nil
      : Date().addingTimeInterval(-Double(elapsedSeconds))

    return RunActivityAttributes.ContentState(
      statusLabel: stringValue("statusLabel", in: data),
      timerStartedAt: timerStartedAt,
      elapsedLabel: stringValue("elapsedLabel", in: data, fallback: "00:00"),
      isPaused: isPaused,
      distanceLabel: stringValue("distanceLabel", in: data),
      currentPaceTitleLabel: stringValue("currentPaceTitleLabel", in: data),
      currentPaceLabel: stringValue("currentPaceLabel", in: data),
      avgPaceTitleLabel: stringValue("avgPaceTitleLabel", in: data),
      avgPaceLabel: stringValue("avgPaceLabel", in: data),
      currentBlockLabel: stringValue("currentBlockLabel", in: data),
      nextBlockLabel: optionalStringValue("nextBlockLabel", in: data),
      repLabel: optionalStringValue("repLabel", in: data)
    )
  }

  private func staleDate() -> Date {
    Date().addingTimeInterval(3600)
  }

  private func stringValue(
    _ key: String,
    in data: [String: Any],
    fallback: String = ""
  ) -> String {
    data[key] as? String ?? fallback
  }

  private func optionalStringValue(
    _ key: String,
    in data: [String: Any]
  ) -> String? {
    guard let value = data[key] as? String, !value.isEmpty else { return nil }
    return value
  }

  private func intValue(_ key: String, in data: [String: Any]) -> Int {
    if let value = data[key] as? Int { return value }
    if let value = data[key] as? NSNumber { return value.intValue }
    if let value = data[key] as? String { return Int(value) ?? 0 }
    return 0
  }

  private func boolValue(_ key: String, in data: [String: Any]) -> Bool {
    if let value = data[key] as? Bool { return value }
    if let value = data[key] as? NSNumber { return value.boolValue }
    return false
  }
}
