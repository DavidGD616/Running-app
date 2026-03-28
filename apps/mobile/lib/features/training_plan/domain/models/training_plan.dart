import 'training_session.dart';
import 'session_type.dart';

class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.name,
    required this.raceType,
    required this.totalWeeks,
    required this.currentWeekNumber,
    required this.sessions,
  });

  final String id;
  final String name;
  final String raceType;
  final int totalWeeks;
  final int currentWeekNumber;
  final List<TrainingSession> sessions;

  /// Sessions belonging to the current ISO week (Mon–Sun).
  List<TrainingSession> get currentWeekSessions {
    final now = DateTime.now();
    final weekStart = _mondayOf(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    return sessions
        .where((s) =>
            !s.date.isBefore(weekStart) && s.date.isBefore(weekEnd))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// The session scheduled for today (status == today).
  TrainingSession? get todaySession {
    for (final s in sessions) {
      if (s.status == SessionStatus.today) return s;
    }
    return null;
  }

  /// First upcoming session after today.
  TrainingSession? get nextUpcomingSession {
    final candidates = sessions
        .where((s) => s.status == SessionStatus.upcoming)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return candidates.isNotEmpty ? candidates.first : null;
  }

  static DateTime _mondayOf(DateTime date) {
    final weekday = date.weekday; // 1 = Mon, 7 = Sun
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }
}
