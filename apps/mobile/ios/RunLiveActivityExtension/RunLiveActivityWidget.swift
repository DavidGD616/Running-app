import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RunLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOS 16.1, *) {
      RunLiveActivityWidget()
    }
  }
}

@available(iOS 16.1, *)
struct RunLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RunActivityAttributes.self) { context in
      RunLockScreenView(context: context)
        .activityBackgroundTint(Color(red: 0.06, green: 0.07, blue: 0.08))
        .activitySystemActionForegroundColor(.white)
        .widgetURL(URL(string: "striviq://active-run"))
    } dynamicIsland: { context in
      let isStructured = context.state.isStructuredSession

      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            if isStructured,
              !context.state.currentBlockLabel.isEmpty {
              Text(phaseContextLabel(context.state))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
              if let remainingRow = context.state.blockRemainingLabel,
                !remainingRow.isEmpty {
                Text(remainingRow)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .minimumScaleFactor(0.75)
              }
              Text(context.state.currentPaceLabel)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            } else {
              MetricLabel(
                title: context.state.currentPaceTitleLabel,
                value: context.state.currentPaceLabel
              )
              if !context.state.targetContextLabel.isEmpty {
                Text(context.state.targetContextLabel)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .minimumScaleFactor(0.75)
              }
            }
          }
        }

        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 4) {
            TimerText(state: context.state)
              .font(.system(.title3, design: .rounded).monospacedDigit())
              .lineLimit(1)
            Text(context.state.distanceLabel)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .minimumScaleFactor(0.75)
          }
        }

        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 2) {
            HStack {
              Text(context.attributes.workoutName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
              Spacer()
              Text(context.state.statusLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.teal)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }

            if isStructured,
              let nextBlockLabel = context.state.nextBlockLabel {
              HStack(spacing: 3) {
                Text(context.state.nextBlockTitleLabel)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                Text(nextBlockLabel)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .minimumScaleFactor(0.75)
              }
            } else if !context.state.targetContextLabel.isEmpty {
              Text(context.state.targetContextLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
          }
        }
      } compactLeading: {
        if isStructured,
          !context.state.currentBlockLabel.isEmpty {
          Text(phaseContextLabel(context.state))
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        } else {
          Text(context.state.currentPaceLabel)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
      } compactTrailing: {
        TimerText(state: context.state)
          .font(.caption2.monospacedDigit())
          .lineLimit(1)
      } minimal: {
        Image(systemName: "figure.run")
      }
      .widgetURL(URL(string: "striviq://active-run"))
    }
  }
}

@available(iOS 16.1, *)
private func phaseContextLabel(_ state: RunActivityAttributes.ContentState) -> String {
  guard !state.currentBlockLabel.isEmpty else { return "" }
  if let repLabel = state.repLabel, !repLabel.isEmpty {
    return "\(repLabel) · \(state.currentBlockLabel)"
  }
  return state.currentBlockLabel
}

@available(iOS 16.1, *)
private struct RunLockScreenView: View {
  let context: ActivityViewContext<RunActivityAttributes>

  private var isStructuredSession: Bool {
    context.state.isStructuredSession
  }

  private var remainingRow: String? {
    guard let remaining = context.state.blockRemainingLabel else { return nil }
    return remaining.isEmpty ? nil : remaining
  }

  private var targetContextRow: String? {
    context.state.targetContextLabel.isEmpty ? nil : context.state.targetContextLabel
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(context.attributes.workoutName)
          .font(.system(size: 14, weight: .semibold, design: .default))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
        Spacer(minLength: 8)
        Text(context.state.statusLabel)
          .font(.system(size: 14, weight: .semibold, design: .default))
          .foregroundStyle(.teal)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }

      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 4) {
          Text(context.state.distanceLabel)
            .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.85)
          Text(context.state.distanceTitleLabel)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.3)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .center, spacing: 4) {
          TimerText(state: context.state)
            .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
          Text(context.state.elapsedUnitLabel)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.3)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)

        VStack(alignment: .trailing, spacing: 4) {
          Text(shortPaceValue(context.state.avgPaceLabel))
            .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.85)
          Text(context.state.avgPaceTitleLabel)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.3)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }

      ProgressView(value: context.state.blockProgressFraction)
        .tint(.green)
        .frame(height: 6)

      if isStructuredSession {
        VStack(alignment: .leading, spacing: 4) {
          HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
              if !context.state.currentBlockLabel.isEmpty {
                Text(phaseContextLabel(context.state))
                  .font(.system(size: 18, weight: .semibold, design: .default))
                  .lineLimit(1)
                  .minimumScaleFactor(0.72)
              }
              if let remainingRow {
                Text(remainingRow)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .minimumScaleFactor(0.75)
              } else if let targetContextRow {
                Text(targetContextRow)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .minimumScaleFactor(0.75)
              }
            }

            Spacer()

            PaceSupportStack(state: context.state)
          }

          if let nextBlockLabel = context.state.nextBlockLabel {
            HStack(spacing: 4) {
              Text(context.state.nextBlockTitleLabel)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(.secondary)
                .lineLimit(1)
              Text(nextBlockLabel)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 3) {
          Text(context.state.currentPaceLabel)
            .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.82)
          Text(context.state.currentPaceTitleLabel)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.3)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          if let targetContextRow {
            Text(targetContextRow)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.white)
              .lineLimit(1)
              .minimumScaleFactor(0.75)
          }
        }
      }
    }
    .padding()
    .foregroundStyle(.white)
  }

  private func shortPaceValue(_ label: String) -> String {
    guard let first = label.split(separator: " ").first else { return label }
    return String(first)
  }
}

@available(iOS 16.1, *)
private struct PaceSupportStack: View {
  let state: RunActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .trailing, spacing: 2) {
      Text(state.currentPaceLabel)
        .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.75)
      Text(state.currentPaceTitleLabel)
        .font(.system(size: 10, weight: .semibold))
        .tracking(0.3)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }
}

@available(iOS 16.1, *)
private struct TimerText: View {
  let state: RunActivityAttributes.ContentState

  var body: some View {
    if state.isPaused {
      Text(state.elapsedLabel)
    } else if let timerStartedAt = state.timerStartedAt {
      Text(timerStartedAt, style: .timer)
    } else {
      Text(state.elapsedLabel)
    }
  }
}

private struct MetricRow: View {
  let title: String
  let value: String

  var body: some View {
    HStack {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(.subheadline.weight(.semibold).monospacedDigit())
    }
  }
}

private struct MetricLabel: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.caption.weight(.semibold).monospacedDigit())
        .lineLimit(1)
    }
  }
}
