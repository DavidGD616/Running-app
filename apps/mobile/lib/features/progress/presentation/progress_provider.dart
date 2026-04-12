import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activity/activity.dart';
import '../../localization/presentation/locale_provider.dart';
import '../../training_plan/domain/models/training_session.dart';
import '../../training_plan/presentation/training_plan_provider.dart';
import '../domain/models/recent_session.dart';
import '../domain/models/training_history_point.dart';
import '../domain/models/user_stats.dart';
import '../domain/models/weekly_volume_data.dart';
import '../domain/services/activity_progress_merger.dart';
import '../domain/services/longest_run_calculator.dart';
import '../domain/services/monthly_distance_calculator.dart';
import '../domain/services/streak_weeks_calculator.dart';
import '../domain/services/training_history_builder.dart';
import '../domain/services/weekly_volume_builder.dart';

/// Provides the derived progress stats still used directly by the screen.
final userStatsProvider = Provider<UserStats>((ref) {
  final completedSessions = ref.watch(completedSessionsProvider);
  final streakWeeks = calculateStreakWeeks(sessions: completedSessions);

  return UserStats(
    streakWeeks: streakWeeks,
    totalRuns: completedSessions.length,
  );
});

final completedSessionsProvider = Provider<List<TrainingSession>>((ref) {
  final trainingPlan = ref.watch(trainingPlanProvider).value;
  final activities = ref.watch(completedActivitiesProvider);
  return buildEffectiveCompletedRunSessions(
    plannedSessions: trainingPlan?.sessions ?? const [],
    activities: activities,
  );
});

/// Provides weekly volume data for the chart (most recent weeks first-last).
final weeklyVolumeProvider = Provider<List<WeeklyVolumeData>>((ref) {
  final completedSessions = ref.watch(completedSessionsProvider);
  final locale = ref.watch(localeProvider).value?.languageCode;
  return buildWeeklyVolumeSeries(sessions: completedSessions, locale: locale);
});

final trainingHistorySeriesProvider =
    Provider.family<List<TrainingHistoryPoint>, TrainingHistoryRange>((
      ref,
      range,
    ) {
      final completedSessions = ref.watch(completedSessionsProvider);
      final locale = ref.watch(localeProvider).value?.languageCode;
      return buildTrainingHistorySeries(
        sessions: completedSessions,
        range: range,
        locale: locale,
      );
    });

/// Total distance (km) logged in the current calendar month.
final monthlyDistanceStatsProvider = Provider<MonthlyDistanceStats>((ref) {
  final completedSessions = ref.watch(completedSessionsProvider);
  return calculateMonthlyDistanceStats(sessions: completedSessions);
});

final monthlyTimeStatsProvider = Provider<MonthlyTimeStats>((ref) {
  final completedSessions = ref.watch(completedSessionsProvider);
  return calculateMonthlyDurationStats(sessions: completedSessions);
});

final longestRunStatsProvider = Provider<LongestRunStats>((ref) {
  final completedSessions = ref.watch(completedSessionsProvider);
  return calculateLongestRunStats(sessions: completedSessions);
});

/// Provides the list of recent completed sessions shown on the progress screen.
final recentSessionsProvider = Provider<List<RecentSession>>((ref) {
  final recentSessions = ref.watch(completedSessionsProvider);

  return recentSessions
      .take(3)
      .map(
        (session) => RecentSession(
          id: session.id,
          date: session.date,
          distanceKm: session.distanceKm ?? 0,
          durationMinutes: session.durationMinutes ?? 0,
          type: session.type,
        ),
      )
      .toList(growable: false);
});
