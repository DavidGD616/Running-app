import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/training_plan/data/training_plan_seed_data.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/workout_step.dart';
import 'package:running_app/features/training_plan/domain/models/workout_target.dart';

void main() {
  test('buildSeedTrainingPlan includes a structured interval session', () {
    final plan = buildSeedTrainingPlan();

    final structuredIntervals = plan.sessions.where(
      (session) =>
          session.type == SessionType.intervals &&
          session.hasStructuredWorkout,
    );

    expect(structuredIntervals, isNotEmpty);

    final session = structuredIntervals.first;
    expect(session.workoutTarget, isNotNull);
    expect(session.workoutTarget!.type, TargetType.pace);
    expect(session.workoutTarget!.zone, TargetZone.interval);
    expect(session.workoutSteps, isNotEmpty);
    expect(session.workoutSteps.first.kind, WorkoutStepKind.warmUp);
    expect(session.workoutSteps[1].kind, WorkoutStepKind.repeat);
    expect(session.workoutSteps[1].repetitions, 5);
    expect(session.workoutSteps[1].steps.first.distanceMeters, 400);
    expect(session.workoutSteps[1].steps.first.target!.zone, TargetZone.interval);
    expect(session.workoutSteps[1].steps.last.duration, const Duration(seconds: 90));
  });
}
