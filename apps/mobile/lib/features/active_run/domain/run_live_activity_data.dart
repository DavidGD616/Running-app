const Object _copyWithSentinel = Object();

class RunLiveActivityData {
  const RunLiveActivityData({
    required this.workoutName,
    required this.statusLabel,
    required this.elapsedSeconds,
    required this.elapsedLabel,
    required this.distanceLabel,
    required this.currentPaceTitleLabel,
    required this.currentPaceLabel,
    required this.avgPaceTitleLabel,
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
  final String currentPaceTitleLabel;
  final String currentPaceLabel;
  final String avgPaceTitleLabel;
  final String avgPaceLabel;
  final String currentBlockLabel;
  final String? nextBlockLabel;
  final String? repLabel;
  final bool isPaused;

  factory RunLiveActivityData.fromMap(Map<Object?, Object?> map) {
    String str(String key, [String fallback = '']) =>
        (map[key] as String?) ?? fallback;
    String? optStr(String key) => map[key] as String?;
    int intVal(String key) {
      final v = map[key];
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return RunLiveActivityData(
      workoutName: str('workoutName'),
      statusLabel: str('statusLabel'),
      elapsedSeconds: intVal('elapsedSeconds'),
      elapsedLabel: str('elapsedLabel', '00:00'),
      distanceLabel: str('distanceLabel'),
      currentPaceTitleLabel: str('currentPaceTitleLabel'),
      currentPaceLabel: str('currentPaceLabel'),
      avgPaceTitleLabel: str('avgPaceTitleLabel'),
      avgPaceLabel: str('avgPaceLabel'),
      currentBlockLabel: str('currentBlockLabel'),
      nextBlockLabel: optStr('nextBlockLabel'),
      repLabel: optStr('repLabel'),
      isPaused: (map['isPaused'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workoutName': workoutName,
      'statusLabel': statusLabel,
      'elapsedSeconds': elapsedSeconds,
      'elapsedLabel': elapsedLabel,
      'distanceLabel': distanceLabel,
      'currentPaceTitleLabel': currentPaceTitleLabel,
      'currentPaceLabel': currentPaceLabel,
      'avgPaceTitleLabel': avgPaceTitleLabel,
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
    String? currentPaceTitleLabel,
    String? currentPaceLabel,
    String? avgPaceTitleLabel,
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
      currentPaceTitleLabel:
          currentPaceTitleLabel ?? this.currentPaceTitleLabel,
      currentPaceLabel: currentPaceLabel ?? this.currentPaceLabel,
      avgPaceTitleLabel: avgPaceTitleLabel ?? this.avgPaceTitleLabel,
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
