import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/progress_seed_data.dart';
import '../domain/models/recent_session.dart';
import '../domain/models/user_stats.dart';
import '../domain/models/weekly_volume_data.dart';
import '../domain/services/streak_weeks_calculator.dart';
import '../domain/services/weekly_volume_builder.dart';
import '../domain/services/monthly_distance_calculator.dart';
import '../domain/services/longest_run_calculator.dart';
import '../../localization/presentation/locale_provider.dart';
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
  final trainingPlan = ref.watch(trainingPlanProvider);
  final locale = ref.watch(localeProvider).value?.languageCode;
  return buildWeeklyVolumeSeries(
    sessions: trainingPlan.sessions,
    locale: locale,
  );
});

/// Total distance (km) logged in the current calendar month.
final monthlyDistanceStatsProvider =
    Provider<MonthlyDistanceStats>((ref) {
  final trainingPlan = ref.watch(trainingPlanProvider);
  return calculateMonthlyDistanceStats(
    sessions: trainingPlan.sessions,
  );
});

final monthlyTimeStatsProvider = Provider<MonthlyTimeStats>((ref) {
  final trainingPlan = ref.watch(trainingPlanProvider);
  return calculateMonthlyDurationStats(
    sessions: trainingPlan.sessions,
  );
});

final longestRunStatsProvider = Provider<LongestRunStats>((ref) {
  final trainingPlan = ref.watch(trainingPlanProvider);
  return calculateLongestRunStats(
    sessions: trainingPlan.sessions,
  );
});

/// Provides the list of recent completed sessions shown on the progress screen.
final recentSessionsProvider = Provider<List<RecentSession>>((ref) {
  return kSeedRecentSessions;
});
