import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';
import 'package:running_app/features/strava/domain/models/strava_athlete.dart';
import 'package:running_app/features/strava/domain/strava_coaching_profile_builder.dart';

final now = DateTime.utc(2026, 6, 7);

void main() {
  test('builds a high-confidence profile for strong recent running', () {
    final profile = buildStravaCoachingProfile(
      _strongRecentRuns(),
      now: now,
      syncedAt: now,
    );

    expect(profile.dataConfidence, StravaDataConfidence.high);
    expect(profile.trainingBase, isNotEmpty);
    expect(profile.endurance, isNotEmpty);
    expect(profile.speedMarkers, isNotEmpty);
    expect(profile.raceTargets, isNotEmpty);
    expect(profile.paceZones.recovery.paceMinSecPerKm, isNotNull);
    expect(profile.paceZones.strides.paceMinSecPerKm, isNotNull);
    expect(profile.terrain, isNot(StravaTerrainProfile.notSure));
    expect(
      profile.provenance.runActivityCount,
      _strongRecentRuns().where((it) => it.isRun).length,
    );
    expect(
      profile.provenance.activityCount,
      _strongRecentRuns().where((it) => it.isRun).length,
    );
    expect(profile.raceTargets.first.stretchTime, isNull);
    expect(profile.recoveryGuardrails.length, lessThanOrEqualTo(3));
    expect(profile.recoveryGuardrails, hasLength(greaterThanOrEqualTo(0)));
    expect(profile.planFocus.category, isNot('focus_data_collection'));
    expect(
      profile.paceZones.longRun.paceMinSecPerKm,
      greaterThan(profile.paceZones.threshold.paceMaxSecPerKm!),
    );
    expect(
      profile.paceZones.longRun.paceMinSecPerKm,
      greaterThan(profile.paceZones.easy.paceMaxSecPerKm!),
    );
    expect(
      profile.paceZones.longRun.paceMinSecPerKm,
      greaterThan(profile.paceZones.racePace.paceMaxSecPerKm!),
    );
  });

  test('120-day-old effort does not inflate last12Weeks provenance counts', () {
    final baselineProfile = buildStravaCoachingProfile(
      _strongRecentRuns(),
      now: now,
      syncedAt: now,
    );
    final withOlderEffortProfile = buildStravaCoachingProfile(
      [..._strongRecentRuns(), _olderEffort(now: now)],
      now: now,
      syncedAt: now,
    );

    expect(
      withOlderEffortProfile.provenance.activityCount,
      baselineProfile.provenance.activityCount,
    );
    expect(
      withOlderEffortProfile.provenance.runActivityCount,
      baselineProfile.provenance.runActivityCount,
    );
  });

  test(
    'older efforts can add stretch confidence without changing safety zones',
    () {
      final baseRuns = _strongRecentRuns();
      final baseProfile = buildStravaCoachingProfile(
        baseRuns,
        now: now,
        syncedAt: now,
      );
      final withOlderEffortProfile = buildStravaCoachingProfile(
        [...baseRuns, _olderEffort(now: now)],
        now: now,
        syncedAt: now,
      );

      expect(baseProfile.dataConfidence, StravaDataConfidence.high);
      expect(withOlderEffortProfile.dataConfidence, StravaDataConfidence.high);
      expect(withOlderEffortProfile.raceTargets.first.stretchTime, isNotNull);
      expect(baseProfile.raceTargets, isNotEmpty);
      expect(
        baseProfile.paceZones.toJson(),
        withOlderEffortProfile.paceZones.toJson(),
      );
    },
  );

  test(
    'returns medium confidence when pace is usable but only lower recent volume',
    () {
      final profile = buildStravaCoachingProfile(
        [..._buildWeakRecentRuns(), _olderEffort(now: now)],
        now: now,
        syncedAt: now,
      );

      expect(profile.dataConfidence, StravaDataConfidence.medium);
      expect(profile.trainingBase, isNotEmpty);
      expect(profile.raceTargets, isNotEmpty);
      expect(profile.paceZones.recovery.paceMinSecPerKm, isNotNull);
    },
  );

  test('non-runs are ignored across counts, pace, terrain, and focus', () {
    final nonRuns = [
      _runLike(
        activityType: 'Ride',
        date: now.subtract(const Duration(days: 2)),
        distanceKm: 80,
        paceSecPerKm: 330,
      ),
      _runLike(
        activityType: 'Bike',
        date: now.subtract(const Duration(days: 10)),
        distanceKm: 60,
        paceSecPerKm: 380,
      ),
      ..._strongRecentRuns(),
    ];

    final baseline = buildStravaCoachingProfile(
      _strongRecentRuns(),
      now: now,
      syncedAt: now,
    );
    final withNonRuns = buildStravaCoachingProfile(
      nonRuns,
      now: now,
      syncedAt: now,
    );

    expect(withNonRuns.trainingBase, isNotEmpty);
    expect(withNonRuns.trainingBase.length, baseline.trainingBase.length);
    expect(
      withNonRuns.trainingBase.first.value,
      baseline.trainingBase.first.value,
    );
    expect(
      withNonRuns.endurance.map((point) => point.toJson()),
      equals(baseline.endurance.map((point) => point.toJson())),
    );
    expect(
      withNonRuns.speedMarkers.map((point) => point.toJson()),
      equals(baseline.speedMarkers.map((point) => point.toJson())),
    );
    expect(withNonRuns.paceZones.toJson(), equals(baseline.paceZones.toJson()));
    expect(withNonRuns.terrain, equals(baseline.terrain));
    expect(
      withNonRuns.raceTargets.map((target) => target.toJson()),
      equals(baseline.raceTargets.map((target) => target.toJson())),
    );
    expect(
      withNonRuns.recoveryGuardrails.map((guardrail) => guardrail.category),
      equals(
        baseline.recoveryGuardrails.map((guardrail) => guardrail.category),
      ),
    );
    expect(withNonRuns.planFocus.toJson(), equals(baseline.planFocus.toJson()));
    expect(
      withNonRuns.provenance.activityCount,
      baseline.provenance.activityCount,
    );
    expect(
      withNonRuns.provenance.runActivityCount,
      baseline.provenance.runActivityCount,
    );
    expect(withNonRuns.dataConfidence, baseline.dataConfidence);
  });

  test(
    'non-runs can change total received items but not run-derived outputs',
    () {
      final nonRunsOnly = [
        _runLike(
          activityType: 'Swim',
          date: now.subtract(const Duration(days: 2)),
          distanceKm: 2,
          paceSecPerKm: 180,
        ),
        _runLike(
          activityType: 'Ride',
          date: now.subtract(const Duration(days: 4)),
          distanceKm: 24,
          paceSecPerKm: 320,
        ),
      ];
      final withNonRuns = buildStravaCoachingProfile(
        [..._buildWeakRecentRuns(), ...nonRunsOnly],
        now: now,
        syncedAt: now,
      );
      final weakBaseline = buildStravaCoachingProfile(
        _buildWeakRecentRuns(),
        now: now,
        syncedAt: now,
      );

      expect(
        withNonRuns.trainingBase.map((point) => point.toJson()),
        equals(weakBaseline.trainingBase.map((point) => point.toJson())),
      );
      expect(
        withNonRuns.endurance.map((point) => point.toJson()),
        equals(weakBaseline.endurance.map((point) => point.toJson())),
      );
      expect(
        withNonRuns.speedMarkers.map((point) => point.toJson()),
        equals(weakBaseline.speedMarkers.map((point) => point.toJson())),
      );
      expect(
        withNonRuns.raceTargets.map((target) => target.toJson()),
        equals(weakBaseline.raceTargets.map((target) => target.toJson())),
      );
      expect(
        withNonRuns.paceZones.toJson(),
        equals(weakBaseline.paceZones.toJson()),
      );
      expect(withNonRuns.terrain, equals(weakBaseline.terrain));
      expect(
        withNonRuns.recoveryGuardrails.map((guardrail) => guardrail.toJson()),
        equals(
          weakBaseline.recoveryGuardrails.map(
            (guardrail) => guardrail.toJson(),
          ),
        ),
      );
    },
  );

  test('returns limited profile for no useful data', () {
    final limitedProfile = buildStravaCoachingProfile(
      [
        _runLike(
          date: now.subtract(const Duration(days: 3)),
          distanceKm: 1.2,
          paceSecPerKm: 520,
          activityType: 'Run',
        ),
      ],
      now: now,
      syncedAt: now,
    );

    expect(limitedProfile.dataConfidence, StravaDataConfidence.limited);
    expect(limitedProfile.trainingBase, isEmpty);
    expect(limitedProfile.endurance, isEmpty);
    expect(limitedProfile.speedMarkers, isEmpty);
    expect(limitedProfile.paceZones.recovery.paceMinSecPerKm, isNull);
    expect(limitedProfile.raceTargets, isEmpty);
    expect(limitedProfile.planFocus.category, 'focus_data_collection');
    expect(limitedProfile.recoveryGuardrails, isNotEmpty);
  });

  test('caps recovery guardrails to a maximum of three', () {
    final profile = buildStravaCoachingProfile(
      [
        _runLike(
          date: now.subtract(const Duration(days: 2)),
          distanceKm: 14,
          paceSecPerKm: 380,
          activityType: 'Run',
          totalElevationGainMeters: 0,
        ),
        _runLike(
          date: now.subtract(const Duration(days: 40)),
          distanceKm: 14,
          paceSecPerKm: 410,
          activityType: 'Run',
          totalElevationGainMeters: 0,
        ),
        _runLike(
          date: now.subtract(const Duration(days: 90)),
          distanceKm: 14,
          paceSecPerKm: 420,
          activityType: 'Run',
          totalElevationGainMeters: 0,
        ),
      ],
      now: now,
      syncedAt: now,
    );

    expect(profile.recoveryGuardrails, isNotEmpty);
    expect(profile.recoveryGuardrails.length, lessThanOrEqualTo(3));
    for (
      var index = 0;
      index < profile.recoveryGuardrails.length - 1;
      index++
    ) {
      expect(
        profile.recoveryGuardrails[index].priority,
        lessThanOrEqualTo(profile.recoveryGuardrails[index + 1].priority),
      );
    }
    expect(
      profile.recoveryGuardrails.every((guardrail) => guardrail.priority <= 3),
      isTrue,
    );
  });

  test('buckets terrain from recent elevation per km', () {
    final flatProfile = buildStravaCoachingProfile(
      [
        _runLike(
          date: now.subtract(const Duration(days: 2)),
          distanceKm: 10,
          paceSecPerKm: 360,
          totalElevationGainMeters: 12,
        ),
        _runLike(
          date: now.subtract(const Duration(days: 8)),
          distanceKm: 8,
          paceSecPerKm: 360,
          totalElevationGainMeters: 10,
        ),
      ],
      now: now,
      syncedAt: now,
    );
    final hillyProfile = buildStravaCoachingProfile(
      [
        _runLike(
          date: now.subtract(const Duration(days: 4)),
          distanceKm: 8,
          paceSecPerKm: 360,
          totalElevationGainMeters: 260,
        ),
        _runLike(
          date: now.subtract(const Duration(days: 10)),
          distanceKm: 8,
          paceSecPerKm: 360,
          totalElevationGainMeters: 260,
        ),
      ],
      now: now,
      syncedAt: now,
    );

    expect(flatProfile.terrain, StravaTerrainProfile.flat);
    expect(hillyProfile.terrain, StravaTerrainProfile.hilly);
  });

  test('terrain includes rolling bucket when elevation gain is moderate', () {
    final rollingProfile = buildStravaCoachingProfile(
      [
        _runLike(
          date: now.subtract(const Duration(days: 3)),
          distanceKm: 10,
          paceSecPerKm: 360,
          totalElevationGainMeters: 90,
        ),
        _runLike(
          date: now.subtract(const Duration(days: 10)),
          distanceKm: 10,
          paceSecPerKm: 360,
          totalElevationGainMeters: 95,
        ),
      ],
      now: now,
      syncedAt: now,
    );

    expect(rollingProfile.terrain, StravaTerrainProfile.rolling);
  });

  test(
    'efforts older than six months no longer affect stretch, confidence, or safety',
    () {
      final withRecentOldEffort = buildStravaCoachingProfile(
        [..._strongRecentRuns(), _olderEffort(now: now, daysAgo: 120)],
        now: now,
        syncedAt: now,
      );
      final withVeryOldEffort = buildStravaCoachingProfile(
        [..._strongRecentRuns(), _olderEffort(now: now, daysAgo: 220)],
        now: now,
        syncedAt: now,
      );

      expect(
        withVeryOldEffort.dataConfidence,
        withRecentOldEffort.dataConfidence,
      );
      expect(
        withRecentOldEffort.dataConfidence,
        isNot(StravaDataConfidence.limited),
      );
      expect(
        withRecentOldEffort.paceZones.toJson(),
        withVeryOldEffort.paceZones.toJson(),
      );
      expect(
        withVeryOldEffort.recoveryGuardrails.map(
          (guardrail) => guardrail.toJson(),
        ),
        equals(
          withRecentOldEffort.recoveryGuardrails.map(
            (guardrail) => guardrail.toJson(),
          ),
        ),
      );
      expect(withRecentOldEffort.raceTargets.first.stretchTime, isNotNull);
      expect(withVeryOldEffort.raceTargets.first.stretchTime, isNull);
    },
  );

  test('ignores future-dated activities', () {
    final profile = buildStravaCoachingProfile(
      [
        ..._strongRecentRuns(),
        _runLike(
          date: now.add(const Duration(days: 3)),
          distanceKm: 10,
          paceSecPerKm: 330,
        ),
      ],
      now: now,
      syncedAt: now,
    );
    final expected = buildStravaCoachingProfile(
      _strongRecentRuns(),
      now: now,
      syncedAt: now,
    );

    expect(profile.dataConfidence, expected.dataConfidence);
    expect(profile.provenance.activityCount, expected.provenance.activityCount);
  });

  test('same-day future timestamps are ignored', () {
    final profile = buildStravaCoachingProfile(
      [
        ..._strongRecentRuns(),
        _runLike(
          date: now.add(const Duration(hours: 1)),
          distanceKm: 10,
          paceSecPerKm: 330,
        ),
      ],
      now: now,
      syncedAt: now,
    );

    final baseline = buildStravaCoachingProfile(
      _strongRecentRuns(),
      now: now,
      syncedAt: now,
    );

    expect(profile.provenance.activityCount, baseline.provenance.activityCount);
    expect(profile.terrain, equals(baseline.terrain));
  });

  test('missing optional Task 4 summary fields do not throw', () {
    final stats = StravaAthleteStats(
      recentRunTotals: const StravaRunTotals(
        distanceMeters: 1000,
        movingTimeSeconds: 300,
        activityCount: 1,
        elevationGainMeters: 10,
      ),
      ytdRunTotals: const StravaRunTotals(
        distanceMeters: 1000,
        movingTimeSeconds: 300,
        activityCount: 1,
        elevationGainMeters: 10,
      ),
      allRunTotals: const StravaRunTotals(
        distanceMeters: 1_000,
        movingTimeSeconds: 300,
        activityCount: 1,
        elevationGainMeters: 10,
      ),
    );
    final athlete = StravaAthlete(
      weightKg: 70.0,
      heartRateZones: null,
      sex: null,
    );

    expect(
      () => buildStravaCoachingProfile(
        [
          StravaSummaryActivity(
            distanceMeters: 10_000,
            movingTimeSeconds: 3_600,
            averageSpeedMetersPerSecond: 2.777_777_777_777,
            startDate: now.subtract(const Duration(days: 1)),
            type: 'Run',
            sportType: 'Run',
          ),
        ],
        stats: stats,
        athlete: athlete,
      ),
      returnsNormally,
    );
  });
}

List<StravaSummaryActivity> _strongRecentRuns() {
  final runs = <StravaSummaryActivity>[];

  for (var weekOffset = 0; weekOffset < 8; weekOffset++) {
    final weekStart = now.subtract(Duration(days: (weekOffset + 1) * 7));
    runs
      ..add(
        _runLike(
          date: weekStart.add(const Duration(days: 1)),
          distanceKm: 10,
          paceSecPerKm: 360,
          totalElevationGainMeters: 12,
        ),
      )
      ..add(
        _runLike(
          date: weekStart.add(const Duration(days: 3)),
          distanceKm: 8,
          paceSecPerKm: 350,
          totalElevationGainMeters: 8,
        ),
      )
      ..add(
        _runLike(
          date: weekStart.add(const Duration(days: 5)),
          distanceKm: 12,
          paceSecPerKm: 335,
          totalElevationGainMeters: 14,
        ),
      );
  }

  return runs;
}

List<StravaSummaryActivity> _buildWeakRecentRuns() {
  final runs = <StravaSummaryActivity>[];
  for (var weekOffset = 0; weekOffset < 8; weekOffset++) {
    runs.add(
      _runLike(
        date: now.subtract(Duration(days: weekOffset * 7 + 2)),
        distanceKm: 1.0,
        paceSecPerKm: 420,
        totalElevationGainMeters: 5,
      ),
    );
  }
  return runs;
}

StravaSummaryActivity _olderEffort({required DateTime now, int daysAgo = 120}) {
  return _runLike(
    date: now.subtract(Duration(days: daysAgo)),
    distanceKm: 15,
    paceSecPerKm: 280,
    totalElevationGainMeters: 45,
  );
}

StravaSummaryActivity _runLike({
  required DateTime date,
  required double distanceKm,
  required int paceSecPerKm,
  String activityType = 'Run',
  double? totalElevationGainMeters,
}) {
  final distanceMeters = distanceKm * 1000;
  return StravaSummaryActivity(
    distanceMeters: distanceMeters,
    movingTimeSeconds: (distanceKm * paceSecPerKm).round(),
    averageSpeedMetersPerSecond: distanceMeters / (distanceKm * paceSecPerKm),
    startDate: date,
    type: activityType,
    sportType: activityType,
    totalElevationGainMeters: totalElevationGainMeters,
  );
}
