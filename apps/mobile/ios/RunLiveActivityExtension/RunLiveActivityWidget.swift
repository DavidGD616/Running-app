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
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            MetricLabel(
              title: context.state.currentPaceTitleLabel,
              value: context.state.currentPaceLabel
            )
            MetricLabel(
              title: context.state.avgPaceTitleLabel,
              value: context.state.avgPaceLabel
            )
          }
        }

        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 4) {
            TimerText(state: context.state)
              .font(.system(.title3, design: .rounded).monospacedDigit())
            Text(context.state.distanceLabel)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 3) {
            HStack {
              Text(context.attributes.workoutName)
                .font(.caption.weight(.semibold))
              Spacer()
              Text(context.state.statusLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.teal)
            }
            Text(context.state.currentBlockLabel)
              .font(.caption2)
              .foregroundStyle(.secondary)
            if let nextBlockLabel = context.state.nextBlockLabel {
              Text(nextBlockLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
        }
      } compactLeading: {
        Text(context.state.distanceLabel)
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
      } compactTrailing: {
        TimerText(state: context.state)
          .font(.caption2.monospacedDigit())
      } minimal: {
        Image(systemName: "figure.run")
      }
      .widgetURL(URL(string: "striviq://active-run"))
    }
  }
}

@available(iOS 16.1, *)
private struct RunLockScreenView: View {
  let context: ActivityViewContext<RunActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(context.attributes.workoutName)
          .font(.headline.weight(.semibold))
          .lineLimit(1)
        Spacer()
        TimerText(state: context.state)
          .font(.headline.monospacedDigit())
      }

      Text(context.state.statusLabel)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.teal)

      VStack(alignment: .leading, spacing: 3) {
        Text(context.state.distanceLabel)
          .font(.system(size: 30, weight: .bold, design: .rounded))
          .lineLimit(1)
        Text(context.state.currentBlockLabel)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        if let nextBlockLabel = context.state.nextBlockLabel {
          Text(nextBlockLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      VStack(spacing: 8) {
        MetricRow(
          title: context.state.currentPaceTitleLabel,
          value: context.state.currentPaceLabel
        )
        MetricRow(
          title: context.state.avgPaceTitleLabel,
          value: context.state.avgPaceLabel
        )
      }

      if let repLabel = context.state.repLabel {
        Text(repLabel)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
      }
    }
    .padding()
    .foregroundStyle(.white)
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
