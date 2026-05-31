import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/strava_athlete.dart';

class StravaAthleteDataBundle {
  const StravaAthleteDataBundle({
    required this.athlete,
    required this.stats,
    required this.activities,
  });

  final StravaAthlete athlete;
  final StravaAthleteStats stats;
  final List<StravaSummaryActivity> activities;
}

abstract interface class StravaService {
  Future<StravaAthlete> fetchAthlete();

  Future<StravaAthleteStats> fetchAthleteStats();

  Future<List<StravaSummaryActivity>> fetchSummaryActivities();
}

class MockStravaService implements StravaService {
  const MockStravaService();

  @override
  Future<StravaAthlete> fetchAthlete() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const StravaAthlete(
      sex: StravaAthleteSex.female,
      weightKg: 62,
      heartRateZones: StravaHeartRateZones(
        zone1: StravaHeartRateZone(minBpm: null, maxBpm: 136),
        zone2: StravaHeartRateZone(minBpm: 137, maxBpm: 149),
        zone3: StravaHeartRateZone(minBpm: 150, maxBpm: 162),
        zone4: StravaHeartRateZone(minBpm: 163, maxBpm: 174),
        zone5: StravaHeartRateZone(minBpm: 175, maxBpm: 192),
      ),
    );
  }

  @override
  Future<StravaAthleteStats> fetchAthleteStats() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const StravaAthleteStats(
      recentRunTotals: StravaRunTotals(
        distanceMeters: 34_200,
        movingTimeSeconds: 12_420,
        activityCount: 3,
        elevationGainMeters: 260,
      ),
      ytdRunTotals: StravaRunTotals(
        distanceMeters: 1_160_000,
        movingTimeSeconds: 435_000,
        activityCount: 104,
        elevationGainMeters: 8_600,
      ),
      allRunTotals: StravaRunTotals(
        distanceMeters: 3_980_000,
        movingTimeSeconds: 1_520_000,
        activityCount: 326,
        elevationGainMeters: 24_400,
      ),
    );
  }

  @override
  Future<List<StravaSummaryActivity>> fetchSummaryActivities() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _buildMockActivities(DateTime.now().toUtc());
  }
}

final stravaServiceProvider = Provider<StravaService>(
  (ref) => const MockStravaService(),
);

List<StravaSummaryActivity> _buildMockActivities(DateTime nowUtc) {
  final currentWeekStart = _mondayOf(nowUtc);
  final activities = <StravaSummaryActivity>[];

  for (var weeksAgo = 7; weeksAgo >= 0; weeksAgo--) {
    activities.addAll([
      _runActivity(
        date: currentWeekStart
            .subtract(Duration(days: weeksAgo * 7))
            .add(const Duration(days: 1)),
        distanceKm: 8,
        paceSecPerKm: 355,
      ),
      _runActivity(
        date: currentWeekStart
            .subtract(Duration(days: weeksAgo * 7))
            .add(const Duration(days: 3)),
        distanceKm: 6,
        paceSecPerKm: 365,
      ),
      _runActivity(
        date: currentWeekStart
            .subtract(Duration(days: weeksAgo * 7))
            .add(const Duration(days: 6)),
        distanceKm: 12,
        paceSecPerKm: 345,
      ),
    ]);
  }

  return activities;
}

StravaSummaryActivity _runActivity({
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
    averageHeartrate: 154,
    startDate: date,
    type: 'Run',
    sportType: 'Run',
  );
}

DateTime _mondayOf(DateTime date) {
  final normalized = DateTime.utc(date.year, date.month, date.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}
