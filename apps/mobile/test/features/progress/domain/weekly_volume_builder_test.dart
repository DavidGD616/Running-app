import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/progress/domain/services/weekly_volume_builder.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';

void main() {
  final baseMonday = DateTime(2024, 3, 25);

  TrainingSession buildSession({
    required DateTime date,
    SessionType type = SessionType.easyRun,
    SessionStatus status = SessionStatus.completed,
    double? distance,
    int? minutes,
    int? elevation,
  }) {
    return TrainingSession(
      id: 'session-${date.toIso8601String()}-${type.name}',
      date: date,
      type: type,
      status: status,
      distanceKm: distance,
      durationMinutes: minutes,
      elevationGainMeters: elevation,
    );
  }

  test('aggregates distance and time per ISO week using actual sessions', () {
    final sessions = [
      // Week -2 (oldest in sample)
      buildSession(
        date: baseMonday.subtract(const Duration(days: 14)),
        distance: 12,
        minutes: 70,
        elevation: 120,
      ),
      buildSession(
        date: baseMonday.subtract(const Duration(days: 12)),
        distance: 6,
        minutes: 35,
        elevation: 80,
      ),
      // Week -1
      buildSession(
        date: baseMonday.subtract(const Duration(days: 7)),
        distance: 8,
        minutes: 45,
        elevation: 90,
      ),
      // Current week
      buildSession(
        date: baseMonday,
        distance: 5,
        minutes: 30,
        elevation: 40,
      ),
      buildSession(
        date: baseMonday.add(const Duration(days: 2)),
        type: SessionType.longRun,
        distance: 14,
        minutes: 80,
        elevation: 160,
      ),
      // Upcoming session for later in the week should be ignored.
      buildSession(
        date: baseMonday.add(const Duration(days: 4)),
        distance: 6,
        minutes: 32,
        status: SessionStatus.upcoming,
        elevation: 70,
      ),
      // Rest day should be ignored.
      TrainingSession(
        id: 'rest',
        date: baseMonday.add(const Duration(days: 1)),
        type: SessionType.restDay,
        status: SessionStatus.completed,
      ),
    ];

    final clock = baseMonday.add(const Duration(days: 3));
    final result = buildWeeklyVolumeSeries(
      sessions: sessions,
      numberOfWeeks: 4,
      clock: clock,
    );

    expect(result, hasLength(4));
    expect(result.last.dateRange, isNull);
    expect(result[2].dateRange, 'MAR 18 - MAR 24');
    expect(result[1].distanceKm, closeTo(18, 0.01));
    expect(result[1].timeHours, 1);
    expect(result[1].timeMinutes, 45);
    expect(result[1].elevationMeters, 200);
    expect(result[2].distanceKm, closeTo(8, 0.01));
    expect(result[2].timeHours, 0);
    expect(result[2].timeMinutes, 45);
    expect(result[2].elevationMeters, 90);
    expect(result.first.distanceKm, 0);
    expect(result.first.elevationMeters, 0);
    expect(result.last.distanceKm, closeTo(19, 0.01));
    expect(result.last.timeHours, 1);
    expect(result.last.timeMinutes, 50);
    expect(result.last.elevationMeters, 200);
  });

  test('returns empty list when numberOfWeeks is zero', () {
    final result = buildWeeklyVolumeSeries(
      sessions: const [],
      numberOfWeeks: 0,
    );
    expect(result, isEmpty);
  });
}
