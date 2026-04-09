import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/workout_step.dart';
import 'package:running_app/features/training_plan/domain/models/workout_target.dart';

void main() {
  test('WorkoutTarget JSON round-trips canonical type and zone', () {
    const target = WorkoutTarget.pace(TargetZone.interval);

    final restored = WorkoutTarget.fromJson(target.toJson());

    expect(restored, isNotNull);
    expect(restored!.type, TargetType.pace);
    expect(restored.zone, TargetZone.interval);
  });

  test('WorkoutStep repeat round-trips nested steps and repeat metadata', () {
    const target = WorkoutTarget.pace(TargetZone.interval);
    const repeat = WorkoutStep.repeat(
      repetitions: 6,
      steps: [
        WorkoutStep.work(
          distanceMeters: 400,
          target: target,
        ),
        WorkoutStep.recovery(
          duration: Duration(seconds: 90),
          target: WorkoutTarget.effort(TargetZone.recovery),
        ),
      ],
    );

    final restored = WorkoutStep.fromJson(repeat.toJson());

    expect(restored, isNotNull);
    expect(restored!.kind, WorkoutStepKind.repeat);
    expect(restored.repetitions, 6);
    expect(restored.isRepeating, isTrue);
    expect(restored.hasNestedSteps, isTrue);
    expect(restored.steps, hasLength(2));
    expect(restored.steps.first.kind, WorkoutStepKind.work);
    expect(restored.steps.first.distanceMeters, 400);
    expect(restored.steps.first.target!.type, TargetType.pace);
    expect(restored.steps.first.target!.zone, TargetZone.interval);
    expect(restored.steps.last.kind, WorkoutStepKind.recovery);
    expect(restored.steps.last.duration, const Duration(seconds: 90));
    expect(restored.steps.last.target!.type, TargetType.effort);
    expect(restored.steps.last.target!.zone, TargetZone.recovery);
  });

  test('TrainingSession copyWith preserves structured workout fields', () {
    const target = WorkoutTarget.effort(TargetZone.tempo);
    const step = WorkoutStep.work(
      duration: Duration(minutes: 20),
      target: target,
    );
    final session = TrainingSession(
      id: 'session-1',
      date: DateTime(2026, 4, 9),
      type: SessionType.tempoRun,
      status: SessionStatus.today,
      workoutTarget: target,
      workoutSteps: const [step],
    );

    final copied = session.copyWith(durationMinutes: 42);

    expect(session.hasStructuredWorkout, isTrue);
    expect(copied.hasStructuredWorkout, isTrue);
    expect(copied.workoutTarget, target);
    expect(copied.workoutSteps, hasLength(1));
    expect(copied.durationMinutes, 42);
  });
}
