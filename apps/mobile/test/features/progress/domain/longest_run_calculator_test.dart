import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/progress/domain/services/longest_run_calculator.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';

void main() {
  TrainingSession buildSession({
    required DateTime date,
    required double distanceKm,
    SessionStatus status = SessionStatus.completed,
    SessionType type = SessionType.longRun,
  }) {
    return TrainingSession(
      id: 'session-${date.toIso8601String()}-${type.name}',
      date: date,
      type: type,
      status: status,
      distanceKm: distanceKm,
    );
  }

  test('returns empty stats when no completed runs', () {
    final stats = calculateLongestRunStats(sessions: []);
    expect(stats.bestDistanceKm, isNull);
    expect(stats.previousBestKm, isNull);
    expect(stats.improvementKm, isNull);
  });

  test('finds best run and previous best below it', () {
    final sessions = [
      buildSession(date: DateTime(2024, 3, 1), distanceKm: 12),
      buildSession(date: DateTime(2024, 3, 5), distanceKm: 15),
      buildSession(date: DateTime(2024, 3, 10), distanceKm: 14),
      buildSession(date: DateTime(2024, 3, 15), distanceKm: 15,
          type: SessionType.tempoRun),
      buildSession(date: DateTime(2024, 3, 20), distanceKm: 13,
          status: SessionStatus.today),
    ];

    final stats = calculateLongestRunStats(sessions: sessions);
    expect(stats.bestDistanceKm, closeTo(15, 0.001));
    expect(stats.previousBestKm, closeTo(14, 0.001));
    expect(stats.improvementKm, closeTo(1, 0.001));
  });

  test('does not report improvement when previous is equal', () {
    final sessions = [
      buildSession(date: DateTime(2024, 3, 1), distanceKm: 12),
      buildSession(date: DateTime(2024, 3, 5), distanceKm: 12),
    ];

    final stats = calculateLongestRunStats(sessions: sessions);
    expect(stats.bestDistanceKm, closeTo(12, 0.001));
    expect(stats.previousBestKm, isNull);
    expect(stats.improvementKm, isNull);
  });
}
