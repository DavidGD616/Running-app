import '../domain/models/session_type.dart';
import '../domain/models/training_session.dart';
import '../domain/models/training_plan.dart';

/// Returns a [TrainingPlan] seeded with mock data for the current ISO week.
/// Dates are computed from [DateTime.now()] so the week always stays current.
TrainingPlan buildSeedTrainingPlan() {
  final now = DateTime.now();
  final monday = _mondayOf(now);

  DateTime day(int offset) =>
      DateTime(monday.year, monday.month, monday.day + offset);

  SessionStatus statusFor(DateTime date) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d.isAtSameMomentAs(today)) return SessionStatus.today;
    if (d.isBefore(today)) return SessionStatus.completed;
    return SessionStatus.upcoming;
  }

  // Fixed override: Wed is always shown as skipped to match design mock
  SessionStatus statusForWed(DateTime date) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d.isBefore(today) || d.isAtSameMomentAs(today)) {
      return SessionStatus.skipped;
    }
    return SessionStatus.upcoming;
  }

  final sessions = [
    TrainingSession(
      id: 'seed-mon',
      date: day(0),
      type: SessionType.rest,
      status: statusFor(day(0)),
    ),
    TrainingSession(
      id: 'seed-tue',
      date: day(1),
      type: SessionType.easyRun,
      status: statusFor(day(1)),
      distanceKm: 5.0,
      durationMinutes: 30,
      effortLabel: 'Easy effort',
    ),
    TrainingSession(
      id: 'seed-wed',
      date: day(2),
      type: SessionType.easyRun,
      status: statusForWed(day(2)),
      distanceKm: 4.0,
      durationMinutes: 25,
      effortLabel: 'Easy effort',
    ),
    TrainingSession(
      id: 'seed-thu',
      date: day(3),
      type: SessionType.intervals,
      status: statusFor(day(3)),
      distanceKm: 6.0,
      durationMinutes: 45,
      description: '4×800m @ 5K pace. 90s recovery jog.',
      effortLabel: 'Hard effort',
    ),
    TrainingSession(
      id: 'seed-fri',
      date: day(4),
      type: SessionType.rest,
      status: statusFor(day(4)),
    ),
    TrainingSession(
      id: 'seed-sat',
      date: day(5),
      type: SessionType.longRun,
      status: statusFor(day(5)),
      distanceKm: 12.0,
      durationMinutes: 75,
      effortLabel: 'Easy effort',
    ),
    TrainingSession(
      id: 'seed-sun',
      date: day(6),
      type: SessionType.recoveryRun,
      status: statusFor(day(6)),
      distanceKm: 3.0,
      durationMinutes: 20,
      effortLabel: 'Very easy effort',
    ),
  ];

  return TrainingPlan(
    id: 'seed-plan',
    name: 'Half Marathon Plan',
    raceType: 'Half Marathon',
    totalWeeks: 12,
    currentWeekNumber: 4,
    sessions: sessions,
  );
}

DateTime _mondayOf(DateTime date) {
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}
