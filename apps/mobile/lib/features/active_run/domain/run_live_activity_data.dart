const Object _copyWithSentinel = Object();

class RunLiveActivityTimelineBlock {
  const RunLiveActivityTimelineBlock({
    this.durationMs,
    this.distanceMeters,
    required this.blockLabel,
    this.nextLabel,
    this.repLabel,
  });

  final int? durationMs;
  final int? distanceMeters;
  final String blockLabel;
  final String? nextLabel;
  final String? repLabel;

  Map<String, dynamic> toMap() => {
    'durationMs': durationMs,
    'distanceMeters': distanceMeters,
    'blockLabel': blockLabel,
    'nextLabel': nextLabel,
    'repLabel': repLabel,
  };

  factory RunLiveActivityTimelineBlock.fromMap(Map<Object?, Object?> map) {
    int? optInt(String key) {
      final v = map[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return RunLiveActivityTimelineBlock(
      durationMs: optInt('durationMs'),
      distanceMeters: optInt('distanceMeters'),
      blockLabel: (map['blockLabel'] as String?) ?? '',
      nextLabel: map['nextLabel'] as String?,
      repLabel: map['repLabel'] as String?,
    );
  }
}

class RunLiveActivityData {
  const RunLiveActivityData({
    required this.workoutName,
    this.statusTitleLabel = '',
    this.statusLabel = '',
    required this.elapsedSeconds,
    required this.elapsedLabel,
    this.elapsedUnitLabel = '',
    this.distanceTitleLabel = '',
    required this.distanceLabel,
    this.currentPaceShortTitleLabel = '',
    required this.currentPaceTitleLabel,
    required this.currentPaceLabel,
    required this.avgPaceTitleLabel,
    required this.avgPaceLabel,
    required this.currentBlockLabel,
    this.nextBlockLabel,
    this.nextBlockTitleLabel = '',
    this.repLabel,
    required this.isPaused,
    required this.distanceKm,
    required this.paceSecondsPerKm,
    required this.unitFactor,
    required this.distanceUnit,
    required this.paceUnit,
    this.plannedDistanceKm,
    this.plannedDurationMs,
    this.timeline,
    this.blockProgressFraction = 0.0,
    this.plannedPaceLabel = '',
    this.blockRemainingLabel,
  });

  final String workoutName;
  final String statusTitleLabel;
  final String statusLabel;
  final int elapsedSeconds;
  final String elapsedLabel;
  final String elapsedUnitLabel;
  final String distanceTitleLabel;
  final String distanceLabel;
  final String currentPaceShortTitleLabel;
  final String currentPaceTitleLabel;
  final String currentPaceLabel;
  final String avgPaceTitleLabel;
  final String avgPaceLabel;
  final String currentBlockLabel;
  final String? nextBlockLabel;
  final String nextBlockTitleLabel;
  final String? repLabel;
  final bool isPaused;

  /// Live distance in km. Authoritative controller distance used for
  /// payload, debug, and native display fallback. Native surfaces must
  /// not infer distance from pace.
  final double distanceKm;

  /// Current pace in seconds-per-kilometre. Authoritative controller
  /// current pace for payload, debug, and native display fallback.
  /// Native surfaces must not use this to compute per-tick distance.
  final int paceSecondsPerKm;

  /// Multiplier to convert km → user-preferred unit (1.0 km, 0.621371 mi).
  final double unitFactor;

  /// Display suffix for distance, e.g. "km" or "mi".
  final String distanceUnit;

  /// Display suffix for pace, e.g. "min/km" or "min/mi".
  final String paceUnit;
  final double? plannedDistanceKm;
  final int? plannedDurationMs;

  /// Full block timeline (optional display metadata). This is NOT
  /// authoritative — native surfaces must render block labels and
  /// progress from the latest Flutter payload fields:
  /// `currentBlockLabel`, `nextBlockLabel`, `repLabel`, and
  /// `blockProgressFraction`. Android must not use `timeline` to
  /// advance blocks or override current labels.
  final List<RunLiveActivityTimelineBlock>? timeline;

  /// Progress 0.0..1.0 for green bar fill (block completion %).
  final double blockProgressFraction;

  /// Formatted planned pace, e.g. "9:45 /mi".
  final String plannedPaceLabel;

  /// Block distance/time remaining, e.g. "0.2 mi left" or "1:30 left".
  final String? blockRemainingLabel;

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

    int? intOrNull(String key) {
      final v = map[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    double doubleVal(String key, double fallback) {
      final v = map[key];
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    double? doubleOrNull(String key) {
      final v = map[key];
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    List<RunLiveActivityTimelineBlock>? timeline;
    final raw = map['timeline'];
    if (raw is List) {
      timeline = raw
          .whereType<Map>()
          .map(
            (e) => RunLiveActivityTimelineBlock.fromMap(
              e.cast<Object?, Object?>(),
            ),
          )
          .toList();
    }

    return RunLiveActivityData(
      workoutName: str('workoutName'),
      statusTitleLabel: str('statusTitleLabel'),
      statusLabel: str('statusLabel'),
      elapsedSeconds: intVal('elapsedSeconds'),
      elapsedLabel: str('elapsedLabel', '00:00'),
      elapsedUnitLabel: str('elapsedUnitLabel'),
      distanceTitleLabel: str('distanceTitleLabel'),
      distanceLabel: str('distanceLabel'),
      currentPaceShortTitleLabel: str('currentPaceShortTitleLabel'),
      currentPaceTitleLabel: str('currentPaceTitleLabel'),
      currentPaceLabel: str('currentPaceLabel'),
      avgPaceTitleLabel: str('avgPaceTitleLabel'),
      avgPaceLabel: str('avgPaceLabel'),
      currentBlockLabel: str('currentBlockLabel'),
      nextBlockLabel: optStr('nextBlockLabel'),
      nextBlockTitleLabel: str('nextBlockTitleLabel'),
      repLabel: optStr('repLabel'),
      isPaused: (map['isPaused'] as bool?) ?? false,
      distanceKm: doubleVal('distanceKm', 0),
      paceSecondsPerKm: intVal('paceSecondsPerKm'),
      unitFactor: doubleVal('unitFactor', 1.0),
      distanceUnit: str('distanceUnit', 'km'),
      paceUnit: str('paceUnit', 'min/km'),
      plannedDistanceKm: doubleOrNull('plannedDistanceKm'),
      plannedDurationMs: intOrNull('plannedDurationMs'),
      timeline: timeline,
      blockProgressFraction: doubleVal('blockProgressFraction', 0.0),
      plannedPaceLabel: str('plannedPaceLabel'),
      blockRemainingLabel: optStr('blockRemainingLabel'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workoutName': workoutName,
      'statusTitleLabel': statusTitleLabel,
      'statusLabel': statusLabel,
      'elapsedSeconds': elapsedSeconds,
      'elapsedLabel': elapsedLabel,
      'elapsedUnitLabel': elapsedUnitLabel,
      'distanceTitleLabel': distanceTitleLabel,
      'distanceLabel': distanceLabel,
      'currentPaceShortTitleLabel': currentPaceShortTitleLabel,
      'currentPaceTitleLabel': currentPaceTitleLabel,
      'currentPaceLabel': currentPaceLabel,
      'avgPaceTitleLabel': avgPaceTitleLabel,
      'avgPaceLabel': avgPaceLabel,
      'currentBlockLabel': currentBlockLabel,
      'nextBlockLabel': nextBlockLabel,
      'nextBlockTitleLabel': nextBlockTitleLabel,
      'repLabel': repLabel,
      'isPaused': isPaused,
      'distanceKm': distanceKm,
      'paceSecondsPerKm': paceSecondsPerKm,
      'unitFactor': unitFactor,
      'distanceUnit': distanceUnit,
      'paceUnit': paceUnit,
      'plannedDistanceKm': plannedDistanceKm,
      'plannedDurationMs': plannedDurationMs,
      if (timeline != null)
        'timeline': timeline!.map((b) => b.toMap()).toList(),
      'blockProgressFraction': blockProgressFraction,
      'plannedPaceLabel': plannedPaceLabel,
      'blockRemainingLabel': blockRemainingLabel,
    };
  }

  RunLiveActivityData copyWith({
    String? workoutName,
    String? statusTitleLabel,
    String? statusLabel,
    int? elapsedSeconds,
    String? elapsedLabel,
    String? elapsedUnitLabel,
    String? distanceTitleLabel,
    String? distanceLabel,
    String? currentPaceShortTitleLabel,
    String? currentPaceTitleLabel,
    String? currentPaceLabel,
    String? avgPaceTitleLabel,
    String? avgPaceLabel,
    String? currentBlockLabel,
    Object? nextBlockLabel = _copyWithSentinel,
    String? nextBlockTitleLabel,
    Object? repLabel = _copyWithSentinel,
    bool? isPaused,
    double? distanceKm,
    int? paceSecondsPerKm,
    double? unitFactor,
    String? distanceUnit,
    String? paceUnit,
    Object? plannedDistanceKm = _copyWithSentinel,
    Object? plannedDurationMs = _copyWithSentinel,
    Object? timeline = _copyWithSentinel,
    double? blockProgressFraction,
    String? plannedPaceLabel,
    Object? blockRemainingLabel = _copyWithSentinel,
  }) {
    return RunLiveActivityData(
      workoutName: workoutName ?? this.workoutName,
      statusTitleLabel: statusTitleLabel ?? this.statusTitleLabel,
      statusLabel: statusLabel ?? this.statusLabel,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      elapsedLabel: elapsedLabel ?? this.elapsedLabel,
      elapsedUnitLabel: elapsedUnitLabel ?? this.elapsedUnitLabel,
      distanceTitleLabel: distanceTitleLabel ?? this.distanceTitleLabel,
      distanceLabel: distanceLabel ?? this.distanceLabel,
      currentPaceShortTitleLabel:
          currentPaceShortTitleLabel ?? this.currentPaceShortTitleLabel,
      currentPaceTitleLabel:
          currentPaceTitleLabel ?? this.currentPaceTitleLabel,
      currentPaceLabel: currentPaceLabel ?? this.currentPaceLabel,
      avgPaceTitleLabel: avgPaceTitleLabel ?? this.avgPaceTitleLabel,
      avgPaceLabel: avgPaceLabel ?? this.avgPaceLabel,
      currentBlockLabel: currentBlockLabel ?? this.currentBlockLabel,
      nextBlockLabel: identical(nextBlockLabel, _copyWithSentinel)
          ? this.nextBlockLabel
          : nextBlockLabel as String?,
      nextBlockTitleLabel: nextBlockTitleLabel ?? this.nextBlockTitleLabel,
      repLabel: identical(repLabel, _copyWithSentinel)
          ? this.repLabel
          : repLabel as String?,
      isPaused: isPaused ?? this.isPaused,
      distanceKm: distanceKm ?? this.distanceKm,
      paceSecondsPerKm: paceSecondsPerKm ?? this.paceSecondsPerKm,
      unitFactor: unitFactor ?? this.unitFactor,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      paceUnit: paceUnit ?? this.paceUnit,
      plannedDistanceKm: identical(plannedDistanceKm, _copyWithSentinel)
          ? this.plannedDistanceKm
          : plannedDistanceKm as double?,
      plannedDurationMs: identical(plannedDurationMs, _copyWithSentinel)
          ? this.plannedDurationMs
          : plannedDurationMs as int?,
      timeline: identical(timeline, _copyWithSentinel)
          ? this.timeline
          : timeline as List<RunLiveActivityTimelineBlock>?,
      blockProgressFraction:
          blockProgressFraction ?? this.blockProgressFraction,
      plannedPaceLabel: plannedPaceLabel ?? this.plannedPaceLabel,
      blockRemainingLabel: identical(blockRemainingLabel, _copyWithSentinel)
          ? this.blockRemainingLabel
          : blockRemainingLabel as String?,
    );
  }
}
