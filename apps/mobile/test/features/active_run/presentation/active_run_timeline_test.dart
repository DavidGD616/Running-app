import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/presentation/active_run_timeline.dart';
import 'package:running_app/features/pre_run/presentation/run_flow_context.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/workout_step.dart';
import 'package:running_app/features/training_plan/domain/models/workout_target.dart';

import '../../../helpers/workout_fixtures.dart';

void main() {
  test('fromSession flattens structured interval workout steps', () {
    final session = buildStructuredIntervalSession();
    final context = RunFlowSessionContext.fromSession(session);

    final timeline = ActiveRunTimeline.fromSession(context);

    expect(timeline.blocks, hasLength(14));
    expect(timeline.blocks.first.kind, ActiveRunBlockKind.warmUp);
    expect(timeline.blocks.first.duration, const Duration(minutes: 10));

    final firstWork = timeline.blocks[1];
    expect(firstWork.kind, ActiveRunBlockKind.work);
    expect(firstWork.distanceMeters, 400);
    expect(firstWork.repIndex, 1);
    expect(firstWork.totalReps, 6);

    final thirdWork = timeline.blocks[5];
    expect(thirdWork.kind, ActiveRunBlockKind.work);
    expect(thirdWork.repIndex, 3);
    expect(thirdWork.totalReps, 6);

    final thirdRecovery = timeline.blocks[6];
    expect(thirdRecovery.kind, ActiveRunBlockKind.recovery);
    expect(thirdRecovery.duration, const Duration(seconds: 90));
    expect(thirdRecovery.repIndex, 3);

    expect(timeline.blocks.last.kind, ActiveRunBlockKind.coolDown);
    expect(timeline.blocks.last.duration, const Duration(minutes: 10));
  });

  test('fromSession builds fallback blocks when workout steps are missing', () {
    final session = buildLegacyTempoSession();
    final context = RunFlowSessionContext.fromSession(session);

    final timeline = ActiveRunTimeline.fromSession(context);

    expect(timeline.blocks, hasLength(3));
    expect(timeline.blocks[0].kind, ActiveRunBlockKind.warmUp);
    expect(timeline.blocks[0].duration, const Duration(minutes: 10));
    expect(timeline.blocks[1].kind, ActiveRunBlockKind.work);
    expect(timeline.blocks[1].duration, const Duration(minutes: 20));
    expect(timeline.blocks[2].kind, ActiveRunBlockKind.coolDown);
    expect(timeline.blocks[2].duration, const Duration(minutes: 10));
  });

  test('fromSession flattens stride repeat blocks separately from work', () {
    final session = TrainingSession(
      id: 'easy_with_strides',
      date: DateTime(2026, 4, 22),
      type: SessionType.easyRun,
      status: SessionStatus.today,
      distanceKm: 5,
      durationMinutes: 35,
      workoutSteps: const [
        WorkoutStep.warmUp(
          target: WorkoutTarget.effort(TargetZone.easy),
          duration: Duration(minutes: 5),
        ),
        WorkoutStep.work(
          target: WorkoutTarget.effort(TargetZone.easy),
          duration: Duration(minutes: 20),
        ),
        WorkoutStep.repeat(
          repetitions: 4,
          steps: [
            WorkoutStep.stride(
              target: WorkoutTarget.effort(TargetZone.interval),
              duration: Duration(seconds: 20),
            ),
            WorkoutStep.recovery(
              target: WorkoutTarget.effort(TargetZone.recovery),
              duration: Duration(seconds: 80),
            ),
          ],
        ),
        WorkoutStep.coolDown(
          target: WorkoutTarget.effort(TargetZone.easy),
          duration: Duration(minutes: 3),
        ),
      ],
    );

    final timeline = ActiveRunTimeline.fromSession(
      RunFlowSessionContext.fromSession(session),
    );

    expect(timeline.blocks, hasLength(11));
    expect(timeline.blocks[0].kind, ActiveRunBlockKind.warmUp);
    expect(timeline.blocks[1].kind, ActiveRunBlockKind.work);
    expect(timeline.blocks[2].kind, ActiveRunBlockKind.stride);
    expect(timeline.blocks[2].repIndex, 1);
    expect(timeline.blocks[2].totalReps, 4);
    expect(timeline.blocks[3].kind, ActiveRunBlockKind.recovery);
    expect(timeline.blocks[9].kind, ActiveRunBlockKind.recovery);
    expect(timeline.blocks[10].kind, ActiveRunBlockKind.coolDown);
  });
}
