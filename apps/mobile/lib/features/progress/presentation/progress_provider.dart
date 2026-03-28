import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/progress_seed_data.dart';
import '../domain/models/user_stats.dart';
import '../domain/models/weekly_volume_data.dart';
import '../domain/models/recent_session.dart';

/// Provides overall user stats (streak, totals, trends, longest run).
/// Swap the body to load from an API or local DB in a future sprint.
final userStatsProvider = Provider<UserStats>((ref) {
  return kSeedUserStats;
});

/// Provides weekly volume data for the chart (most recent weeks first-last).
final weeklyVolumeProvider = Provider<List<WeeklyVolumeData>>((ref) {
  return kSeedWeeklyVolume;
});

/// Provides the list of recent completed sessions shown on the progress screen.
final recentSessionsProvider = Provider<List<RecentSession>>((ref) {
  return kSeedRecentSessions;
});
