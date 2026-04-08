import 'plan_week.dart';
import 'training_session.dart';
import 'session_type.dart';
import 'support_session.dart';

enum TrainingPlanRaceType { fiveK, tenK, halfMarathon, marathon, other }

class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.raceType,
    required this.totalWeeks,
    required this.currentWeekNumber,
    required this.sessions,
    this.supportSessions = const [],
  });

  final String id;
  final TrainingPlanRaceType raceType;
  final int totalWeeks;
  final int currentWeekNumber;
  final List<TrainingSession> sessions;
  final List<SupportSession> supportSessions;

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

  /// Support sessions belonging to the current ISO week (Mon–Sun).
  List<SupportSession> get currentWeekSupportSessions {
    final now = DateTime.now();
    final weekStart = _mondayOf(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    return supportSessions
        .where((s) => !s.date.isBefore(weekStart) && s.date.isBefore(weekEnd))
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

  /// All weeks in the plan, grouped by weekNumber and sorted ascending.
  List<PlanWeek> get allWeeks {
    final grouped = <int, List<TrainingSession>>{};
    final supportGrouped = <int, List<SupportSession>>{};
    for (final s in sessions) {
      grouped.putIfAbsent(s.weekNumber, () => []).add(s);
    }
    for (final support in supportSessions) {
      supportGrouped.putIfAbsent(support.weekNumber, () => []).add(support);
    }
    final weekNumbers = {...grouped.keys, ...supportGrouped.keys}.toList()
      ..sort();
    return weekNumbers.map((n) {
      final sorted = List<TrainingSession>.from(grouped[n] ?? const []);
      sorted.sort((a, b) => a.date.compareTo(b.date));
      final supportSorted = List<SupportSession>.from(
        supportGrouped[n] ?? const [],
      );
      supportSorted.sort((a, b) => a.date.compareTo(b.date));
      return PlanWeek(
        weekNumber: n,
        sessions: sorted,
        supportSessions: supportSorted,
      );
    }).toList();
  }

  static DateTime _mondayOf(DateTime date) {
    final weekday = date.weekday; // 1 = Mon, 7 = Sun
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }
}
