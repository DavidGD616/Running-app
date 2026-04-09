import 'package:intl/intl.dart';

import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';
import '../models/weekly_volume_data.dart';

/// Builds the weekly volume chart series from real training plan sessions.
List<WeeklyVolumeData> buildWeeklyVolumeSeries({
  required Iterable<TrainingSession> sessions,
  int numberOfWeeks = 6,
  DateTime? clock,
  String? locale,
}) {
  if (numberOfWeeks <= 0) return const [];

  final now = clock ?? DateTime.now();
  final currentWeekStart = _mondayOf(now);
  final formatter = DateFormat('MMM dd', locale);
  final completedRuns = sessions
      .where(
        (s) => s.countsAsRun && s.status == SessionStatus.completed,
      )
      .toList(growable: false);

  WeeklyVolumeData buildWeek({
    required DateTime weekStart,
    required bool isCurrentWeek,
  }) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final bucket = completedRuns
        .where(
          (s) =>
              !s.date.isBefore(weekStart) &&
              s.date.isBefore(weekEnd),
        )
        .toList(growable: false);

    final totalKm =
        bucket.fold<double>(0, (sum, s) => sum + (s.distanceKm ?? 0.0));
    final totalMinutes =
        bucket.fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));

    final totalElevation =
        bucket.fold<int>(0, (sum, s) => sum + (s.elevationGainMeters ?? 0));

    final label = isCurrentWeek
        ? null
        : '${formatter.format(weekStart).toUpperCase()} - '
            '${formatter.format(weekEnd.subtract(const Duration(days: 1))).toUpperCase()}';

    return WeeklyVolumeData(
      distanceKm: totalKm,
      timeHours: totalMinutes ~/ 60,
      timeMinutes: totalMinutes % 60,
      elevationMeters: totalElevation,
      dateRange: label,
    );
  }

  final weeks = <WeeklyVolumeData>[];
  for (int i = numberOfWeeks - 1; i >= 0; i--) {
    final weekStart = currentWeekStart.subtract(Duration(days: i * 7));
    weeks.add(
      buildWeek(
        weekStart: weekStart,
        isCurrentWeek: i == 0,
      ),
    );
  }
  return weeks;
}

DateTime _mondayOf(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final weekday = normalized.weekday; // 1 = Mon, 7 = Sun
  return DateTime(
    normalized.year,
    normalized.month,
    normalized.day - (weekday - 1),
  );
}
