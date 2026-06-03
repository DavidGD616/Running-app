import 'dart:math' as math;

import 'athlete_summary.dart';
import '../../profile/domain/models/runner_profile.dart';
import 'models/strava_athlete.dart';

const int _recentWindowDays = 84;
const int _olderWindowDays = 183;
const double _rollingTerrainThresholdMPerKm = 8;
const double _hillyTerrainThresholdMPerKm = 20;

StravaCoachingProfile buildStravaCoachingProfile(
  Iterable<StravaSummaryActivity> activities, {
  StravaAthleteStats? stats,
  StravaAthlete? athlete,
  DateTime? now,
  DateTime? syncedAt,
}) {
  final effectiveNow = (now ?? DateTime.now()).toUtc();
  final nowDate = _dateOnly(effectiveNow);
  final validActivities = activities
      .where((activity) => !activity.startDate.toUtc().isAfter(effectiveNow))
      .toList(growable: false);
  final runActivities = validActivities
      .where((activity) => activity.isRun)
      .where((activity) => activity.distanceKm > 0)
      .where((activity) => activity.movingTimeSeconds > 0)
      .toList(growable: false);

  final summary = deriveAthleteSummary(
    validActivities,
    stats,
    athlete,
    effectiveNow,
  );

  final recentWindowStart = nowDate.subtract(
    const Duration(days: _recentWindowDays),
  );
  final olderWindowStart = nowDate.subtract(
    const Duration(days: _olderWindowDays),
  );
  final recentRuns12Weeks = runActivities
      .where(
        (activity) =>
            !_dateOnly(activity.startDate).isBefore(recentWindowStart) &&
            !_dateOnly(activity.startDate).isAfter(nowDate),
      )
      .toList(growable: false);
  final olderRuns = runActivities
      .where(
        (activity) =>
            _dateOnly(activity.startDate).isAfter(olderWindowStart) &&
            _dateOnly(activity.startDate).isBefore(recentWindowStart),
      )
      .toList(growable: false);

  final dataConfidence = _deriveDataConfidence(
    summary: summary,
    olderRunCount: olderRuns.length,
  );

  final trainingBase = dataConfidence == StravaDataConfidence.limited
      ? const <StravaEvidencePoint>[]
      : _buildTrainingBase(
          summary: summary,
          recentRuns: recentRuns12Weeks,
          nowDate: nowDate,
        );

  final endurance = dataConfidence == StravaDataConfidence.limited
      ? const <StravaEvidencePoint>[]
      : _buildEndurance(
          summary: summary,
          recentRuns: recentRuns12Weeks,
          nowDate: nowDate,
        );

  final speedMarkers = dataConfidence == StravaDataConfidence.limited
      ? const <StravaEvidencePoint>[]
      : _buildSpeedMarkers(summary: summary, recentRuns: recentRuns12Weeks);

  final terrain = _deriveTerrainProfile(recentRuns12Weeks);
  final paceZones = dataConfidence == StravaDataConfidence.limited
      ? const StravaPaceZones.empty()
      : _buildPaceZones(
          thresholdPaceSecPerKm: summary.estimatedThresholdPaceSecPerKm,
          easyPaceSecPerKm: summary.typicalEasyPaceSecPerKm,
          hardPaceSecPerKm: summary.typicalHardPaceSecPerKm,
        );

  final guardrails = _buildRecoveryGuardrails(
    summary: summary,
    dataConfidence: dataConfidence,
    recentRuns: recentRuns12Weeks,
  );

  final raceTargets = _buildRaceTargets(
    summary: summary,
    dataConfidence: dataConfidence,
    summaryNow: nowDate,
    recentRuns: recentRuns12Weeks,
    olderRuns: olderRuns,
  );

  final planFocus = _buildPlanFocus(
    dataConfidence: dataConfidence,
    summary: summary,
    guardrails: guardrails,
    hasTerrainEvidence: recentRuns12Weeks.isNotEmpty,
    hasRaceTargets: raceTargets.isNotEmpty,
  );

  final provenanceWindowStart = recentRuns12Weeks.isEmpty
      ? nowDate.subtract(const Duration(days: _recentWindowDays))
      : _dateOnly(
          recentRuns12Weeks
              .map((activity) => activity.startDate)
              .reduce((left, right) => left.isBefore(right) ? left : right),
        );
  final provenanceWindowEnd = recentRuns12Weeks.isEmpty
      ? nowDate
      : _dateOnly(
          recentRuns12Weeks
              .map((activity) => activity.startDate)
              .reduce((left, right) => left.isAfter(right) ? left : right),
        );
  final provenanceRunCount = recentRuns12Weeks.length;

  final provenance = StravaAnalysisProvenance(
    source: 'strava_sync',
    syncedAt: (syncedAt ?? effectiveNow).toUtc(),
    dataWindow: 'last12Weeks',
    dataFromDate: provenanceWindowStart,
    dataThroughDate: provenanceWindowEnd,
    activityCount: provenanceRunCount,
    runActivityCount: provenanceRunCount,
    confidence: dataConfidence,
  );

  return StravaCoachingProfile(
    provenance: provenance,
    dataConfidence: dataConfidence,
    trainingBase: trainingBase,
    endurance: endurance,
    speedMarkers: speedMarkers,
    paceZones: paceZones,
    terrain: terrain,
    recoveryGuardrails: guardrails,
    raceTargets: raceTargets,
    planFocus: planFocus,
  );
}

StravaDataConfidence _deriveDataConfidence({
  required AthleteSummary summary,
  required int olderRunCount,
}) {
  final hasAnyRecentRun =
      summary.runsPerWeek > 0 || summary.longestRecentRunKm > 0;
  if (!hasAnyRecentRun || summary.weeklyVolumeKm <= 0) {
    return StravaDataConfidence.limited;
  }

  final hasPaceSignals =
      summary.typicalEasyPaceSecPerKm != null &&
      summary.typicalHardPaceSecPerKm != null &&
      summary.estimatedThresholdPaceSecPerKm != null;

  final hasSufficientRecentData =
      !summary.insufficientData &&
      summary.weeksActiveInLast8 >= 4 &&
      summary.runsPerWeek >= 2 &&
      summary.longestRecentRunKm >= 8 &&
      summary.acuteChronicRatio >= 0.6 &&
      summary.acuteChronicRatio <= 1.8 &&
      hasPaceSignals;

  if (hasSufficientRecentData) {
    return StravaDataConfidence.high;
  }

  if (!summary.insufficientData && hasPaceSignals && olderRunCount > 0) {
    return StravaDataConfidence.medium;
  }

  if (!summary.insufficientData && summary.runsPerWeek >= 1.5) {
    return StravaDataConfidence.medium;
  }

  if (olderRunCount >= 1 && hasPaceSignals) {
    return StravaDataConfidence.medium;
  }

  return StravaDataConfidence.limited;
}

List<StravaEvidencePoint> _buildTrainingBase({
  required AthleteSummary summary,
  required List<StravaSummaryActivity> recentRuns,
  required DateTime nowDate,
}) {
  if (recentRuns.isEmpty) {
    return const [];
  }

  final evidenceDate = _mostRecentDate(recentRuns) ?? nowDate;

  return [
    StravaEvidencePoint(
      metric: 'training_base_weekly_km',
      date: evidenceDate,
      value: summary.weeklyVolumeKm,
      unit: 'km_per_week',
    ),
    StravaEvidencePoint(
      metric: 'training_base_runs_per_week',
      date: evidenceDate,
      value: num.parse(summary.runsPerWeek.toStringAsFixed(1)),
      unit: 'runs_per_week',
    ),
  ];
}

List<StravaEvidencePoint> _buildEndurance({
  required AthleteSummary summary,
  required List<StravaSummaryActivity> recentRuns,
  required DateTime nowDate,
}) {
  if (recentRuns.isEmpty || summary.longestRecentRunKm <= 0) {
    return const [];
  }

  final longRun = recentRuns.reduce((left, right) {
    return left.distanceKm >= right.distanceKm ? left : right;
  });

  return [
    StravaEvidencePoint(
      metric: 'endurance_long_run_km',
      date: _dateOnly(longRun.startDate),
      value: longRun.distanceKm,
      unit: 'km',
    ),
    if (summary.longestLayoffDays >= 6)
      StravaEvidencePoint(
        metric: 'endurance_longest_layoff_days',
        date: _mostRecentDate(recentRuns) ?? nowDate,
        value: summary.longestLayoffDays,
        unit: 'days',
      ),
  ];
}

List<StravaEvidencePoint> _buildSpeedMarkers({
  required AthleteSummary summary,
  required List<StravaSummaryActivity> recentRuns,
}) {
  final samples =
      recentRuns
          .where((activity) => activity.distanceKm >= 1)
          .map(_paceSampleFromActivity)
          .whereType<_PaceSample>()
          .toList(growable: false)
        ..sort(
          (left, right) => left.paceSecPerKm.compareTo(right.paceSecPerKm),
        );

  if (samples.isEmpty) {
    return const [];
  }

  final hardPace = summary.typicalHardPaceSecPerKm;
  final easyPace = summary.typicalEasyPaceSecPerKm;
  final thresholdPace = summary.estimatedThresholdPaceSecPerKm;

  return [
    if (hardPace != null)
      StravaEvidencePoint(
        metric: 'speed_marker_hard_pace',
        date: _closestSampleByPace(samples, hardPace.toDouble())!.date,
        value: hardPace,
        unit: 'sec_per_km',
      ),
    if (easyPace != null)
      StravaEvidencePoint(
        metric: 'speed_marker_easy_pace',
        date: _closestSampleByPace(samples, easyPace.toDouble())!.date,
        value: easyPace,
        unit: 'sec_per_km',
      ),
    if (thresholdPace != null)
      StravaEvidencePoint(
        metric: 'speed_marker_threshold_pace',
        date: _closestSampleByPace(samples, thresholdPace.toDouble())!.date,
        value: thresholdPace,
        unit: 'sec_per_km',
      ),
  ];
}

StravaPaceZones _buildPaceZones({
  required int? thresholdPaceSecPerKm,
  required int? easyPaceSecPerKm,
  required int? hardPaceSecPerKm,
}) {
  if (thresholdPaceSecPerKm == null ||
      easyPaceSecPerKm == null ||
      hardPaceSecPerKm == null) {
    return const StravaPaceZones.empty();
  }

  final threshold = thresholdPaceSecPerKm.toDouble();
  final easy = easyPaceSecPerKm.toDouble();
  final hard = hardPaceSecPerKm.toDouble();
  final easyZone = _paceZoneFromBase(
    baseSecPerKm: threshold,
    minOffset: 12,
    maxOffset: 34,
  );
  final longRunBase = easy > threshold ? easy : threshold + 12;
  final longRunZone = _nonOverlappingLongRunZone(
    longRunBaseSecPerKm: longRunBase,
    thresholdSecPerKm: threshold,
    easyZone: easyZone,
  );

  return StravaPaceZones(
    recovery: _paceZoneFromBase(
      baseSecPerKm: easy,
      minOffset: 60,
      maxOffset: 110,
    ),
    easy: easyZone,
    longRun: longRunZone,
    steady: _paceZoneFromBase(
      baseSecPerKm: threshold,
      minOffset: -20,
      maxOffset: 2,
    ),
    tempo: _paceZoneFromBase(
      baseSecPerKm: threshold,
      minOffset: -30,
      maxOffset: -8,
    ),
    threshold: _paceZoneFromBase(
      baseSecPerKm: threshold,
      minOffset: -8,
      maxOffset: 10,
    ),
    racePace: _paceZoneFromBase(
      baseSecPerKm: threshold,
      minOffset: -18,
      maxOffset: -2,
    ),
    intervals: _paceZoneFromBase(
      baseSecPerKm: hard,
      minOffset: -48,
      maxOffset: -16,
    ),
    strides: _paceZoneFromBase(
      baseSecPerKm: hard,
      minOffset: -70,
      maxOffset: -45,
    ),
  );
}

StravaPaceZone _nonOverlappingLongRunZone({
  required double longRunBaseSecPerKm,
  required double thresholdSecPerKm,
  required StravaPaceZone easyZone,
}) {
  final longRun = _paceZoneFromBase(
    baseSecPerKm: longRunBaseSecPerKm,
    minOffset: 0,
    maxOffset: 60,
  );

  final thresholdMax = _paceZoneFromBase(
    baseSecPerKm: thresholdSecPerKm,
    minOffset: 10,
    maxOffset: 30,
  );
  final safeMin = thresholdMax.paceMaxSecPerKm! + 1;
  final longRunFloorMin = longRun.paceMinSecPerKm ?? safeMin;
  final longRunFloorMax = longRun.paceMaxSecPerKm ?? safeMin;
  final easyFloorMax = easyZone.paceMaxSecPerKm ?? safeMin;
  final zoneMin = math.max(longRunFloorMin, safeMin);
  final nonOverlappingMin = math.max(zoneMin, easyFloorMax + 1);
  final zoneMax = math.max(nonOverlappingMin, longRunFloorMax);
  return StravaPaceZone(
    paceMinSecPerKm: nonOverlappingMin,
    paceMaxSecPerKm: zoneMax,
  );
}

StravaPaceZone _paceZoneFromBase({
  required double baseSecPerKm,
  required int minOffset,
  required int maxOffset,
}) {
  final rawMin = baseSecPerKm + minOffset;
  final rawMax = baseSecPerKm + maxOffset;
  final min = math.max(1, rawMin.floor());
  final max = math.max(min, rawMax.floor());
  return StravaPaceZone(paceMinSecPerKm: min, paceMaxSecPerKm: max);
}

List<StravaGuardrail> _buildRecoveryGuardrails({
  required AthleteSummary summary,
  required StravaDataConfidence dataConfidence,
  required List<StravaSummaryActivity> recentRuns,
}) {
  final candidateGuardrails = <StravaGuardrail>[];

  if (summary.acuteChronicRatio > 1.6) {
    candidateGuardrails.add(
      const StravaGuardrail(
        priority: 0,
        category: 'recovery_load_spike',
        message:
            'Recent load is notably above recent 4-week baseline. Keep recovery days easy and frequent.',
      ),
    );
  }

  if (summary.volumeTrend == VolumeTrend.detraining ||
      summary.runsPerWeek < 2.0) {
    candidateGuardrails.add(
      const StravaGuardrail(
        priority: 1,
        category: 'recovery_detraining',
        message:
            'Recent load looks low. Increase consistency before adding intensity.',
      ),
    );
  }

  if (summary.longestLayoffDays >= 14) {
    candidateGuardrails.add(
      const StravaGuardrail(
        priority: 2,
        category: 'recovery_long_layoff',
        message:
            'A long layoff was detected. Build volume gradually for the next block.',
      ),
    );
  }

  if (summary.weeksActiveInLast8 < 3 || summary.insufficientData) {
    candidateGuardrails.add(
      const StravaGuardrail(
        priority: 2,
        category: 'recovery_sparse_data',
        message: 'Data is too sparse to infer stable recovery pacing yet.',
      ),
    );
  }

  final paceSamples = recentRuns
      .where((activity) => activity.distanceKm >= 1)
      .toList(growable: false);
  final paceUncertain =
      paceSamples.length < 6 || paceSamples.length != recentRuns.length;
  if (paceUncertain &&
      paceSamples.isNotEmpty &&
      dataConfidence != StravaDataConfidence.high) {
    candidateGuardrails.add(
      const StravaGuardrail(
        priority: 2,
        category: 'recovery_pace_uncertainty',
        message:
            'Effort pacing is only partially supported by recent samples, use effort cues when needed.',
      ),
    );
  }

  if (dataConfidence == StravaDataConfidence.limited &&
      candidateGuardrails.isEmpty) {
    candidateGuardrails.add(
      const StravaGuardrail(
        priority: 0,
        category: 'recovery_data_collection',
        message:
            'Collect a bit more consistent run data before finalizing training intensity.',
      ),
    );
  }

  candidateGuardrails.sort(
    (left, right) => left.priority.compareTo(right.priority),
  );
  final unique = <String>{};
  final selected = <StravaGuardrail>[];

  for (final guardrail in candidateGuardrails) {
    if (selected.length >= 3) {
      break;
    }
    if (unique.add(guardrail.category)) {
      selected.add(guardrail);
    }
  }

  return selected;
}

List<StravaRaceTargetEstimate> _buildRaceTargets({
  required AthleteSummary summary,
  required StravaDataConfidence dataConfidence,
  required DateTime summaryNow,
  required List<StravaSummaryActivity> recentRuns,
  required List<StravaSummaryActivity> olderRuns,
}) {
  if (dataConfidence == StravaDataConfidence.limited) return const [];

  final projection = mapSummaryToBenchmark(summary);
  if (projection.time == null || projection.type == BenchmarkType.skip) {
    return const [];
  }

  final distanceKm = _benchmarkDistanceKm(projection.type);
  final evidence = <StravaEvidencePoint>[];
  final paceSamples = recentRuns
      .where((activity) => activity.distanceKm >= 1)
      .map(_paceSampleFromActivity)
      .whereType<_PaceSample>()
      .toList(growable: false);

  if (paceSamples.isNotEmpty) {
    final source = _closestSampleByPace(
      paceSamples,
      projection.time!.inSeconds.toDouble() / distanceKm,
    )!;
    evidence.add(
      StravaEvidencePoint(
        metric: 'race_target_reference_effort',
        date: source.date,
        value: projection.time!.inSeconds,
        unit: 'sec',
      ),
    );
  } else {
    evidence.add(
      StravaEvidencePoint(
        metric: 'race_target_reference_run',
        date: summaryNow,
        value: projection.time!.inSeconds,
        unit: 'sec',
      ),
    );
  }

  final stretchTime = _buildStretchTarget(
    distanceKm: distanceKm,
    primarySec: projection.time!.inSeconds,
    olderRuns: olderRuns,
  );

  return [
    StravaRaceTargetEstimate(
      distanceKm: distanceKm,
      primaryTime: projection.time!,
      stretchTime: stretchTime,
      confidence: dataConfidence,
      evidence: evidence,
    ),
  ];
}

Duration? _buildStretchTarget({
  required double distanceKm,
  required int primarySec,
  required List<StravaSummaryActivity> olderRuns,
}) {
  final reference = _bestSustainedEffort(
    olderRuns,
    minDistanceKm: 3,
    minMovingSeconds: 1200,
  );
  if (reference == null) {
    return null;
  }

  if (reference.distanceMeters <= 0 || reference.movingTimeSeconds <= 0) {
    return null;
  }

  final projectedSec = _projectDurationSeconds(
    knownDistanceKm: reference.distanceKm,
    knownSeconds: reference.movingTimeSeconds.toDouble(),
    targetDistanceKm: distanceKm,
  );

  if (projectedSec >= primarySec) {
    return null;
  }

  final maxImprovement = (primarySec * 0.92).round();
  final stretch = math.max(maxImprovement, projectedSec);
  if (stretch >= primarySec) {
    return null;
  }

  return Duration(seconds: stretch);
}

StravaTerrainProfile _deriveTerrainProfile(
  List<StravaSummaryActivity> recentRuns,
) {
  final samples = recentRuns
      .where(
        (activity) =>
            activity.totalElevationGainMeters != null &&
            activity.distanceMeters > 0,
      )
      .toList(growable: false);
  if (samples.isEmpty) {
    return StravaTerrainProfile.notSure;
  }

  var totalDistanceKm = 0.0;
  var totalElevationMeters = 0.0;
  for (final activity in samples) {
    totalDistanceKm += activity.distanceKm;
    totalElevationMeters += activity.totalElevationGainMeters!;
  }

  if (totalDistanceKm <= 0) {
    return StravaTerrainProfile.notSure;
  }

  final elevationPerKm = totalElevationMeters / totalDistanceKm;
  if (elevationPerKm <= _rollingTerrainThresholdMPerKm) {
    return StravaTerrainProfile.flat;
  }
  if (elevationPerKm <= _hillyTerrainThresholdMPerKm) {
    return StravaTerrainProfile.rolling;
  }
  return StravaTerrainProfile.hilly;
}

StravaPlanFocus _buildPlanFocus({
  required StravaDataConfidence dataConfidence,
  required AthleteSummary summary,
  required List<StravaGuardrail> guardrails,
  required bool hasTerrainEvidence,
  required bool hasRaceTargets,
}) {
  if (dataConfidence == StravaDataConfidence.limited) {
    return const StravaPlanFocus(
      category: 'focus_data_collection',
      summary:
          'Collect more consistent runs before Strava-derived target setting.',
    );
  }

  if (guardrails.isNotEmpty) {
    return const StravaPlanFocus(
      category: 'focus_recovery_and_consistency',
      summary:
          'Your recent training shows progress with uneven readiness, so consistency and recovery should lead plan ramp-up.',
    );
  }

  if (dataConfidence == StravaDataConfidence.high &&
      hasTerrainEvidence &&
      hasRaceTargets) {
    return const StravaPlanFocus(
      category: 'focus_threshold_and_endurance',
      summary:
          'Your running base and pace markers are strong; plan can emphasize threshold work with controlled long-run growth.',
    );
  }

  if (summary.weeksActiveInLast8 >= 4 && hasRaceTargets) {
    return const StravaPlanFocus(
      category: 'focus_endurance_and_speed',
      summary:
          'Build on your current base by balancing endurance consistency and controlled speed development.',
    );
  }

  return const StravaPlanFocus(
    category: 'focus_data_collection',
    summary:
        'Keep adding stable running frequency to refine pace zones and guardrails.',
  );
}

_PaceSample? _closestSampleByPace(
  List<_PaceSample> samples,
  double targetPace,
) {
  if (samples.isEmpty) return null;

  var best = samples.first;
  var bestDiff = (best.paceSecPerKm - targetPace).abs();

  for (final sample in samples.skip(1)) {
    final diff = (sample.paceSecPerKm - targetPace).abs();
    if (diff < bestDiff) {
      best = sample;
      bestDiff = diff;
    }
  }

  return best;
}

_PaceSample? _paceSampleFromActivity(StravaSummaryActivity activity) {
  final paceSecPerKm = activity.movingTimeSeconds / activity.distanceKm;
  if (!paceSecPerKm.isFinite || paceSecPerKm <= 0) {
    return null;
  }

  return _PaceSample(
    date: _dateOnly(activity.startDate),
    paceSecPerKm: paceSecPerKm,
  );
}

StravaSummaryActivity? _bestSustainedEffort(
  List<StravaSummaryActivity> activities, {
  required double minDistanceKm,
  required int minMovingSeconds,
}) {
  final candidates =
      activities
          .where(
            (activity) =>
                activity.distanceKm >= minDistanceKm &&
                activity.movingTimeSeconds >= minMovingSeconds,
          )
          .toList(growable: false)
        ..sort((left, right) {
          final leftPace = left.movingTimeSeconds / left.distanceKm;
          final rightPace = right.movingTimeSeconds / right.distanceKm;
          return leftPace.compareTo(rightPace);
        });

  if (candidates.isEmpty) return null;
  return candidates.first;
}

double _benchmarkDistanceKm(BenchmarkType type) {
  switch (type) {
    case BenchmarkType.oneKmRun:
      return 1.0;
    case BenchmarkType.oneKmWalk:
      return 1.0;
    case BenchmarkType.oneMiRun:
      return 1.60934;
    case BenchmarkType.oneMiWalk:
      return 1.60934;
    case BenchmarkType.fiveK:
      return 5.0;
    case BenchmarkType.tenK:
      return 10.0;
    case BenchmarkType.halfMarathon:
      return 21.0975;
    case BenchmarkType.skip:
      return 1.0;
  }
}

int _projectDurationSeconds({
  required double knownDistanceKm,
  required double knownSeconds,
  required double targetDistanceKm,
}) {
  if (knownDistanceKm <= 0) {
    throw ArgumentError.value(
      knownDistanceKm,
      'knownDistanceKm',
      'Known distance must be positive.',
    );
  }
  if (knownSeconds <= 0) {
    throw ArgumentError.value(
      knownSeconds,
      'knownSeconds',
      'Known duration must be positive.',
    );
  }
  if (targetDistanceKm <= 0) {
    throw ArgumentError.value(
      targetDistanceKm,
      'targetDistanceKm',
      'Target distance must be positive.',
    );
  }

  // Riegel exponent for endurance fade.
  const riegelExponent = 1.06;
  final projectedSeconds =
      knownSeconds *
      math.pow(targetDistanceKm / knownDistanceKm, riegelExponent);
  return projectedSeconds.round();
}

DateTime? _mostRecentDate(List<StravaSummaryActivity> activities) {
  if (activities.isEmpty) {
    return null;
  }
  return activities
      .map((activity) => activity.startDate)
      .reduce((left, right) => left.isAfter(right) ? left : right);
}

DateTime _dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

class _PaceSample {
  const _PaceSample({required this.date, required this.paceSecPerKm});

  final DateTime date;
  final double paceSecPerKm;
}
