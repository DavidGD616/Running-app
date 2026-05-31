import 'dart:math' as math;

import '../../profile/domain/models/runner_profile.dart';
import 'models/strava_athlete.dart';

enum VolumeTrend { building, steady, detraining }

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

  final weeksForVolume = dataWeeks == 0 ? 4 : dataWeeks.clamp(4, 8);
  final weeklyVolumeKm = _mean(
    weeklyKmByBucket.sublist(weeklyKmByBucket.length - weeksForVolume),
  );

  final priorFourWeekMean = _mean(weeklyKmByBucket.sublist(0, 4));
  final lastFourWeekMean = _mean(weeklyKmByBucket.sublist(4, 8));
  final volumeTrend = _deriveVolumeTrend(
    previousMean: priorFourWeekMean,
    currentMean: lastFourWeekMean,
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
      return !activityDate.isBefore(nowDate.subtract(const Duration(days: 7)));
    }),
  );

  final chronicDistanceKm = _sumDistance(
    runActivities.where((activity) {
      final activityDate = _dateOnly(activity.startDate);
      return !activityDate.isBefore(nowDate.subtract(const Duration(days: 28)));
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
  final estimatedThresholdPaceSecPerKm = _deriveEstimatedThresholdPace(
    recentRuns12Weeks: recentRuns12Weeks,
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
  if (summary.insufficientData && summary.weeklyVolumeKm < 8) {
    return RunnerExperience.brandNew;
  }

  if (summary.weeklyVolumeKm < 20 || summary.runsPerWeek < 2) {
    return RunnerExperience.beginner;
  }

  if (summary.weeklyVolumeKm < 45 || summary.runsPerWeek < 4) {
    return RunnerExperience.intermediate;
  }

  return RunnerExperience.experienced;
}

BenchmarkProjection mapSummaryToBenchmark(AthleteSummary summary) {
  final thresholdPaceSecPerKm = summary.estimatedThresholdPaceSecPerKm;
  if (thresholdPaceSecPerKm == null || thresholdPaceSecPerKm <= 0) {
    return const BenchmarkProjection(type: BenchmarkType.skip);
  }

  if (summary.longestRecentRunKm >= 18) {
    return BenchmarkProjection(
      type: BenchmarkType.halfMarathon,
      time: Duration(seconds: thresholdPaceSecPerKm * 21),
    );
  }

  if (summary.longestRecentRunKm >= 9) {
    return BenchmarkProjection(
      type: BenchmarkType.tenK,
      time: Duration(seconds: thresholdPaceSecPerKm * 10),
    );
  }

  if (summary.longestRecentRunKm >= 4) {
    return BenchmarkProjection(
      type: BenchmarkType.fiveK,
      time: Duration(seconds: thresholdPaceSecPerKm * 5),
    );
  }

  return BenchmarkProjection(
    type: BenchmarkType.oneKmRun,
    time: Duration(seconds: thresholdPaceSecPerKm),
  );
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

int? _deriveEstimatedThresholdPace({
  required List<StravaSummaryActivity> recentRuns12Weeks,
  required int? fallbackHardPaceSecPerKm,
}) {
  final sustainedRuns = recentRuns12Weeks
      .where((run) => run.movingTimeSeconds >= 20 * 60 && run.distanceKm >= 3)
      .toList(growable: false);

  if (sustainedRuns.isEmpty) {
    if (fallbackHardPaceSecPerKm == null) return null;
    return (fallbackHardPaceSecPerKm * 1.04).round();
  }

  final fastestSustainedPaceSecPerKm = sustainedRuns
      .map((run) => run.movingTimeSeconds / run.distanceKm)
      .reduce(math.min);
  return (fastestSustainedPaceSecPerKm * 1.06).round();
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
