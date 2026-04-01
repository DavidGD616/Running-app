import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';

/// Calculates total completed distance for the current calendar month.
double calculateMonthDistance({
  required Iterable<TrainingSession> sessions,
  DateTime? clock,
}) {
  if (sessions.isEmpty) return 0;

  final now = clock ?? DateTime.now();
  final targetYear = now.year;
  final targetMonth = now.month;

  return sessions
      .where((s) =>
          s.date.year == targetYear &&
          s.date.month == targetMonth &&
          s.status == SessionStatus.completed &&
          !s.type.isRest)
      .fold(0.0, (sum, s) => sum + (s.distanceKm ?? 0.0));
}
