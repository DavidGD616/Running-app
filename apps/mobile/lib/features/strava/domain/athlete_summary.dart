import 'dart:math' as math;

import '../../profile/domain/models/runner_profile.dart';
import 'models/strava_athlete.dart';

const int _distanceScale = 10000;
const int _oneKmScaled = _distanceScale; // 1 km in fixed-point distance units.
const int _fiveKmScaled = 5 * _oneKmScaled;
const int _tenKmScaled = 10 * _oneKmScaled;
const int _halfMarathonKmScaled = 210975; // 21.0975 km in fixed-point distance units.

enum VolumeTrend { building, steady, detraining }

extension VolumeTrendPersistence on VolumeTrend {
  String toKey() {
    return switch (this) {
      VolumeTrend.building => 'building',
      VolumeTrend.steady => 'steady',
      VolumeTrend.detraining => 'detraining',
    };
  }
}

class AthleteSummary {
  const AthleteSummary({
    required this.weeklyVolumeKm,
    required this.volumeTrend,
    required this.acuteChronicRatio,
    required this.longestRecentRunKm,
    required this.typicalEasyPaceSecPerKm,
    required this.typicalHardPaceSecPerKm,
    required this.estimatedThresholdPaceSecPerKm,
    required this.runsPerWeek,
    required this.longestLayoffDays,
    required this.weeksActiveInLast8,
    required this.dataWeeks,
    required this.insufficientData,
    required this.hasHeartRateZones,
    this.referenceEffortDistanceKm,
    this.referenceEffortSeconds,
  });

  final double weeklyVolumeKm;
  final VolumeTrend volumeTrend;
  final double acuteChronicRatio;
  final double longestRecentRunKm;
  final int? typicalEasyPaceSecPerKm;
  final int? typicalHardPaceSecPerKm;
  final int? estimatedThresholdPaceSecPerKm;
  final double runsPerWeek;
  final int longestLayoffDays;
  final int weeksActiveInLast8;
  final int dataWeeks;
  final bool insufficientData;
  final bool hasHeartRateZones;

  /// Distance of the best recent sustained effort used as the Riegel anchor for
  /// benchmark projections. Null when no reliable effort is available.
  final double? referenceEffortDistanceKm;

  /// Moving time (seconds) of [referenceEffortDistanceKm]'s effort.
  final int? referenceEffortSeconds;
}

class BenchmarkProjection {
  const BenchmarkProjection({required this.type, this.time});

  final BenchmarkType type;
  final Duration? time;
}

class OnboardingFitnessMapping {
  const OnboardingFitnessMapping({
    required this.weeklyVolume,
    required this.longestRun,
    required this.experience,
    required this.benchmark,
  });

  final WeeklyVolumeRange weeklyVolume;
  final LongestRunRange longestRun;
  final RunnerExperience experience;
  final BenchmarkProjection benchmark;
}

AthleteSummary deriveAthleteSummary(
  Iterable<StravaSummaryActivity> activities,
  StravaAthleteStats? stats,
  StravaAthlete? athlete,
  DateTime now,
) {
  final nowDate = _dateOnly(now);
  final runActivities =
      activities
          .where((activity) => activity.isRun)
          .where((activity) => !_dateOnly(activity.startDate).isAfter(nowDate))
          .where(
            (activity) =>
                activity.distanceMeters > 0 && activity.movingTimeSeconds > 0,
          )
          .toList(growable: false)
        ..sort((left, right) => left.startDate.compareTo(right.startDate));

  final weeklyKmByBucket = _buildEightWeekVolumeBuckets(
    runActivities: runActivities,
    nowDate: nowDate,
  );
  final weeksActiveInLast8 = weeklyKmByBucket
      .where((value) => value > 0)
      .length;
  final dataWeeks = _deriveDataWeeks(
    runActivities: runActivities,
    nowDate: nowDate,
  );

  // The trailing bucket is the week containing `now`. When `now` is mid-week
  // that bucket only holds a partial week of running, which would deflate the
  // volume mean and distort the trend. Drop it from completed-week stats unless
  // `now` is the final day of its week (Sunday), in which case it is complete.
  final currentWeekComplete = nowDate.weekday == DateTime.sunday;
  final completedWeekBuckets = currentWeekComplete
      ? weeklyKmByBucket
      : weeklyKmByBucket.sublist(0, weeklyKmByBucket.length - 1);

  final completedDataWeeks = currentWeekComplete
      ? dataWeeks
      : (dataWeeks - 1).clamp(0, completedWeekBuckets.length);
  final weeksForVolume = completedDataWeeks == 0
      ? math.min(4, completedWeekBuckets.length)
      : completedDataWeeks.clamp(4, completedWeekBuckets.length);
  final weeklyVolumeKm = _mean(
    completedWeekBuckets.sublist(completedWeekBuckets.length - weeksForVolume),
  );

  // Compare the older half of the completed weeks against the more recent half
  // so the in-progress week never skews the trend toward false detraining.
  final trendSplit = completedWeekBuckets.length ~/ 2;
  final priorMean = _mean(completedWeekBuckets.sublist(0, trendSplit));
  final recentMean = _mean(completedWeekBuckets.sublist(trendSplit));
  final volumeTrend = _deriveVolumeTrend(
    previousMean: priorMean,
    currentMean: recentMean,
  );

  final recentRuns12Weeks = runActivities
      .where((activity) {
        final activityDate = _dateOnly(activity.startDate);
        return !activityDate.isBefore(
          nowDate.subtract(const Duration(days: 84)),
        );
      })
      .toList(growable: false);

  final acuteDistanceKm = _sumDistance(
    runActivities.where((activity) {
      final activityDate = _dateOnly(activity.startDate);
      // True trailing 7-day window: [now-6, now] inclusive spans 7 calendar days.
      return !activityDate.isBefore(nowDate.subtract(const Duration(days: 6)));
    }),
  );

  final chronicDistanceKm = _sumDistance(
    runActivities.where((activity) {
      final activityDate = _dateOnly(activity.startDate);
      // True trailing 28-day window: [now-27, now] inclusive spans 28 days.
      return !activityDate.isBefore(nowDate.subtract(const Duration(days: 27)));
    }),
  );
  final chronicWeeklyAverageKm = chronicDistanceKm / 4.0;
  final acuteChronicRatio = chronicWeeklyAverageKm > 0
      ? acuteDistanceKm / chronicWeeklyAverageKm
      : 0.0;

  final longestRecentRunKm = recentRuns12Weeks.isEmpty
      ? 0.0
      : recentRuns12Weeks
            .map((activity) => activity.distanceKm)
            .reduce(math.max);

  final paceSamplesSecPerKm =
      recentRuns12Weeks
          .where((activity) => activity.distanceKm >= 1)
          .map((activity) => activity.movingTimeSeconds / activity.distanceKm)
          .where((pace) => pace.isFinite && pace > 0)
          .toList(growable: false)
        ..sort();

  final typicalHardPaceSecPerKm = _deriveTypicalHardPace(paceSamplesSecPerKm);
  final typicalEasyPaceSecPerKm = _deriveTypicalEasyPace(paceSamplesSecPerKm);

  // The fastest sustained effort is the most reliable single (distance, time)
  // data point and anchors both the threshold estimate and benchmark Riegel
  // projections.
  final referenceEffort = _bestSustainedEffort(recentRuns12Weeks);
  final estimatedThresholdPaceSecPerKm = _deriveEstimatedThresholdPace(
    referenceEffort: referenceEffort,
    fallbackHardPaceSecPerKm: typicalHardPaceSecPerKm,
  );

  final runCountInDataWindow = _countRunsInDataWindow(
    runActivities: runActivities,
    nowDate: nowDate,
    dataWeeks: dataWeeks,
  );
  final runsPerWeek = dataWeeks > 0 ? runCountInDataWindow / dataWeeks : 0.0;

  final longestLayoffDays = _deriveLongestLayoffDays(
    recentRuns12Weeks: recentRuns12Weeks,
    nowDate: nowDate,
  );

  final historicalRunCount = stats?.allRunTotals.activityCount ?? 0;
  final hasMinimalHistory = historicalRunCount > 0 || runActivities.isNotEmpty;
  final insufficientData =
      !hasMinimalHistory ||
      runCountInDataWindow < 8 ||
      weeksActiveInLast8 < 3 ||
      paceSamplesSecPerKm.length < 6;

  return AthleteSummary(
    weeklyVolumeKm: weeklyVolumeKm,
    volumeTrend: volumeTrend,
    acuteChronicRatio: acuteChronicRatio,
    longestRecentRunKm: longestRecentRunKm,
    typicalEasyPaceSecPerKm: typicalEasyPaceSecPerKm,
    typicalHardPaceSecPerKm: typicalHardPaceSecPerKm,
    estimatedThresholdPaceSecPerKm: estimatedThresholdPaceSecPerKm,
    runsPerWeek: runsPerWeek,
    longestLayoffDays: longestLayoffDays,
    weeksActiveInLast8: weeksActiveInLast8,
    dataWeeks: dataWeeks,
    insufficientData: insufficientData,
    hasHeartRateZones:
        athlete?.heartRateZones?.orderedZones.isNotEmpty ?? false,
    referenceEffortDistanceKm: referenceEffort?.distanceKm,
    referenceEffortSeconds: referenceEffort?.movingTimeSeconds,
  );
}

OnboardingFitnessMapping mapSummaryToOnboarding(AthleteSummary summary) {
  return OnboardingFitnessMapping(
    weeklyVolume: mapWeeklyVolumeKmToCanonicalRange(summary.weeklyVolumeKm),
    longestRun: mapLongestRunKmToCanonicalRange(summary.longestRecentRunKm),
    experience: mapSummaryToExperience(summary),
    benchmark: mapSummaryToBenchmark(summary),
  );
}

WeeklyVolumeRange mapWeeklyVolumeKmToCanonicalRange(double weeklyVolumeKm) {
  if (weeklyVolumeKm <= 0) return WeeklyVolumeRange.volume0;
  if (weeklyVolumeKm <= 13) return WeeklyVolumeRange.volume1;
  if (weeklyVolumeKm <= 16) return WeeklyVolumeRange.volume2;
  if (weeklyVolumeKm <= 24) return WeeklyVolumeRange.volume3;
  if (weeklyVolumeKm <= 32) return WeeklyVolumeRange.volume4;
  if (weeklyVolumeKm <= 48) return WeeklyVolumeRange.volume5;
  return WeeklyVolumeRange.volume6;
}

LongestRunRange mapLongestRunKmToCanonicalRange(double longestRunKm) {
  if (longestRunKm <= 0) return LongestRunRange.run0;
  if (longestRunKm < 5) return LongestRunRange.run1;
  if (longestRunKm <= 8) return LongestRunRange.run2;
  if (longestRunKm <= 13) return LongestRunRange.run3;
  if (longestRunKm <= 16) return LongestRunRange.run4;
  if (longestRunKm <= 21) return LongestRunRange.run5;
  return LongestRunRange.run6;
}

RunnerExperience mapSummaryToExperience(AthleteSummary summary) {
  if (summary.insufficientData) {
    if (summary.weeklyVolumeKm < 8 || summary.runsPerWeek < 1.5) {
      return RunnerExperience.brandNew;
    }
    return RunnerExperience.beginner;
  }

  if (summary.weeklyVolumeKm < 20 || summary.runsPerWeek < 2) {
    return RunnerExperience.beginner;
  }

  if (summary.weeklyVolumeKm < 45 || summary.runsPerWeek < 4) {
    return RunnerExperience.intermediate;
  }

  return RunnerExperience.experienced;
}

/// Riegel endurance exponent. Times grow faster than linearly with distance:
/// `T2 = T1 * (D2 / D1)^_riegelExponent`.
const double _riegelExponent = 1.06;

BenchmarkProjection mapSummaryToBenchmark(AthleteSummary summary) {
  final thresholdPaceSecPerKm = summary.estimatedThresholdPaceSecPerKm;
  if (thresholdPaceSecPerKm == null || thresholdPaceSecPerKm <= 0) {
    return const BenchmarkProjection(type: BenchmarkType.skip);
  }

  // Anchor the Riegel projection on the best recent sustained effort when
  // available. Otherwise fall back to the effort implied by threshold pace:
  // threshold pace is, by definition, sustainable for ~1 hour, so anchor at
  // (threshold distance, 3600 s) rather than a 1 km pace point (which would
  // exaggerate fade across many doublings).
  final hasReferenceEffort =
      summary.referenceEffortDistanceKm != null &&
      summary.referenceEffortDistanceKm! > 0 &&
      summary.referenceEffortSeconds != null &&
      summary.referenceEffortSeconds! > 0;
  final double knownDistanceKm;
  final double knownSeconds;
  if (hasReferenceEffort) {
    knownDistanceKm = summary.referenceEffortDistanceKm!;
    knownSeconds = summary.referenceEffortSeconds!.toDouble();
  } else {
    knownSeconds = 3600.0;
    knownDistanceKm = knownSeconds / thresholdPaceSecPerKm;
  }

  BenchmarkProjection project(BenchmarkType type, int scaledTargetDistanceKm) {
    final seconds = _projectDurationSeconds(
      knownDistanceKm: knownDistanceKm,
      knownSeconds: knownSeconds,
      scaledTargetDistanceKm: scaledTargetDistanceKm,
    );
    return BenchmarkProjection(type: type, time: Duration(seconds: seconds));
  }

  if (summary.longestRecentRunKm >= 18) {
    return project(BenchmarkType.halfMarathon, _halfMarathonKmScaled);
  }
  if (summary.longestRecentRunKm >= 9) {
    return project(BenchmarkType.tenK, _tenKmScaled);
  }
  if (summary.longestRecentRunKm >= 4) {
    return project(BenchmarkType.fiveK, _fiveKmScaled);
  }
  return project(BenchmarkType.oneKmRun, _oneKmScaled);
}

/// Projects the duration for [scaledTargetDistanceKm] from a known
/// (distance, time) effort using Riegel's endurance model:
/// `T_target = T_known * (D_target / D_known)^_riegelExponent`.
int _projectDurationSeconds({
  required double knownDistanceKm,
  required double knownSeconds,
  required int scaledTargetDistanceKm,
}) {
  if (knownDistanceKm <= 0) {
    throw ArgumentError.value(
      knownDistanceKm,
      'knownDistanceKm',
      'Known effort distance must be positive.',
    );
  }
  if (knownSeconds <= 0) {
    throw ArgumentError.value(
      knownSeconds,
      'knownSeconds',
      'Known effort time must be positive.',
    );
  }
  if (scaledTargetDistanceKm <= 0) {
    throw ArgumentError.value(
      scaledTargetDistanceKm,
      'scaledTargetDistanceKm',
      'Benchmark distance must be positive.',
    );
  }

  final targetDistanceKm = scaledTargetDistanceKm / _distanceScale;
  final projectedSeconds =
      knownSeconds *
      math.pow(targetDistanceKm / knownDistanceKm, _riegelExponent);
  return projectedSeconds.round();
}

List<double> _buildEightWeekVolumeBuckets({
  required List<StravaSummaryActivity> runActivities,
  required DateTime nowDate,
}) {
  final currentWeekStart = _mondayOf(nowDate);
  final oldestWeekStart = currentWeekStart.subtract(const Duration(days: 49));
  final buckets = List<double>.filled(8, 0);

  for (final run in runActivities) {
    final activityWeekStart = _mondayOf(_dateOnly(run.startDate));
    if (activityWeekStart.isBefore(oldestWeekStart) ||
        activityWeekStart.isAfter(currentWeekStart)) {
      continue;
    }

    final index = activityWeekStart.difference(oldestWeekStart).inDays ~/ 7;
    buckets[index] += run.distanceKm;
  }

  return buckets;
}

int _deriveDataWeeks({
  required List<StravaSummaryActivity> runActivities,
  required DateTime nowDate,
}) {
  final currentWeekStart = _mondayOf(nowDate);
  final oldestWeekStart = currentWeekStart.subtract(const Duration(days: 49));
  final recentRuns = runActivities
      .where((activity) {
        final activityDate = _dateOnly(activity.startDate);
        return !activityDate.isBefore(oldestWeekStart) &&
            !activityDate.isAfter(nowDate);
      })
      .toList(growable: false);

  if (recentRuns.isEmpty) return 0;

  final oldestRunWeekStart = _mondayOf(_dateOnly(recentRuns.first.startDate));
  final weekSpan = currentWeekStart.difference(oldestRunWeekStart).inDays ~/ 7;
  return (weekSpan + 1).clamp(1, 8);
}

VolumeTrend _deriveVolumeTrend({
  required double previousMean,
  required double currentMean,
}) {
  if (previousMean <= 0) {
    if (currentMean <= 0) return VolumeTrend.steady;
    return VolumeTrend.building;
  }

  final deltaRatio = (currentMean - previousMean) / previousMean;
  if (deltaRatio >= 0.15) return VolumeTrend.building;
  if (deltaRatio <= -0.15) return VolumeTrend.detraining;
  return VolumeTrend.steady;
}

double _sumDistance(Iterable<StravaSummaryActivity> activities) {
  return activities.fold<double>(
    0,
    (sum, activity) => sum + activity.distanceKm,
  );
}

int? _deriveTypicalHardPace(List<double> paceSamplesSecPerKm) {
  if (paceSamplesSecPerKm.isEmpty) return null;

  final count = math.max(1, (paceSamplesSecPerKm.length * 0.15).round());
  final hardest = paceSamplesSecPerKm.take(count).toList(growable: false);
  return _median(hardest)?.round();
}

int? _deriveTypicalEasyPace(List<double> paceSamplesSecPerKm) {
  if (paceSamplesSecPerKm.isEmpty) return null;

  final count = math.max(1, (paceSamplesSecPerKm.length * 0.70).round());
  final easiest = paceSamplesSecPerKm
      .skip(paceSamplesSecPerKm.length - count)
      .toList(growable: false);
  return _median(easiest)?.round();
}

/// Picks the most reliable recent sustained effort (>= 20 min, >= 3 km) as the
/// single fastest-paced effort. Returns null when none qualify.
StravaSummaryActivity? _bestSustainedEffort(
  List<StravaSummaryActivity> recentRuns12Weeks,
) {
  StravaSummaryActivity? best;
  double? bestPace;
  for (final run in recentRuns12Weeks) {
    if (run.movingTimeSeconds < 20 * 60 || run.distanceKm < 3) continue;
    final pace = run.movingTimeSeconds / run.distanceKm;
    if (!pace.isFinite || pace <= 0) continue;
    if (bestPace == null || pace < bestPace) {
      bestPace = pace;
      best = run;
    }
  }
  return best;
}

int? _deriveEstimatedThresholdPace({
  required StravaSummaryActivity? referenceEffort,
  required int? fallbackHardPaceSecPerKm,
}) {
  if (referenceEffort == null) {
    if (fallbackHardPaceSecPerKm == null) return null;
    return (fallbackHardPaceSecPerKm * 1.04).round();
  }

  // Threshold pace is the pace sustainable for ~1 hour. Project the reference
  // effort to the distance that takes 3600 s under Riegel, then take that
  // distance's average pace. Solving T_known * (D / D_known)^e = 3600 gives
  // D = D_known * (3600 / T_known)^(1/e); threshold pace = 3600 / D.
  final knownDistanceKm = referenceEffort.distanceKm;
  final knownSeconds = referenceEffort.movingTimeSeconds.toDouble();
  if (knownDistanceKm <= 0 || knownSeconds <= 0) {
    if (fallbackHardPaceSecPerKm == null) return null;
    return (fallbackHardPaceSecPerKm * 1.04).round();
  }

  const thresholdSeconds = 3600.0;
  final thresholdDistanceKm =
      knownDistanceKm *
      math.pow(thresholdSeconds / knownSeconds, 1 / _riegelExponent);
  if (thresholdDistanceKm <= 0) {
    if (fallbackHardPaceSecPerKm == null) return null;
    return (fallbackHardPaceSecPerKm * 1.04).round();
  }
  return (thresholdSeconds / thresholdDistanceKm).round();
}

int _countRunsInDataWindow({
  required List<StravaSummaryActivity> runActivities,
  required DateTime nowDate,
  required int dataWeeks,
}) {
  if (dataWeeks <= 0) return 0;

  final currentWeekStart = _mondayOf(nowDate);
  final start = currentWeekStart.subtract(Duration(days: (dataWeeks - 1) * 7));
  return runActivities.where((activity) {
    final date = _dateOnly(activity.startDate);
    return !date.isBefore(start) && !date.isAfter(nowDate);
  }).length;
}

int _deriveLongestLayoffDays({
  required List<StravaSummaryActivity> recentRuns12Weeks,
  required DateTime nowDate,
}) {
  final windowStart = nowDate.subtract(const Duration(days: 84));
  final uniqueRunDates =
      recentRuns12Weeks
          .map((run) => _dateOnly(run.startDate))
          .toSet()
          .toList(growable: false)
        ..sort();

  if (uniqueRunDates.isEmpty) {
    return nowDate.difference(windowStart).inDays;
  }

  var longest = uniqueRunDates.first.difference(windowStart).inDays;
  for (var index = 1; index < uniqueRunDates.length; index++) {
    final daysBetween =
        uniqueRunDates[index].difference(uniqueRunDates[index - 1]).inDays - 1;
    if (daysBetween > longest) {
      longest = daysBetween;
    }
  }

  final tailGap = nowDate.difference(uniqueRunDates.last).inDays;
  return math.max(longest, tailGap);
}

DateTime _dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

DateTime _mondayOf(DateTime date) {
  final normalizedDate = _dateOnly(date);
  return normalizedDate.subtract(Duration(days: normalizedDate.weekday - 1));
}

double _mean(List<double> values) {
  if (values.isEmpty) return 0;
  return values.reduce((left, right) => left + right) / values.length;
}

double? _median(List<double> sortedValues) {
  if (sortedValues.isEmpty) return null;

  final middle = sortedValues.length ~/ 2;
  if (sortedValues.length.isOdd) {
    return sortedValues[middle];
  }

  return (sortedValues[middle - 1] + sortedValues[middle]) / 2;
}
