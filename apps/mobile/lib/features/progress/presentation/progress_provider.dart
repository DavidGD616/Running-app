import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/progress_seed_data.dart';
import '../domain/models/recent_session.dart';
import '../domain/models/user_stats.dart';
import '../domain/models/weekly_volume_data.dart';
import '../domain/services/streak_weeks_calculator.dart';
import '../../training_plan/presentation/training_plan_provider.dart';

/// Provides overall user stats (streak, totals, trends, longest run).
/// Swap the body to load from an API or local DB in a future sprint.
final userStatsProvider = Provider<UserStats>((ref) {
  final trainingPlan = ref.watch(trainingPlanProvider);
  final streakWeeks = calculateStreakWeeks(
    sessions: trainingPlan.sessions,
  );

  final seed = kSeedUserStats;
  return UserStats(
    streakWeeks: streakWeeks,
    totalDistanceKm: seed.totalDistanceKm,
    totalTimeMinutes: seed.totalTimeMinutes,
    totalRuns: seed.totalRuns,
    avgPacePerKm: seed.avgPacePerKm,
    distanceTrendPct: seed.distanceTrendPct,
    timeTrendPct: seed.timeTrendPct,
    longestRunKm: seed.longestRunKm,
    longestRunImprovementKm: seed.longestRunImprovementKm,
  );
});

/// Provides weekly volume data for the chart (most recent weeks first-last).
final weeklyVolumeProvider = Provider<List<WeeklyVolumeData>>((ref) {
  return kSeedWeeklyVolume;
});

/// Provides the list of recent completed sessions shown on the progress screen.
final recentSessionsProvider = Provider<List<RecentSession>>((ref) {
  return kSeedRecentSessions;
});
