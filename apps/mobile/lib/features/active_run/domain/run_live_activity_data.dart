const Object _copyWithSentinel = Object();

class RunLiveActivityData {
  const RunLiveActivityData({
    required this.workoutName,
    required this.statusLabel,
    required this.elapsedSeconds,
    required this.elapsedLabel,
    required this.distanceLabel,
    required this.currentPaceLabel,
    required this.avgPaceLabel,
    required this.currentBlockLabel,
    this.nextBlockLabel,
    this.repLabel,
    required this.isPaused,
  });

  final String workoutName;
  final String statusLabel;
  final int elapsedSeconds;
  final String elapsedLabel;
  final String distanceLabel;
  final String currentPaceLabel;
  final String avgPaceLabel;
  final String currentBlockLabel;
  final String? nextBlockLabel;
  final String? repLabel;
  final bool isPaused;

  Map<String, dynamic> toMap() {
    return {
      'workoutName': workoutName,
      'statusLabel': statusLabel,
      'elapsedSeconds': elapsedSeconds,
      'elapsedLabel': elapsedLabel,
      'distanceLabel': distanceLabel,
      'currentPaceLabel': currentPaceLabel,
      'avgPaceLabel': avgPaceLabel,
      'currentBlockLabel': currentBlockLabel,
      'nextBlockLabel': nextBlockLabel,
      'repLabel': repLabel,
      'isPaused': isPaused,
    };
  }

  RunLiveActivityData copyWith({
    String? workoutName,
    String? statusLabel,
    int? elapsedSeconds,
    String? elapsedLabel,
    String? distanceLabel,
    String? currentPaceLabel,
    String? avgPaceLabel,
    String? currentBlockLabel,
    Object? nextBlockLabel = _copyWithSentinel,
    Object? repLabel = _copyWithSentinel,
    bool? isPaused,
  }) {
    return RunLiveActivityData(
      workoutName: workoutName ?? this.workoutName,
      statusLabel: statusLabel ?? this.statusLabel,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      elapsedLabel: elapsedLabel ?? this.elapsedLabel,
      distanceLabel: distanceLabel ?? this.distanceLabel,
      currentPaceLabel: currentPaceLabel ?? this.currentPaceLabel,
      avgPaceLabel: avgPaceLabel ?? this.avgPaceLabel,
      currentBlockLabel: currentBlockLabel ?? this.currentBlockLabel,
      nextBlockLabel: identical(nextBlockLabel, _copyWithSentinel)
          ? this.nextBlockLabel
          : nextBlockLabel as String?,
      repLabel: identical(repLabel, _copyWithSentinel)
          ? this.repLabel
          : repLabel as String?,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}
