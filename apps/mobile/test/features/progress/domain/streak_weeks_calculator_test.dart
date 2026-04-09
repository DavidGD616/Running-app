import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/progress/domain/services/streak_weeks_calculator.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';

void main() {
  final clock = DateTime(2024, 3, 31); // Sunday of the reference week.
  final baseMonday = DateTime(2024, 3, 25);

  DateTime dayOfWeek(int weeksAgo, int dayOffset) {
    final monday = baseMonday.subtract(Duration(days: weeksAgo * 7));
    return monday.add(Duration(days: dayOffset));
  }

  TrainingSession buildSession({
    required DateTime date,
    SessionType type = SessionType.easyRun,
    SessionStatus status = SessionStatus.completed,
  }) {
    return TrainingSession(
      id: 'session-${date.toIso8601String()}-${type.name}',
      date: date,
      type: type,
      status: status,
    );
  }

  test('counts consecutive active weeks ending with the latest active week', () {
    final sessions = [
      buildSession(date: dayOfWeek(0, 1)),
      buildSession(date: dayOfWeek(1, 2)),
      buildSession(date: dayOfWeek(2, 3)),
    ];

    expect(
      calculateStreakWeeks(sessions: sessions, clock: clock),
      3,
    );
  });

  test('streak stops when the latest week has only today sessions', () {
    final sessions = [
      buildSession(date: dayOfWeek(0, 2), status: SessionStatus.today),
      buildSession(date: dayOfWeek(2, 4)),
    ];

    expect(
      calculateStreakWeeks(sessions: sessions, clock: clock),
      1,
    );
  });

  test('ignores rest days, skipped, upcoming, and future sessions', () {
    final futureRun = buildSession(
      date: baseMonday.add(const Duration(days: 7)),
    );
    final restDay = buildSession(
      date: dayOfWeek(0, 0),
      type: SessionType.restDay,
    );
    final skipped = buildSession(
      date: dayOfWeek(0, 3),
      status: SessionStatus.skipped,
    );
    final completedWeek = buildSession(date: dayOfWeek(1, 1));

    final sessions = [futureRun, restDay, skipped, completedWeek];

    expect(
      calculateStreakWeeks(sessions: sessions, clock: clock),
      1,
    );
  });

  test('returns zero when there are no completed sessions', () {
    final sessions = <TrainingSession>[];

    expect(
      calculateStreakWeeks(sessions: sessions, clock: clock),
      0,
    );
  });
}
