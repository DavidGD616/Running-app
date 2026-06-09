import '../../../training_plan/domain/models/model_json_utils.dart';

enum StravaDataConfidence {
  high('high'),
  medium('medium'),
  limited('limited');

  const StravaDataConfidence(this.key);

  final String key;

  static StravaDataConfidence? fromKey(String? key) {
    if (key == null || key.isEmpty) return null;

    for (final value in values) {
      if (value.key == key) return value;
    }

    return null;
  }
}

class StravaAnalysisProvenance {
  const StravaAnalysisProvenance({
    required this.source,
    required this.syncedAt,
    required this.dataWindow,
    required this.dataFromDate,
    required this.dataThroughDate,
    required this.activityCount,
    required this.runActivityCount,
    required this.confidence,
  });

  final String source;
  final DateTime syncedAt;
  final String dataWindow;
  final DateTime dataFromDate;
  final DateTime dataThroughDate;
  final int activityCount;
  final int runActivityCount;
  final StravaDataConfidence confidence;

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'syncedAt': syncedAt.toIso8601String(),
      'dataWindow': dataWindow,
      'dataFromDate': dataFromDate.toIso8601String(),
      'dataThroughDate': dataThroughDate.toIso8601String(),
      'activityCount': activityCount,
      'runActivityCount': runActivityCount,
      'confidence': confidence.key,
    };
  }

  factory StravaAnalysisProvenance.fromJson(Map<String, dynamic> json) {
    final source = requiredString(json, 'source', context: 'provenance');
    final syncedAt = requiredDateTime(json, 'syncedAt', context: 'provenance');
    final dataWindow = requiredString(
      json,
      'dataWindow',
      context: 'provenance',
    );
    final dataFromDate = requiredDateTime(
      json,
      'dataFromDate',
      context: 'provenance',
    );
    final dataThroughDate = requiredDateTime(
      json,
      'dataThroughDate',
      context: 'provenance',
    );
    final activityCount = requiredInt(
      json,
      'activityCount',
      context: 'provenance',
    );
    final runActivityCount = requiredInt(
      json,
      'runActivityCount',
      context: 'provenance',
    );
    final confidence = _requiredConfidence(
      json,
      'confidence',
      context: 'provenance',
    );

    if (dataThroughDate.isBefore(dataFromDate)) {
      throw const FormatException(
        'Invalid provenance: dataThroughDate must be on or after dataFromDate.',
      );
    }
    if (activityCount < 0 || runActivityCount < 0) {
      throw const FormatException(
        'Invalid provenance: activity counts must be >= 0.',
      );
    }
    if (runActivityCount > activityCount) {
      throw const FormatException(
        'Invalid provenance: runActivityCount cannot exceed activityCount.',
      );
    }

    return StravaAnalysisProvenance(
      source: source,
      syncedAt: syncedAt,
      dataWindow: dataWindow,
      dataFromDate: dataFromDate,
      dataThroughDate: dataThroughDate,
      activityCount: activityCount,
      runActivityCount: runActivityCount,
      confidence: confidence,
    );
  }
}

class StravaEvidencePoint {
  const StravaEvidencePoint({
    required this.metric,
    required this.date,
    required this.value,
    required this.unit,
  });

  final String metric;
  final DateTime date;
  final num value;
  final String unit;

  Map<String, dynamic> toJson() {
    return {
      'metric': metric,
      'date': date.toIso8601String(),
      'value': value,
      'unit': unit,
    };
  }

  factory StravaEvidencePoint.fromJson(Map<String, dynamic> json) {
    final metric = requiredString(json, 'metric', context: 'evidence point');
    final date = requiredDateTime(json, 'date', context: 'evidence point');
    final value = requiredNum(json, 'value', context: 'evidence point');
    final unit = requiredString(json, 'unit', context: 'evidence point');

    if (value is double && !value.isFinite) {
      throw const FormatException(
        'Invalid evidence point: value must be finite.',
      );
    }

    return StravaEvidencePoint(
      metric: metric,
      date: date,
      value: value,
      unit: unit,
    );
  }
}

class StravaPaceZone {
  const StravaPaceZone({this.paceMinSecPerKm, this.paceMaxSecPerKm});

  final int? paceMinSecPerKm;
  final int? paceMaxSecPerKm;

  Map<String, dynamic> toJson() {
    return removeNullValues({
          'paceMinSecPerKm': paceMinSecPerKm,
          'paceMaxSecPerKm': paceMaxSecPerKm,
        })
        as Map<String, dynamic>;
  }

  factory StravaPaceZone.fromJson(
    Map<String, dynamic> json, {
    String? context,
  }) {
    final rawPaceMinSecPerKm = json['paceMinSecPerKm'];
    final rawPaceMaxSecPerKm = json['paceMaxSecPerKm'];
    final paceMinSecPerKm = optionalInt(json['paceMinSecPerKm']);
    final paceMaxSecPerKm = optionalInt(json['paceMaxSecPerKm']);

    final contextLabel = context ?? 'pace zone';
    if (rawPaceMinSecPerKm != null && paceMinSecPerKm == null) {
      throw FormatException(
        'Invalid $contextLabel: paceMinSecPerKm must be an int.',
      );
    }
    if (rawPaceMaxSecPerKm != null && paceMaxSecPerKm == null) {
      throw FormatException(
        'Invalid $contextLabel: paceMaxSecPerKm must be an int.',
      );
    }

    if (paceMinSecPerKm != null && paceMinSecPerKm <= 0) {
      throw FormatException(
        'Invalid $contextLabel: paceMinSecPerKm must be > 0 when present.',
      );
    }
    if (paceMaxSecPerKm != null && paceMaxSecPerKm <= 0) {
      throw FormatException(
        'Invalid $contextLabel: paceMaxSecPerKm must be > 0 when present.',
      );
    }
    if (paceMinSecPerKm != null &&
        paceMaxSecPerKm != null &&
        paceMinSecPerKm > paceMaxSecPerKm) {
      throw FormatException(
        'Invalid $contextLabel: paceMinSecPerKm cannot exceed paceMaxSecPerKm.',
      );
    }

    return StravaPaceZone(
      paceMinSecPerKm: paceMinSecPerKm,
      paceMaxSecPerKm: paceMaxSecPerKm,
    );
  }
}

class StravaPaceZones {
  const StravaPaceZones({
    required this.recovery,
    required this.easy,
    required this.longRun,
    required this.steady,
    required this.tempo,
    required this.threshold,
    required this.racePace,
    required this.intervals,
    required this.strides,
  });

  const StravaPaceZones.empty()
    : recovery = const StravaPaceZone(),
      easy = const StravaPaceZone(),
      longRun = const StravaPaceZone(),
      steady = const StravaPaceZone(),
      tempo = const StravaPaceZone(),
      threshold = const StravaPaceZone(),
      racePace = const StravaPaceZone(),
      intervals = const StravaPaceZone(),
      strides = const StravaPaceZone();

  final StravaPaceZone recovery;
  final StravaPaceZone easy;
  final StravaPaceZone longRun;
  final StravaPaceZone steady;
  final StravaPaceZone tempo;
  final StravaPaceZone threshold;
  final StravaPaceZone racePace;
  final StravaPaceZone intervals;
  final StravaPaceZone strides;

  Map<String, dynamic> toJson() {
    return {
      'recovery': recovery.toJson(),
      'easy': easy.toJson(),
      'longRun': longRun.toJson(),
      'steady': steady.toJson(),
      'tempo': tempo.toJson(),
      'threshold': threshold.toJson(),
      'racePace': racePace.toJson(),
      'intervals': intervals.toJson(),
      'strides': strides.toJson(),
    };
  }

  factory StravaPaceZones.fromJson(Map<String, dynamic> json) {
    return StravaPaceZones(
      recovery: _paceZoneOrEmpty(json, 'recovery'),
      easy: _paceZoneOrEmpty(json, 'easy'),
      longRun: _paceZoneOrEmpty(json, 'longRun'),
      steady: _paceZoneOrEmpty(json, 'steady'),
      tempo: _paceZoneOrEmpty(json, 'tempo'),
      threshold: _paceZoneOrEmpty(json, 'threshold'),
      racePace: _paceZoneOrEmpty(json, 'racePace'),
      intervals: _paceZoneOrEmpty(json, 'intervals'),
      strides: _paceZoneOrEmpty(json, 'strides'),
    );
  }
}

class StravaGuardrail {
  const StravaGuardrail({
    required this.priority,
    required this.category,
    required this.message,
  });

  final int priority;
  final String category;
  final String message;

  Map<String, dynamic> toJson() {
    return {'priority': priority, 'category': category, 'message': message};
  }

  factory StravaGuardrail.fromJson(Map<String, dynamic> json) {
    final priority = requiredInt(json, 'priority', context: 'guardrail');
    final category = requiredString(json, 'category', context: 'guardrail');
    final message = requiredString(json, 'message', context: 'guardrail');

    if (priority < 0 || priority > 3) {
      throw const FormatException(
        'Invalid guardrail: priority must be between 0 and 3.',
      );
    }

    return StravaGuardrail(
      priority: priority,
      category: category,
      message: message,
    );
  }
}

enum StravaTerrainProfile {
  flat('flat'),
  rolling('rolling'),
  hilly('hilly'),
  notSure('notSure');

  const StravaTerrainProfile(this.key);

  final String key;

  static StravaTerrainProfile? fromKey(String? key) {
    if (key == null || key.isEmpty) return null;

    for (final value in values) {
      if (value.key == key) return value;
    }

    return null;
  }
}

class StravaRaceTargetEstimate {
  const StravaRaceTargetEstimate({
    required this.distanceKm,
    required this.primaryTime,
    this.stretchTime,
    required this.confidence,
    required this.evidence,
  });

  final double distanceKm;
  final Duration primaryTime;
  final Duration? stretchTime;
  final StravaDataConfidence confidence;
  final List<StravaEvidencePoint> evidence;

  Map<String, dynamic> toJson() {
    return removeNullValues({
          'distanceKm': distanceKm,
          'primaryTimeSec': primaryTime.inSeconds,
          'stretchTimeSec': stretchTime?.inSeconds,
          'confidence': confidence.key,
          'evidence': evidence
              .map((point) => point.toJson())
              .toList(growable: false),
        })
        as Map<String, dynamic>;
  }

  factory StravaRaceTargetEstimate.fromJson(Map<String, dynamic> json) {
    final distanceKm = requiredDouble(
      json,
      'distanceKm',
      context: 'race target estimate',
    );
    final primaryTimeSeconds = requiredInt(
      json,
      'primaryTimeSec',
      context: 'race target estimate',
    );
    final rawStretchTimeSeconds = json['stretchTimeSec'];
    final stretchTimeSeconds = optionalInt(json['stretchTimeSec']);
    final confidence = _requiredConfidence(
      json,
      'confidence',
      context: 'race target estimate',
    );
    final evidence = _requiredEvidenceList(
      json,
      'evidence',
      context: 'race target estimate',
    );

    if (!distanceKm.isFinite || distanceKm <= 0) {
      throw const FormatException(
        'Invalid race target estimate: distanceKm must be > 0.',
      );
    }
    if (primaryTimeSeconds <= 0) {
      throw const FormatException(
        'Invalid race target estimate: primaryTimeSec must be > 0.',
      );
    }
    if (rawStretchTimeSeconds != null && stretchTimeSeconds == null) {
      throw const FormatException(
        'Invalid race target estimate: stretchTimeSec must be an int.',
      );
    }
    if (stretchTimeSeconds != null && stretchTimeSeconds <= 0) {
      throw const FormatException(
        'Invalid race target estimate: stretchTimeSec must be > 0.',
      );
    }

    return StravaRaceTargetEstimate(
      distanceKm: distanceKm,
      primaryTime: Duration(seconds: primaryTimeSeconds),
      stretchTime: stretchTimeSeconds == null
          ? null
          : Duration(seconds: stretchTimeSeconds),
      confidence: confidence,
      evidence: evidence,
    );
  }
}

class StravaPlanFocus {
  const StravaPlanFocus({required this.category, required this.summary});

  final String category;
  final String summary;

  Map<String, dynamic> toJson() {
    return {'category': category, 'summary': summary};
  }

  factory StravaPlanFocus.fromJson(Map<String, dynamic> json) {
    return StravaPlanFocus(
      category: requiredString(json, 'category', context: 'plan focus'),
      summary: requiredString(json, 'summary', context: 'plan focus'),
    );
  }
}

class StravaCoachingProfile {
  const StravaCoachingProfile({
    required this.provenance,
    required this.dataConfidence,
    required this.trainingBase,
    required this.endurance,
    required this.speedMarkers,
    required this.paceZones,
    required this.terrain,
    required this.recoveryGuardrails,
    required this.raceTargets,
    required this.planFocus,
  });

  final StravaAnalysisProvenance provenance;
  final StravaDataConfidence dataConfidence;
  final List<StravaEvidencePoint> trainingBase;
  final List<StravaEvidencePoint> endurance;
  final List<StravaEvidencePoint> speedMarkers;
  final StravaPaceZones paceZones;
  final StravaTerrainProfile terrain;
  final List<StravaGuardrail> recoveryGuardrails;
  final List<StravaRaceTargetEstimate> raceTargets;
  final StravaPlanFocus planFocus;

  Map<String, dynamic> toJson() {
    return removeNullValues({
          'provenance': provenance.toJson(),
          'dataConfidence': dataConfidence.key,
          'trainingBase': trainingBase
              .map((point) => point.toJson())
              .toList(growable: false),
          'endurance': endurance
              .map((point) => point.toJson())
              .toList(growable: false),
          'speedMarkers': speedMarkers
              .map((point) => point.toJson())
              .toList(growable: false),
          'paceZones': paceZones.toJson(),
          'terrain': terrain.key,
          'recoveryGuardrails': recoveryGuardrails
              .map((guardrail) => guardrail.toJson())
              .toList(growable: false),
          'raceTargets': raceTargets
              .map((targetEstimate) => targetEstimate.toJson())
              .toList(growable: false),
          'planFocus': planFocus.toJson(),
        })
        as Map<String, dynamic>;
  }

  factory StravaCoachingProfile.fromJson(Map<String, dynamic> json) {
    final provenance = StravaAnalysisProvenance.fromJson(
      requiredMap(json, 'provenance', context: 'coaching profile'),
    );
    final dataConfidence = _requiredConfidence(
      json,
      'dataConfidence',
      context: 'coaching profile',
    );
    final trainingBase = _requiredEvidenceList(
      json,
      'trainingBase',
      context: 'coaching profile',
    );
    final endurance = _requiredEvidenceList(
      json,
      'endurance',
      context: 'coaching profile',
    );
    final speedMarkers = _requiredEvidenceList(
      json,
      'speedMarkers',
      context: 'coaching profile',
    );
    final paceZones = StravaPaceZones.fromJson(
      requiredMap(json, 'paceZones', context: 'coaching profile'),
    );
    final terrain = _requiredTerrain(
      json,
      'terrain',
      context: 'coaching profile',
    );
    final recoveryGuardrails = _requiredGuardrailList(
      json,
      'recoveryGuardrails',
      context: 'coaching profile',
    );
    final raceTargets = _requiredRaceTargetList(
      json,
      'raceTargets',
      context: 'coaching profile',
    );
    final planFocus = StravaPlanFocus.fromJson(
      requiredMap(json, 'planFocus', context: 'coaching profile'),
    );

    return StravaCoachingProfile(
      provenance: provenance,
      dataConfidence: dataConfidence,
      trainingBase: trainingBase,
      endurance: endurance,
      speedMarkers: speedMarkers,
      paceZones: paceZones,
      terrain: terrain,
      recoveryGuardrails: recoveryGuardrails,
      raceTargets: raceTargets,
      planFocus: planFocus,
    );
  }
}

StravaDataConfidence _requiredConfidence(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = requiredString(json, key, context: context);
  final parsed = StravaDataConfidence.fromKey(raw);
  if (parsed == null) {
    throw FormatException('Invalid $context: unsupported $key "$raw".');
  }
  return parsed;
}

StravaTerrainProfile _requiredTerrain(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = requiredString(json, key, context: context);
  final parsed = StravaTerrainProfile.fromKey(raw);
  if (parsed == null) {
    throw FormatException('Invalid $context: unsupported $key "$raw".');
  }
  return parsed;
}

StravaPaceZone _paceZoneOrEmpty(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) {
    return const StravaPaceZone();
  }
  if (raw is! Map) {
    throw FormatException(
      'Invalid pace zones: $key must be a map when present.',
    );
  }
  return StravaPaceZone.fromJson(
    raw.cast<String, dynamic>(),
    context: 'pace zones.$key',
  );
}

List<StravaEvidencePoint> _requiredEvidenceList(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final list = requiredList(json, key, context: context);
  return list
      .map((entry) {
        if (entry is! Map) {
          throw FormatException(
            'Invalid $context: $key must contain object entries.',
          );
        }
        return StravaEvidencePoint.fromJson(entry.cast<String, dynamic>());
      })
      .toList(growable: false);
}

List<StravaGuardrail> _requiredGuardrailList(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final list = requiredList(json, key, context: context);
  return list
      .map((entry) {
        if (entry is! Map) {
          throw FormatException(
            'Invalid $context: $key must contain object entries.',
          );
        }
        return StravaGuardrail.fromJson(entry.cast<String, dynamic>());
      })
      .toList(growable: false);
}

List<StravaRaceTargetEstimate> _requiredRaceTargetList(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final list = requiredList(json, key, context: context);
  return list
      .map((entry) {
        if (entry is! Map) {
          throw FormatException(
            'Invalid $context: $key must contain object entries.',
          );
        }
        return StravaRaceTargetEstimate.fromJson(entry.cast<String, dynamic>());
      })
      .toList(growable: false);
}
