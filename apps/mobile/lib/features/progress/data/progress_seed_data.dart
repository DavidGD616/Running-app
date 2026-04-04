import '../domain/models/user_stats.dart';

const kSeedUserStats = UserStats(
  streakWeeks: 5,
  totalDistanceKm: 65.2,
  totalTimeMinutes: 375, // 6h 15m
  totalRuns: 10,
  avgPacePerKm: '6:15',
  distanceTrendPct: 14.0,
  timeTrendPct: 5.0,
  longestRunKm: 12.0,
  longestRunImprovementKm: 4.0,
);
