import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/strava/domain/athlete_summary.dart';
import 'package:running_app/features/strava/domain/models/strava_athlete.dart';

void main() {
  final now = DateTime(2026, 4, 5);
  final currentWeekStart = DateTime(2026, 3, 30);

  test('beginner fixture derives stable low volume summary', () {
    final summary = deriveAthleteSummary(
      _buildBeginnerActivities(currentWeekStart),
      _stats(activityCount: 16),
      _athleteWithHeartRateZones(),
      now,
    );

    expect(summary.insufficientData, isFalse);
    expect(summary.hasHeartRateZones, isTrue);
    expect(summary.volumeTrend, VolumeTrend.steady);
    expect(summary.weeklyVolumeKm, closeTo(9.0, 0.01));
    expect(summary.runsPerWeek, closeTo(2.0, 0.01));
    expect(summary.dataWeeks, 8);
    expect(summary.weeksActiveInLast8, 8);
    expect(summary.acuteChronicRatio, closeTo(1.0, 0.05));
    expect(summary.longestRecentRunKm, closeTo(5.0, 0.01));
    expect(summary.typicalHardPaceSecPerKm, isNotNull);
    expect(summary.typicalEasyPaceSecPerKm, isNotNull);
    expect(
      summary.typicalEasyPaceSecPerKm!,
      greaterThan(summary.typicalHardPaceSecPerKm!),
    );

    final mapping = mapSummaryToOnboarding(summary);
    expect(mapping.weeklyVolume, WeeklyVolumeRange.volume1);
    expect(mapping.longestRun, LongestRunRange.run2);
    expect(mapping.experience, RunnerExperience.beginner);
    expect(mapping.benchmark.type, BenchmarkType.fiveK);
    expect(mapping.benchmark.time, isNotNull);
  });

  test(
    'consistent intermediate fixture derives steady trend and usable paces',
    () {
      final summary = deriveAthleteSummary(
        _buildConsistentIntermediateActivities(currentWeekStart),
        _stats(activityCount: 32),
        null,
        now,
      );

      expect(summary.insufficientData, isFalse);
      expect(summary.volumeTrend, VolumeTrend.steady);
      expect(summary.weeklyVolumeKm, closeTo(32, 0.01));
      expect(summary.runsPerWeek, closeTo(3.875, 0.001));
      expect(summary.longestRecentRunKm, closeTo(12, 0.01));
      expect(summary.acuteChronicRatio, greaterThan(1.2));
      expect(summary.typicalHardPaceSecPerKm, isNotNull);
      expect(summary.typicalEasyPaceSecPerKm, isNotNull);
      expect(summary.estimatedThresholdPaceSecPerKm, isNotNull);
      expect(
        summary.estimatedThresholdPaceSecPerKm!,
        greaterThan(summary.typicalHardPaceSecPerKm!),
      );

      final mapping = mapSummaryToOnboarding(summary);
      expect(mapping.weeklyVolume, WeeklyVolumeRange.volume4);
      expect(mapping.longestRun, LongestRunRange.run3);
      expect(mapping.experience, RunnerExperience.intermediate);
      expect(mapping.benchmark.type, BenchmarkType.tenK);
      expect(mapping.benchmark.time, isNotNull);
    },
  );

  test('detraining fixture derives clear negative trend and low ACWR', () {
    final summary = deriveAthleteSummary(
      _buildDetrainingActivities(currentWeekStart),
      _stats(activityCount: 30),
      null,
      now,
    );

    expect(summary.insufficientData, isFalse);
    expect(summary.volumeTrend, VolumeTrend.detraining);
    expect(summary.weeklyVolumeKm, closeTo(26.5, 0.01));
    expect(summary.runsPerWeek, closeTo(3.625, 0.001));
    expect(summary.acuteChronicRatio, lessThan(0.7));
    expect(summary.longestRecentRunKm, closeTo(8, 0.01));

    final mapping = mapSummaryToOnboarding(summary);
    expect(mapping.weeklyVolume, WeeklyVolumeRange.volume4);
    expect(mapping.longestRun, LongestRunRange.run2);
    expect(mapping.experience, RunnerExperience.intermediate);
  });

  test('sparse fixture marks insufficient data and conservative mapping', () {
    final summary = deriveAthleteSummary(
      _buildSparseActivities(currentWeekStart),
      _stats(activityCount: 3),
      null,
      now,
    );

    expect(summary.insufficientData, isTrue);
    expect(summary.dataWeeks, 8);
    expect(summary.weeksActiveInLast8, 3);
    expect(summary.runsPerWeek, closeTo(0.375, 0.001));
    expect(summary.typicalHardPaceSecPerKm, isNull);
    expect(summary.typicalEasyPaceSecPerKm, isNull);
    expect(summary.estimatedThresholdPaceSecPerKm, isNull);

    final mapping = mapSummaryToOnboarding(summary);
    expect(mapping.weeklyVolume, WeeklyVolumeRange.volume1);
    expect(mapping.longestRun, LongestRunRange.run1);
    expect(mapping.experience, RunnerExperience.brandNew);
    expect(mapping.benchmark.type, BenchmarkType.skip);
    expect(mapping.benchmark.time, isNull);
  });

  test('insufficient data mapping never promotes above beginner', () {
    final summary = AthleteSummary(
      weeklyVolumeKm: 36,
      volumeTrend: VolumeTrend.steady,
      acuteChronicRatio: 1,
      longestRecentRunKm: 14,
      typicalEasyPaceSecPerKm: 360,
      typicalHardPaceSecPerKm: 325,
      estimatedThresholdPaceSecPerKm: 345,
      runsPerWeek: 3,
      longestLayoffDays: 12,
      weeksActiveInLast8: 2,
      dataWeeks: 8,
      insufficientData: true,
      hasHeartRateZones: false,
    );

    expect(mapSummaryToExperience(summary), RunnerExperience.beginner);
  });

  test('insufficient data with low runs per week maps to brand new', () {
    final summary = AthleteSummary(
      weeklyVolumeKm: 12,
      volumeTrend: VolumeTrend.steady,
      acuteChronicRatio: 1,
      longestRecentRunKm: 6,
      typicalEasyPaceSecPerKm: 380,
      typicalHardPaceSecPerKm: 340,
      estimatedThresholdPaceSecPerKm: 355,
      runsPerWeek: 1.25,
      longestLayoffDays: 16,
      weeksActiveInLast8: 3,
      dataWeeks: 8,
      insufficientData: true,
      hasHeartRateZones: false,
    );

    expect(mapSummaryToExperience(summary), RunnerExperience.brandNew);
  });

  test('half marathon benchmark uses official 21.0975 km distance', () {
    final summary = AthleteSummary(
      weeklyVolumeKm: 42,
      volumeTrend: VolumeTrend.steady,
      acuteChronicRatio: 1,
      longestRecentRunKm: 18,
      typicalEasyPaceSecPerKm: 360,
      typicalHardPaceSecPerKm: 330,
      estimatedThresholdPaceSecPerKm: 300,
      runsPerWeek: 4,
      longestLayoffDays: 5,
      weeksActiveInLast8: 8,
      dataWeeks: 8,
      insufficientData: false,
      hasHeartRateZones: true,
    );

    final benchmark = mapSummaryToBenchmark(summary);
    expect(benchmark.type, BenchmarkType.halfMarathon);
    expect(benchmark.time, const Duration(seconds: 6329));
  });

  test('strava parser accepts top HR zone max sentinel -1', () {
    final athlete = StravaAthlete.fromJson({
      'sex': 'F',
      'weight': 61.2,
      'heart_rate_zones': {
        'zones': [
          {'max': 135},
          {'min': 136, 'max': 148},
          {'min': 149, 'max': 160},
          {'min': 161, 'max': 172},
          {'min': 173, 'max': -1},
        ],
      },
    });

    final topZone = athlete.heartRateZones?.zone5;
    expect(topZone, isNotNull);
    expect(topZone!.maxBpm, StravaHeartRateZone.unboundedMaxBpmSentinel);
    expect(topZone.hasUnboundedUpperBound, isTrue);
  });
}

StravaAthleteStats _stats({required int activityCount}) {
  return StravaAthleteStats(
    recentRunTotals: const StravaRunTotals(
      distanceMeters: 12_000,
      movingTimeSeconds: 4_200,
      activityCount: 3,
      elevationGainMeters: 120,
    ),
    ytdRunTotals: const StravaRunTotals(
      distanceMeters: 400_000,
      movingTimeSeconds: 140_000,
      activityCount: 48,
      elevationGainMeters: 2_400,
    ),
    allRunTotals: StravaRunTotals(
      distanceMeters: 2_000_000,
      movingTimeSeconds: 700_000,
      activityCount: activityCount,
      elevationGainMeters: 12_000,
    ),
  );
}

StravaAthlete _athleteWithHeartRateZones() {
  return const StravaAthlete(
    sex: StravaAthleteSex.male,
    weightKg: 70,
    heartRateZones: StravaHeartRateZones(
      zone1: StravaHeartRateZone(minBpm: null, maxBpm: 135),
      zone2: StravaHeartRateZone(minBpm: 136, maxBpm: 148),
      zone3: StravaHeartRateZone(minBpm: 149, maxBpm: 160),
      zone4: StravaHeartRateZone(minBpm: 161, maxBpm: 172),
      zone5: StravaHeartRateZone(minBpm: 173, maxBpm: 195),
    ),
  );
}

List<StravaSummaryActivity> _buildBeginnerActivities(
  DateTime currentWeekStart,
) {
  final activities = <StravaSummaryActivity>[];
  for (var weeksAgo = 7; weeksAgo >= 0; weeksAgo--) {
    activities.addAll([
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 1),
        distanceKm: 4,
        paceSecPerKm: 410,
      ),
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 5),
        distanceKm: 5,
        paceSecPerKm: 390,
      ),
    ]);
  }

  activities.add(
    _ride(
      date: _weekDate(currentWeekStart, weeksAgo: 0, dayOffset: 2),
      distanceKm: 20,
      paceSecPerKm: 120,
    ),
  );
  return activities;
}

List<StravaSummaryActivity> _buildConsistentIntermediateActivities(
  DateTime currentWeekStart,
) {
  final activities = <StravaSummaryActivity>[];
  for (var weeksAgo = 7; weeksAgo >= 0; weeksAgo--) {
    activities.addAll([
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 0),
        distanceKm: 8,
        paceSecPerKm: 360,
      ),
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 2),
        distanceKm: 7,
        paceSecPerKm: 365,
      ),
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 4),
        distanceKm: 6,
        paceSecPerKm: 300,
      ),
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 6),
        distanceKm: 12,
        paceSecPerKm: 340,
      ),
    ]);
  }

  return activities;
}

List<StravaSummaryActivity> _buildDetrainingActivities(
  DateTime currentWeekStart,
) {
  final activities = <StravaSummaryActivity>[];
  for (var weeksAgo = 7; weeksAgo >= 4; weeksAgo--) {
    activities.addAll([
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 0),
        distanceKm: 8,
        paceSecPerKm: 340,
      ),
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 1),
        distanceKm: 8,
        paceSecPerKm: 345,
      ),
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 2),
        distanceKm: 8,
        paceSecPerKm: 335,
      ),
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 3),
        distanceKm: 8,
        paceSecPerKm: 330,
      ),
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 4),
        distanceKm: 8,
        paceSecPerKm: 350,
      ),
    ]);
  }

  for (var weeksAgo = 3; weeksAgo >= 1; weeksAgo--) {
    activities.addAll([
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 0),
        distanceKm: 6,
        paceSecPerKm: 360,
      ),
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 2),
        distanceKm: 6,
        paceSecPerKm: 365,
      ),
      _run(
        date: _weekDate(currentWeekStart, weeksAgo: weeksAgo, dayOffset: 4),
        distanceKm: 6,
        paceSecPerKm: 370,
      ),
    ]);
  }

  activities.add(
    _run(
      date: _weekDate(currentWeekStart, weeksAgo: 0, dayOffset: 1),
      distanceKm: 6,
      paceSecPerKm: 380,
    ),
  );
  return activities;
}

List<StravaSummaryActivity> _buildSparseActivities(DateTime currentWeekStart) {
  return [
    _run(
      date: _weekDate(currentWeekStart, weeksAgo: 7, dayOffset: 2),
      distanceKm: 0.8,
      paceSecPerKm: 460,
    ),
    _run(
      date: _weekDate(currentWeekStart, weeksAgo: 3, dayOffset: 4),
      distanceKm: 0.9,
      paceSecPerKm: 450,
    ),
    _run(
      date: _weekDate(currentWeekStart, weeksAgo: 0, dayOffset: 6),
      distanceKm: 0.7,
      paceSecPerKm: 470,
    ),
  ];
}

DateTime _weekDate(
  DateTime currentWeekStart, {
  required int weeksAgo,
  required int dayOffset,
}) {
  return currentWeekStart
      .subtract(Duration(days: weeksAgo * 7))
      .add(Duration(days: dayOffset));
}

StravaSummaryActivity _run({
  required DateTime date,
  required double distanceKm,
  required int paceSecPerKm,
}) {
  final distanceMeters = distanceKm * 1000;
  final movingTimeSeconds = (distanceKm * paceSecPerKm).round();
  return StravaSummaryActivity(
    distanceMeters: distanceMeters,
    movingTimeSeconds: movingTimeSeconds,
    averageSpeedMetersPerSecond: distanceMeters / movingTimeSeconds,
    averageHeartrate: 152,
    startDate: date,
    type: 'Run',
    sportType: 'Run',
  );
}

StravaSummaryActivity _ride({
  required DateTime date,
  required double distanceKm,
  required int paceSecPerKm,
}) {
  final distanceMeters = distanceKm * 1000;
  final movingTimeSeconds = (distanceKm * paceSecPerKm).round();
  return StravaSummaryActivity(
    distanceMeters: distanceMeters,
    movingTimeSeconds: movingTimeSeconds,
    averageSpeedMetersPerSecond: distanceMeters / movingTimeSeconds,
    averageHeartrate: 135,
    startDate: date,
    type: 'Ride',
    sportType: 'Ride',
  );
}
