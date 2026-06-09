import 'model_json_utils.dart';

enum CoachingReadinessLevel {
  raceReady('raceReady'),
  prepared('prepared'),
  developing('developing'),
  underprepared('underprepared'),
  unsupported('unsupported');

  const CoachingReadinessLevel(this.key);
  final String key;

  static CoachingReadinessLevel? fromKey(String? key) =>
      enumFromKey(key, values, (value) => value.key);
}

enum CoachingConfidence {
  high('high'),
  medium('medium'),
  limited('limited');

  const CoachingConfidence(this.key);
  final String key;

  static CoachingConfidence? fromKey(String? key) =>
      enumFromKey(key, values, (value) => value.key);
}

enum CoachingSource {
  strava('strava'),
  manual('manual'),
  mixed('mixed'),
  unknown('unknown');

  const CoachingSource(this.key);
  final String key;

  static CoachingSource? fromKey(String? key) =>
      enumFromKey(key, values, (value) => value.key);
}

enum CoachingPhase {
  base('base'),
  build('build'),
  specific('specific'),
  peak('peak'),
  taperRace('taperRace'),
  safeBuild('safeBuild'),
  unsupportedFallback('unsupportedFallback');

  const CoachingPhase(this.key);
  final String key;

  static CoachingPhase? fromKey(String? key) =>
      enumFromKey(key, values, (value) => value.key);
}

class CoachingTarget {
  const CoachingTarget({
    this.distanceKm,
    this.time,
    this.paceSecPerKm,
    this.confidence,
    this.source,
    this.supported,
    this.reason,
  });

  final double? distanceKm;
  final Duration? time;
  final int? paceSecPerKm;
  final CoachingConfidence? confidence;
  final CoachingSource? source;
  final bool? supported;
  final String? reason;

  Map<String, dynamic> toJson() {
    return removeNullValues({
          'distanceKm': distanceKm,
          'timeSec': time?.inSeconds,
          'paceSecPerKm': paceSecPerKm,
          'confidence': confidence?.key,
          'source': source?.key,
          'supported': supported,
          'reason': reason,
        })
        as Map<String, dynamic>;
  }

  static CoachingTarget fromJson(Map<String, dynamic> json) {
    final distanceKm = optionalDouble(json['distanceKm']);
    final timeSec = optionalInt(json['timeSec']);
    final paceSecPerKm = optionalInt(json['paceSecPerKm']);
    return CoachingTarget(
      distanceKm: distanceKm != null && distanceKm > 0 ? distanceKm : null,
      time: timeSec != null && timeSec > 0 ? Duration(seconds: timeSec) : null,
      paceSecPerKm: paceSecPerKm != null && paceSecPerKm > 0
          ? paceSecPerKm
          : null,
      confidence: CoachingConfidence.fromKey(stringOrNull(json['confidence'])),
      source: CoachingSource.fromKey(stringOrNull(json['source'])),
      supported: json['supported'] is bool ? json['supported'] as bool : null,
      reason: stringOrNull(json['reason']),
    );
  }
}

class PhaseStrategy {
  const PhaseStrategy({required this.phase, required this.weeks, this.focus});

  final CoachingPhase phase;
  final int weeks;
  final String? focus;

  Map<String, dynamic> toJson() {
    return removeNullValues({
          'phase': phase.key,
          'weeks': weeks,
          'focus': focus,
        })
        as Map<String, dynamic>;
  }

  static PhaseStrategy fromJson(Map<String, dynamic> json) {
    final phase = CoachingPhase.fromKey(stringOrNull(json['phase']));
    final weeks = optionalInt(json['weeks']);
    if (phase == null || weeks == null || weeks <= 0) {
      throw const FormatException('Invalid phase strategy.');
    }
    return PhaseStrategy(
      phase: phase,
      weeks: weeks,
      focus: stringOrNull(json['focus']),
    );
  }
}

class CoachingTaper {
  const CoachingTaper({
    this.weeks,
    this.volumeReductionPercent,
    this.finalWeekFocus,
  });

  final int? weeks;
  final int? volumeReductionPercent;
  final String? finalWeekFocus;

  Map<String, dynamic> toJson() {
    return removeNullValues({
          'weeks': weeks,
          'volumeReductionPercent': volumeReductionPercent,
          'finalWeekFocus': finalWeekFocus,
        })
        as Map<String, dynamic>;
  }

  static CoachingTaper fromJson(Map<String, dynamic> json) {
    return CoachingTaper(
      weeks: optionalInt(json['weeks']),
      volumeReductionPercent: optionalInt(json['volumeReductionPercent']),
      finalWeekFocus: stringOrNull(json['finalWeekFocus']),
    );
  }
}

class CoachingBriefSnapshot {
  const CoachingBriefSnapshot({
    this.raceType,
    this.readinessLevel,
    this.confidence,
    this.source,
    this.currentVolumeKmPerWeek,
    this.currentRunsPerWeek,
    this.recentLongRunKm,
    this.planLengthWeeks,
    this.phaseStrategy = const [],
    this.maxWeeklyVolumeKm,
    this.longRunCeilingKm,
    this.weeklyRunDays,
    this.taper,
    this.workoutEmphasis = const [],
    this.evidenceTarget,
    this.ambitiousTarget,
    this.constraints = const [],
    this.rationale = const [],
  });

  final String? raceType;
  final CoachingReadinessLevel? readinessLevel;
  final CoachingConfidence? confidence;
  final CoachingSource? source;
  final double? currentVolumeKmPerWeek;
  final double? currentRunsPerWeek;
  final double? recentLongRunKm;
  final int? planLengthWeeks;
  final List<PhaseStrategy> phaseStrategy;
  final double? maxWeeklyVolumeKm;
  final double? longRunCeilingKm;
  final int? weeklyRunDays;
  final CoachingTaper? taper;
  final List<String> workoutEmphasis;
  final CoachingTarget? evidenceTarget;
  final CoachingTarget? ambitiousTarget;
  final List<String> constraints;
  final List<String> rationale;

  Map<String, dynamic> toJson() {
    return removeNullValues({
          'raceType': raceType,
          'readinessLevel': readinessLevel?.key,
          'confidence': confidence?.key,
          'source': source?.key,
          'currentVolumeKmPerWeek': currentVolumeKmPerWeek,
          'currentRunsPerWeek': currentRunsPerWeek,
          'recentLongRunKm': recentLongRunKm,
          'planLengthWeeks': planLengthWeeks,
          'phaseStrategy': phaseStrategy
              .map((phase) => phase.toJson())
              .toList(),
          'maxWeeklyVolumeKm': maxWeeklyVolumeKm,
          'longRunCeilingKm': longRunCeilingKm,
          'weeklyRunDays': weeklyRunDays,
          'taper': taper?.toJson(),
          'workoutEmphasis': workoutEmphasis,
          'evidenceTarget': evidenceTarget?.toJson(),
          'ambitiousTarget': ambitiousTarget?.toJson(),
          'constraints': constraints,
          'rationale': rationale,
        })
        as Map<String, dynamic>;
  }

  static CoachingBriefSnapshot fromJson(Map<String, dynamic> json) {
    return CoachingBriefSnapshot(
      raceType: stringOrNull(json['raceType']),
      readinessLevel: CoachingReadinessLevel.fromKey(
        stringOrNull(json['readinessLevel']),
      ),
      confidence: CoachingConfidence.fromKey(stringOrNull(json['confidence'])),
      source: CoachingSource.fromKey(stringOrNull(json['source'])),
      currentVolumeKmPerWeek: optionalDouble(json['currentVolumeKmPerWeek']),
      currentRunsPerWeek: optionalDouble(json['currentRunsPerWeek']),
      recentLongRunKm: optionalDouble(json['recentLongRunKm']),
      planLengthWeeks: optionalInt(json['planLengthWeeks']),
      phaseStrategy: _phaseStrategyList(json['phaseStrategy']),
      maxWeeklyVolumeKm: optionalDouble(json['maxWeeklyVolumeKm']),
      longRunCeilingKm: optionalDouble(json['longRunCeilingKm']),
      weeklyRunDays: optionalInt(json['weeklyRunDays']),
      taper: _optionalTaper(json['taper']),
      workoutEmphasis: stringListOrEmpty(json['workoutEmphasis']),
      evidenceTarget: _optionalTarget(json['evidenceTarget']),
      ambitiousTarget: _optionalTarget(json['ambitiousTarget']),
      constraints: stringListOrEmpty(json['constraints']),
      rationale: stringListOrEmpty(json['rationale']),
    );
  }
}

CoachingBriefSnapshot? coachingBriefSnapshotOrNull(Object? value) {
  try {
    if (value is Map<String, dynamic>) {
      return CoachingBriefSnapshot.fromJson(value);
    }
    if (value is Map) {
      return CoachingBriefSnapshot.fromJson(
        value.map((key, item) => MapEntry('$key', item)),
      );
    }
  } on FormatException {
    return null;
  }
  return null;
}

CoachingTarget? coachingTargetOrNull(Object? value) {
  try {
    if (value is Map<String, dynamic>) return CoachingTarget.fromJson(value);
    if (value is Map) {
      return CoachingTarget.fromJson(
        value.map((key, item) => MapEntry('$key', item)),
      );
    }
  } on FormatException {
    return null;
  }
  return null;
}

List<PhaseStrategy> phaseStrategyListOrEmpty(Object? value) {
  try {
    return _phaseStrategyList(value);
  } on FormatException {
    return const [];
  }
}

List<PhaseStrategy> _phaseStrategyList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((entry) {
        if (entry is Map<String, dynamic>) return PhaseStrategy.fromJson(entry);
        if (entry is Map) {
          return PhaseStrategy.fromJson(
            entry.map((key, item) => MapEntry('$key', item)),
          );
        }
        throw const FormatException('Invalid phase strategy entry.');
      })
      .toList(growable: false);
}

CoachingTaper? _optionalTaper(Object? value) {
  if (value is Map<String, dynamic>) return CoachingTaper.fromJson(value);
  if (value is Map) {
    return CoachingTaper.fromJson(
      value.map((key, item) => MapEntry('$key', item)),
    );
  }
  return null;
}

CoachingTarget? _optionalTarget(Object? value) => coachingTargetOrNull(value);
