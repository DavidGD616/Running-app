import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';

/// Counts consecutive active weeks ending with the most recent week that has
/// at least one completed (or in-progress) non-rest workout.
int calculateStreakWeeks({
  required Iterable<TrainingSession> sessions,
  DateTime? clock,
}) {
  final now = clock ?? DateTime.now();
  final activeWeekStarts = <DateTime>{};

  for (final session in sessions) {
    if (session.date.isAfter(now)) continue;
    final status = session.status;
    final isActiveStatus =
        status == SessionStatus.completed || status == SessionStatus.today;
    if (!isActiveStatus) continue;
    if (session.type.isRest) continue;

    activeWeekStarts.add(_mondayOf(session.date));
  }

  if (activeWeekStarts.isEmpty) return 0;

  final sortedWeekStarts = activeWeekStarts.toList()
    ..sort((a, b) => a.compareTo(b));

  var cursor = sortedWeekStarts.last;
  var streak = 0;

  while (activeWeekStarts.contains(cursor)) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 7));
  }

  return streak;
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
