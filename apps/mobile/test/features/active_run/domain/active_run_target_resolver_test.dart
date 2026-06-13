import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/domain/active_run_target_resolver.dart';
import 'package:running_app/features/strava/domain/models/strava_coaching_profile.dart';
import 'package:running_app/features/training_plan/domain/models/workout_target.dart';

void main() {
  group('ActiveRunTargetResolver', () {
    const resolver = ActiveRunTargetResolver();
    const paceZones = StravaPaceZones(
      recovery: StravaPaceZone(paceMinSecPerKm: 420, paceMaxSecPerKm: 480),
      easy: StravaPaceZone(paceMinSecPerKm: 360, paceMaxSecPerKm: 420),
      longRun: StravaPaceZone(paceMinSecPerKm: 370, paceMaxSecPerKm: 440),
      steady: StravaPaceZone(paceMinSecPerKm: 330, paceMaxSecPerKm: 360),
      tempo: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 320),
      threshold: StravaPaceZone(paceMinSecPerKm: 285, paceMaxSecPerKm: 300),
      racePace: StravaPaceZone(paceMinSecPerKm: 295, paceMaxSecPerKm: 305),
      intervals: StravaPaceZone(paceMinSecPerKm: 250, paceMaxSecPerKm: 270),
      strides: StravaPaceZone(paceMinSecPerKm: 220, paceMaxSecPerKm: 240),
    );

    test('uses explicit block target range first', () {
      final target = resolver.resolve(
        currentBlockTarget: const WorkoutTarget.pace(
          TargetZone.tempo,
          paceMinSecPerKm: 310,
          paceMaxSecPerKm: 330,
        ),
        blockRole: PaceGuidanceBlockRole.work,
        fallbackTarget: const WorkoutTarget.pace(
          TargetZone.tempo,
          paceMinSecPerKm: 290,
          paceMaxSecPerKm: 300,
        ),
        paceZones: paceZones,
      );

      expect(target?.paceMinSecPerKm, 310);
      expect(target?.paceMaxSecPerKm, 330);
      expect(target?.zone, TargetZone.tempo);
    });

    test('uses pace zones for zone-only work blocks', () {
      final target = resolver.resolve(
        currentBlockTarget: const WorkoutTarget.pace(TargetZone.interval),
        blockRole: PaceGuidanceBlockRole.work,
        fallbackTarget: null,
        paceZones: paceZones,
      );

      expect(target?.paceMinSecPerKm, 250);
      expect(target?.paceMaxSecPerKm, 270);
      expect(target?.zone, TargetZone.interval);
    });

    test('uses strides pace zone while keeping interval target zone', () {
      final target = resolver.resolve(
        currentBlockTarget: const WorkoutTarget.pace(TargetZone.interval),
        blockRole: PaceGuidanceBlockRole.stride,
        fallbackTarget: null,
        paceZones: paceZones,
      );

      expect(target?.paceMinSecPerKm, 220);
      expect(target?.paceMaxSecPerKm, 240);
      expect(target?.zone, TargetZone.interval);
    });

    test('uses recovery pace zone instead of interval fallback', () {
      final target = resolver.resolve(
        currentBlockTarget: const WorkoutTarget.effort(TargetZone.recovery),
        blockRole: PaceGuidanceBlockRole.recovery,
        fallbackTarget: const WorkoutTarget.pace(
          TargetZone.interval,
          paceMinSecPerKm: 250,
          paceMaxSecPerKm: 270,
        ),
        paceZones: paceZones,
      );

      expect(target?.paceMinSecPerKm, 420);
      expect(target?.paceMaxSecPerKm, 480);
      expect(target?.zone, TargetZone.recovery);
    });

    test('warm-up role uses easy pace zone over mismatched block zone', () {
      final target = resolver.resolve(
        currentBlockTarget: const WorkoutTarget.effort(TargetZone.interval),
        blockRole: PaceGuidanceBlockRole.warmUp,
        fallbackTarget: null,
        paceZones: paceZones,
      );

      expect(target?.paceMinSecPerKm, 360);
      expect(target?.paceMaxSecPerKm, 420);
      expect(target?.zone, TargetZone.easy);
    });

    test('cool-down role uses easy pace zone over recovery block zone', () {
      final target = resolver.resolve(
        currentBlockTarget: const WorkoutTarget.effort(TargetZone.recovery),
        blockRole: PaceGuidanceBlockRole.coolDown,
        fallbackTarget: null,
        paceZones: paceZones,
      );

      expect(target?.paceMinSecPerKm, 360);
      expect(target?.paceMaxSecPerKm, 420);
      expect(target?.zone, TargetZone.easy);
    });

    test('does not use mismatched fallback when pace zones are missing', () {
      final target = resolver.resolve(
        currentBlockTarget: const WorkoutTarget.effort(TargetZone.recovery),
        blockRole: PaceGuidanceBlockRole.recovery,
        fallbackTarget: const WorkoutTarget.pace(
          TargetZone.interval,
          paceMinSecPerKm: 250,
          paceMaxSecPerKm: 270,
        ),
        paceZones: null,
      );

      expect(target, isNull);
    });

    test('uses same-zone fallback when pace zones are missing', () {
      final target = resolver.resolve(
        currentBlockTarget: const WorkoutTarget.effort(TargetZone.easy),
        blockRole: PaceGuidanceBlockRole.work,
        fallbackTarget: const WorkoutTarget.pace(
          TargetZone.easy,
          paceMinSecPerKm: 360,
          paceMaxSecPerKm: 420,
        ),
        paceZones: null,
      );

      expect(target?.paceMinSecPerKm, 360);
      expect(target?.paceMaxSecPerKm, 420);
    });
  });
}
