import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/presentation/active_run_timeline.dart';
import 'package:running_app/features/pre_run/presentation/run_flow_context.dart';

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
}
