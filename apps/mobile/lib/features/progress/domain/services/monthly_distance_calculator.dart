import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';

class MonthlyDistanceStats {
  const MonthlyDistanceStats({
    required this.currentKm,
    required this.previousKm,
    required this.trendPct,
  });

  final double currentKm;
  final double? previousKm;
  final double? trendPct;

  bool get hasComparison => previousKm != null && trendPct != null;
}

/// Calculates total completed distance for the current calendar month.
double calculateMonthDistance({
  required Iterable<TrainingSession> sessions,
  DateTime? clock,
}) {
  if (sessions.isEmpty) return 0;
  final now = clock ?? DateTime.now();
  return _distanceForMonth(sessions, now.year, now.month);
}

/// Returns the current and previous month totals plus the percentage delta.
MonthlyDistanceStats calculateMonthlyDistanceStats({
  required Iterable<TrainingSession> sessions,
  DateTime? clock,
}) {
  if (sessions.isEmpty) {
    return const MonthlyDistanceStats(
      currentKm: 0,
      previousKm: null,
      trendPct: null,
    );
  }

  final now = clock ?? DateTime.now();
  final currentKm = _distanceForMonth(sessions, now.year, now.month);
  final previousDate = DateTime(now.year, now.month - 1, 1);
  final previousKm =
      _distanceForMonth(sessions, previousDate.year, previousDate.month);

  double? trendPct;
  double? prevValue;
  if (previousKm > 0) {
    prevValue = previousKm;
    trendPct = ((currentKm - prevValue) / prevValue) * 100;
  }

  return MonthlyDistanceStats(
    currentKm: currentKm,
    previousKm: prevValue,
    trendPct: trendPct,
  );
}

double _distanceForMonth(
  Iterable<TrainingSession> sessions,
  int year,
  int month,
) {
  return sessions
      .where((s) =>
          s.date.year == year &&
          s.date.month == month &&
          s.status == SessionStatus.completed &&
          !s.type.isRest)
      .fold(0.0, (sum, s) => sum + (s.distanceKm ?? 0.0));
}
