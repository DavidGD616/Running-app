enum TargetType { pace, effort, heartRate }

enum TargetZone {
  recovery,
  easy,
  steady,
  tempo,
  threshold,
  interval,
  racePace,
  longRun,
}

class WorkoutTarget {
  const WorkoutTarget({
    required this.type,
    required this.zone,
    this.paceMinSecPerKm,
    this.paceMaxSecPerKm,
    this.effortCue,
  }) : assert(
         (paceMinSecPerKm == null || paceMinSecPerKm > 0) &&
             (paceMaxSecPerKm == null || paceMaxSecPerKm > 0) &&
             (paceMinSecPerKm == null ||
                 paceMaxSecPerKm == null ||
                 paceMinSecPerKm <= paceMaxSecPerKm),
         'Invalid workout target pace range.',
       );

  static bool _isValidPaceRange(int? paceMinSecPerKm, int? paceMaxSecPerKm) {
    if (paceMinSecPerKm != null && paceMinSecPerKm <= 0) return false;
    if (paceMaxSecPerKm != null && paceMaxSecPerKm <= 0) return false;
    if (paceMinSecPerKm != null &&
        paceMaxSecPerKm != null &&
        paceMinSecPerKm > paceMaxSecPerKm) {
      return false;
    }
    return true;
  }

  static void _validatePaceRangeOrThrow(
    int? paceMinSecPerKm,
    int? paceMaxSecPerKm,
  ) {
    if (_isValidPaceRange(paceMinSecPerKm, paceMaxSecPerKm)) return;
    throw const FormatException(
      'Invalid workout target: paceMinSecPerKm and paceMaxSecPerKm must be > 0, and paceMinSecPerKm cannot exceed paceMaxSecPerKm.',
    );
  }

  static int? _paceFromJson(Object? value, String key) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    if (value is String && value.isNotEmpty) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('Invalid workout target: $key must be an int.');
  }

  static String? _optionalStringOrThrow(Object? value, String key) {
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Invalid workout target: $key must be a string.');
  }

  static const int schemaVersion = 1;

  final TargetType type;
  final TargetZone zone;
  final int? paceMinSecPerKm;
  final int? paceMaxSecPerKm;
  final String? effortCue;

  const WorkoutTarget.pace(
    this.zone, {
    this.paceMinSecPerKm,
    this.paceMaxSecPerKm,
    this.effortCue,
  }) : type = TargetType.pace,
       assert(
         (paceMinSecPerKm == null || paceMinSecPerKm > 0) &&
             (paceMaxSecPerKm == null || paceMaxSecPerKm > 0) &&
             (paceMinSecPerKm == null ||
                 paceMaxSecPerKm == null ||
                 paceMinSecPerKm <= paceMaxSecPerKm),
         'Invalid workout target pace range.',
       );

  const WorkoutTarget.effort(
    this.zone, {
    this.paceMinSecPerKm,
    this.paceMaxSecPerKm,
    this.effortCue,
  }) : type = TargetType.effort,
       assert(
         (paceMinSecPerKm == null || paceMinSecPerKm > 0) &&
             (paceMaxSecPerKm == null || paceMaxSecPerKm > 0) &&
             (paceMinSecPerKm == null ||
                 paceMaxSecPerKm == null ||
                 paceMinSecPerKm <= paceMaxSecPerKm),
         'Invalid workout target pace range.',
       );

  const WorkoutTarget.heartRate(
    this.zone, {
    // pace fields may be present for mixed-target guidance but are typically
    // null for heartRate targets.
    this.paceMinSecPerKm,
    this.paceMaxSecPerKm,
    this.effortCue,
  }) : type = TargetType.heartRate,
       assert(
         (paceMinSecPerKm == null || paceMinSecPerKm > 0) &&
             (paceMaxSecPerKm == null || paceMaxSecPerKm > 0) &&
             (paceMinSecPerKm == null ||
                 paceMaxSecPerKm == null ||
                 paceMinSecPerKm <= paceMaxSecPerKm),
         'Invalid workout target pace range.',
       );

  WorkoutTarget copyWith({
    TargetType? type,
    TargetZone? zone,
    int? paceMinSecPerKm,
    int? paceMaxSecPerKm,
    String? effortCue,
  }) {
    // Limitation: nullable pace fields cannot be explicitly nulled out via
    // copyWith because null means "keep existing".
    return WorkoutTarget(
      type: type ?? this.type,
      zone: zone ?? this.zone,
      paceMinSecPerKm: paceMinSecPerKm ?? this.paceMinSecPerKm,
      paceMaxSecPerKm: paceMaxSecPerKm ?? this.paceMaxSecPerKm,
      effortCue: effortCue ?? this.effortCue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'type': type.name,
      'zone': zone.name,
      if (paceMinSecPerKm != null) 'paceMinSecPerKm': paceMinSecPerKm,
      if (paceMaxSecPerKm != null) 'paceMaxSecPerKm': paceMaxSecPerKm,
      if (effortCue != null) 'effortCue': effortCue,
    };
  }

  static WorkoutTarget? fromJson(Map<String, dynamic> json) {
    final type = _targetTypeFromKey(json['type'] as String?);
    final zone = _targetZoneFromKey(json['zone'] as String?);
    if (type == null || zone == null) return null;

    final paceMinSecPerKm = _paceFromJson(
      json['paceMinSecPerKm'],
      'paceMinSecPerKm',
    );
    final paceMaxSecPerKm = _paceFromJson(
      json['paceMaxSecPerKm'],
      'paceMaxSecPerKm',
    );
    _validatePaceRangeOrThrow(paceMinSecPerKm, paceMaxSecPerKm);

    return WorkoutTarget(
      type: type,
      zone: zone,
      paceMinSecPerKm: paceMinSecPerKm,
      paceMaxSecPerKm: paceMaxSecPerKm,
      effortCue: _optionalStringOrThrow(json['effortCue'], 'effortCue'),
    );
  }
}

TargetType? _targetTypeFromKey(String? key) {
  if (key == null || key.isEmpty) return null;
  for (final value in TargetType.values) {
    if (value.name == key) return value;
  }
  return null;
}

TargetZone? _targetZoneFromKey(String? key) {
  if (key == null || key.isEmpty) return null;
  for (final value in TargetZone.values) {
    if (value.name == key) return value;
  }
  return null;
}
