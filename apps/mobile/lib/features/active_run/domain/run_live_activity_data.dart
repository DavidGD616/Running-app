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
    required this.distanceKm,
    required this.paceSecondsPerKm,
    required this.unitFactor,
    required this.distanceUnit,
    required this.paceUnit,
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

  /// Live distance in km. Android service uses this as seed and ticks it.
  final double distanceKm;

  /// Current pace in seconds-per-kilometre. Service uses this to compute
  /// per-tick distance increments while Flutter is backgrounded.
  final int paceSecondsPerKm;

  /// Multiplier to convert km → user-preferred unit (1.0 km, 0.621371 mi).
  final double unitFactor;

  /// Display suffix for distance, e.g. "km" or "mi".
  final String distanceUnit;

  /// Display suffix for pace, e.g. "min/km" or "min/mi".
  final String paceUnit;

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
    double doubleVal(String key, double fallback) {
      final v = map[key];
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
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
      distanceKm: doubleVal('distanceKm', 0),
      paceSecondsPerKm: intVal('paceSecondsPerKm'),
      unitFactor: doubleVal('unitFactor', 1.0),
      distanceUnit: str('distanceUnit', 'km'),
      paceUnit: str('paceUnit', 'min/km'),
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
      'distanceKm': distanceKm,
      'paceSecondsPerKm': paceSecondsPerKm,
      'unitFactor': unitFactor,
      'distanceUnit': distanceUnit,
      'paceUnit': paceUnit,
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
    double? distanceKm,
    int? paceSecondsPerKm,
    double? unitFactor,
    String? distanceUnit,
    String? paceUnit,
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
      distanceKm: distanceKm ?? this.distanceKm,
      paceSecondsPerKm: paceSecondsPerKm ?? this.paceSecondsPerKm,
      unitFactor: unitFactor ?? this.unitFactor,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      paceUnit: paceUnit ?? this.paceUnit,
    );
  }
}
