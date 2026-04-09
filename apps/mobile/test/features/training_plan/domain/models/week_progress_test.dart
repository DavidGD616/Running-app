import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/week_progress.dart';

void main() {
  test(
    'WeekProgress.fromSessions excludes support sessions from run totals',
    () {
      final runSession = TrainingSession(
        id: 'run_w4-tue',
        date: DateTime(2026, 4, 7),
        type: SessionType.easyRun,
        status: SessionStatus.completed,
        distanceKm: 8.0,
        durationMinutes: 42,
      );
      final supportSession = TrainingSession(
        id: 'support_w4-wed',
        date: DateTime(2026, 4, 8),
        type: SessionType.crossTraining,
        status: SessionStatus.completed,
        supplementalType: SupplementalSessionType.strength,
        distanceKm: 99.0,
        durationMinutes: 999,
      );

      final progress = WeekProgress.fromSessions([runSession, supportSession]);

      expect(progress.completedSessions, 1);
      expect(progress.totalSessions, 1);
      expect(progress.completedVolumeKm, closeTo(8.0, 0.001));
      expect(progress.totalVolumeKm, closeTo(8.0, 0.001));
      expect(progress.totalDurationMinutes, 42);
    },
  );
}
