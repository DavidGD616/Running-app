import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/progress/domain/services/monthly_distance_calculator.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';

void main() {
  TrainingSession buildSession({
    required DateTime date,
    double? distanceKm,
    SessionType type = SessionType.easyRun,
    SessionStatus status = SessionStatus.completed,
  }) {
    return TrainingSession(
      id: 'session-${date.toIso8601String()}-${type.name}',
      date: date,
      type: type,
      status: status,
      distanceKm: distanceKm,
    );
  }

  test('sums completed non-rest sessions in the current month only', () {
    final clock = DateTime(2024, 4, 15);
    final sessions = [
      buildSession(date: DateTime(2024, 4, 1), distanceKm: 5),
      buildSession(date: DateTime(2024, 4, 5), distanceKm: 8),
      buildSession(date: DateTime(2024, 4, 10), distanceKm: 7,
          status: SessionStatus.today),
      buildSession(date: DateTime(2024, 3, 30), distanceKm: 10),
      buildSession(date: DateTime(2024, 4, 12), distanceKm: 3,
          type: SessionType.restDay),
      buildSession(date: DateTime(2024, 4, 14), distanceKm: 6),
    ];

    final total = calculateMonthDistance(sessions: sessions, clock: clock);
    expect(total, closeTo(19, 0.001));
  });

  test('returns 0 when no matching sessions', () {
    final clock = DateTime(2024, 6, 1);
    final sessions = [
      buildSession(date: DateTime(2024, 5, 20), distanceKm: 10),
      buildSession(date: DateTime(2024, 7, 2), distanceKm: 5),
    ];

    final total = calculateMonthDistance(sessions: sessions, clock: clock);
    expect(total, 0);
  });
}
