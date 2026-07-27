import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/pre_run/presentation/run_flow_context.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';

import '../../../helpers/workout_fixtures.dart';

final paceZonesFixture = StravaPaceZones(
  recovery: const StravaPaceZone(paceMinSecPerKm: 460, paceMaxSecPerKm: 520),
  easy: const StravaPaceZone(paceMinSecPerKm: 380, paceMaxSecPerKm: 420),
  longRun: const StravaPaceZone(paceMinSecPerKm: 360, paceMaxSecPerKm: 430),
  steady: const StravaPaceZone(paceMinSecPerKm: 340, paceMaxSecPerKm: 390),
  tempo: const StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 340),
  threshold: const StravaPaceZone(paceMinSecPerKm: 280, paceMaxSecPerKm: 310),
  racePace: const StravaPaceZone(paceMinSecPerKm: 270, paceMaxSecPerKm: 300),
  intervals: const StravaPaceZone(paceMinSecPerKm: 260, paceMaxSecPerKm: 290),
  strides: const StravaPaceZone(paceMinSecPerKm: 240, paceMaxSecPerKm: 260),
);

void main() {
  test('RunFlowSessionContext carries structured workout payload', () {
    final session = buildStructuredIntervalSession();
    final context = RunFlowSessionContext.fromSession(
      session,
      planVersionId: 'plan-version-4',
    );
    final args = PreRunArgs.fromSession(
      session,
      planVersionId: 'plan-version-4',
    );

    expect(context.sessionId, session.id);
    expect(context.sessionType, session.type);
    expect(context.hasStructuredWorkout, isTrue);
    expect(context.workoutTarget, session.workoutTarget);
    expect(context.workoutSteps, hasLength(3));
    expect(context.workoutSteps.first.kind.name, 'warmUp');
    expect(context.workoutSteps[1].kind.name, 'repeat');
    expect(context.planVersionId, 'plan-version-4');
    expect(args.session.workoutTarget, session.workoutTarget);
    expect(args.session.workoutSteps, hasLength(3));
    expect(args.session.planVersionId, 'plan-version-4');
  });

  test('RunFlowSessionContext carries selected pace zones', () {
    final session = buildStructuredIntervalSession();
    final context = RunFlowSessionContext.fromSession(
      session,
      paceZones: paceZonesFixture,
    );
    final args = PreRunArgs.fromSession(session, paceZones: paceZonesFixture);

    expect(context.paceZones?.easy.paceMinSecPerKm, 380);
    expect(context.paceZones?.easy.paceMaxSecPerKm, 420);
    expect(args.session.paceZones?.easy.paceMinSecPerKm, 380);
    expect(args.session.paceZones?.easy.paceMaxSecPerKm, 420);
  });

  test(
    'RunFlowSessionContext fromJson is backward compatible without paceZones',
    () {
      final session = buildStructuredIntervalSession();
      final context = RunFlowSessionContext.fromSession(
        session,
        paceZones: paceZonesFixture,
      );
      final serialized = context.toJson();
      serialized.remove('paceZones');

      final restored = RunFlowSessionContext.fromJson(serialized);

      expect(restored.paceZones, isNull);
      expect(restored.sessionId, session.id);
      expect(restored.sessionType, session.type);
      expect(restored.workoutSteps, hasLength(3));
    },
  );

  test('RunFlowSessionContext JSON preserves captured plan provenance', () {
    final session = buildStructuredIntervalSession();
    final context = RunFlowSessionContext.fromSession(
      session,
      planVersionId: 'plan-version-4',
    );

    final restored = RunFlowSessionContext.fromJson(context.toJson());

    expect(restored.planVersionId, 'plan-version-4');
  });

  test(
    'RunFlowSessionContext JSON remains backward compatible without provenance',
    () {
      final session = buildStructuredIntervalSession();
      final serialized = RunFlowSessionContext.fromSession(session).toJson()
        ..remove('planVersionId');

      final restored = RunFlowSessionContext.fromJson(serialized);

      expect(restored.planVersionId, isNull);
    },
  );
}
