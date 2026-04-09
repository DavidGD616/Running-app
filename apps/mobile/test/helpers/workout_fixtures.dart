import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/workout_step.dart';
import 'package:running_app/features/training_plan/domain/models/workout_target.dart';

TrainingSession buildStructuredIntervalSession({
  String id = 'w4-thu',
  DateTime? date,
  SessionStatus status = SessionStatus.completed,
  int weekNumber = 4,
}) {
  final sessionDate = date ?? DateTime(2026, 4, 9, 7, 30);

  return TrainingSession(
    id: id,
    date: sessionDate,
    type: SessionType.intervals,
    status: status,
    weekNumber: weekNumber,
    distanceKm: 6.0,
    durationMinutes: 45,
    effort: TrainingSessionEffort.hard,
    workoutTarget: const WorkoutTarget.pace(TargetZone.interval),
    workoutSteps: [
      WorkoutStep.warmUp(
        duration: const Duration(minutes: 10),
        target: const WorkoutTarget.effort(TargetZone.easy),
      ),
      WorkoutStep.repeat(
        repetitions: 6,
        steps: [
          WorkoutStep.work(
            distanceMeters: 400,
            target: const WorkoutTarget.pace(TargetZone.interval),
          ),
          WorkoutStep.recovery(
            duration: const Duration(seconds: 90),
            target: const WorkoutTarget.effort(TargetZone.recovery),
          ),
        ],
      ),
      WorkoutStep.coolDown(
        duration: const Duration(minutes: 10),
        target: const WorkoutTarget.effort(TargetZone.recovery),
      ),
    ],
    intervalReps: 6,
    intervalRepDistanceMeters: 400,
    intervalRecoverySeconds: 90,
    warmUpMinutes: 10,
    coolDownMinutes: 10,
  );
}

TrainingSession buildLegacyTempoSession({
  String id = 'w4-fri',
  DateTime? date,
  SessionStatus status = SessionStatus.completed,
  int weekNumber = 4,
}) {
  final sessionDate = date ?? DateTime(2026, 4, 10, 7, 30);

  return TrainingSession(
    id: id,
    date: sessionDate,
    type: SessionType.tempoRun,
    status: status,
    weekNumber: weekNumber,
    distanceKm: 7.0,
    durationMinutes: 40,
    effort: TrainingSessionEffort.moderate,
    warmUpMinutes: 10,
    coolDownMinutes: 10,
  );
}
