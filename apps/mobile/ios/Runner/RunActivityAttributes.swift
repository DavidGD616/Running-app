import ActivityKit
import Foundation

// SYNC: must match RunLiveActivityExtension/RunActivityAttributes.swift
@available(iOS 16.1, *)
struct RunActivityAttributes: ActivityAttributes {
  let workoutName: String

  struct ContentState: Codable, Hashable {
    var statusLabel: String
    var timerStartedAt: Date?
    var elapsedLabel: String
    var elapsedUnitLabel: String
    var isPaused: Bool
    var distanceTitleLabel: String
    var distanceLabel: String
    var currentPaceTitleLabel: String
    var currentPaceLabel: String
    var avgPaceTitleLabel: String
    var avgPaceLabel: String
    var currentBlockLabel: String
    var nextBlockLabel: String?
    var nextBlockTitleLabel: String
    var repLabel: String?
    var blockProgressFraction: Double
    var plannedPaceLabel: String
    var blockRemainingLabel: String?
  }
}
