import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/pre_run/presentation/run_flow_context.dart';

import '../../../helpers/workout_fixtures.dart';

void main() {
  test('RunFlowSessionContext carries structured workout payload', () {
    final session = buildStructuredIntervalSession();
    final context = RunFlowSessionContext.fromSession(session);
    final args = PreRunArgs.fromSession(session);

    expect(context.sessionId, session.id);
    expect(context.sessionType, session.type);
    expect(context.hasStructuredWorkout, isTrue);
    expect(context.workoutTarget, session.workoutTarget);
    expect(context.workoutSteps, hasLength(3));
    expect(context.workoutSteps.first.kind.name, 'warmUp');
    expect(context.workoutSteps[1].kind.name, 'repeat');
    expect(args.session.workoutTarget, session.workoutTarget);
    expect(args.session.workoutSteps, hasLength(3));
  });
}
