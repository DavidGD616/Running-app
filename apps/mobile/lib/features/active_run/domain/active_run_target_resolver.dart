import '../../strava/domain/models/strava_coaching_profile.dart';
import '../../training_plan/domain/models/workout_target.dart';

enum PaceGuidanceBlockRole { warmUp, work, recovery, coolDown, stride }

class ActiveRunResolvedTarget {
  const ActiveRunResolvedTarget({
    required this.target,
    required this.zone,
    required this.paceMinSecPerKm,
    required this.paceMaxSecPerKm,
  });

  final WorkoutTarget target;
  final TargetZone zone;
  final int paceMinSecPerKm;
  final int paceMaxSecPerKm;
}

class ActiveRunTargetResolver {
  const ActiveRunTargetResolver();

  ActiveRunResolvedTarget? resolve({
    required WorkoutTarget? currentBlockTarget,
    required PaceGuidanceBlockRole? blockRole,
    required WorkoutTarget? fallbackTarget,
    required StravaPaceZones? paceZones,
  }) {
    final roleZone = _zoneForRole(blockRole);
    final explicitBlockRange = _rangeFor(currentBlockTarget);
    if (explicitBlockRange != null) {
      return ActiveRunResolvedTarget(
        target: currentBlockTarget!,
        zone: currentBlockTarget.zone,
        paceMinSecPerKm: explicitBlockRange.min,
        paceMaxSecPerKm: explicitBlockRange.max,
      );
    }

    final zone = roleZone ?? currentBlockTarget?.zone ?? fallbackTarget?.zone;
    if (zone == null) return null;

    final zoneRange = _rangeForPaceZone(
      _paceZoneFor(zone: zone, blockRole: blockRole, paceZones: paceZones),
    );
    if (zoneRange != null) {
      return ActiveRunResolvedTarget(
        target: WorkoutTarget(
          type:
              currentBlockTarget?.type ??
              fallbackTarget?.type ??
              TargetType.pace,
          zone: zone,
          paceMinSecPerKm: zoneRange.min,
          paceMaxSecPerKm: zoneRange.max,
          effortCue: currentBlockTarget?.effortCue ?? fallbackTarget?.effortCue,
        ),
        zone: zone,
        paceMinSecPerKm: zoneRange.min,
        paceMaxSecPerKm: zoneRange.max,
      );
    }

    final fallbackRange = _rangeFor(fallbackTarget);
    if (fallbackTarget != null &&
        fallbackTarget.zone == zone &&
        fallbackRange != null) {
      return ActiveRunResolvedTarget(
        target: fallbackTarget,
        zone: zone,
        paceMinSecPerKm: fallbackRange.min,
        paceMaxSecPerKm: fallbackRange.max,
      );
    }

    return null;
  }

  ({int min, int max})? _rangeFor(WorkoutTarget? target) {
    final min = target?.paceMinSecPerKm;
    final max = target?.paceMaxSecPerKm;
    if (min == null || max == null) return null;
    return (min: min, max: max);
  }

  ({int min, int max})? _rangeForPaceZone(StravaPaceZone? paceZone) {
    final min = paceZone?.paceMinSecPerKm;
    final max = paceZone?.paceMaxSecPerKm;
    if (min == null || max == null) return null;
    return (min: min, max: max);
  }

  StravaPaceZone? _paceZoneFor({
    required TargetZone zone,
    required PaceGuidanceBlockRole? blockRole,
    required StravaPaceZones? paceZones,
  }) {
    if (paceZones == null) return null;
    if (blockRole == PaceGuidanceBlockRole.stride) return paceZones.strides;
    return switch (zone) {
      TargetZone.recovery => paceZones.recovery,
      TargetZone.easy => paceZones.easy,
      TargetZone.longRun => paceZones.longRun,
      TargetZone.steady => paceZones.steady,
      TargetZone.tempo => paceZones.tempo,
      TargetZone.threshold => paceZones.threshold,
      TargetZone.racePace => paceZones.racePace,
      TargetZone.interval => paceZones.intervals,
    };
  }

  TargetZone? _zoneForRole(PaceGuidanceBlockRole? role) {
    return switch (role) {
      PaceGuidanceBlockRole.warmUp => TargetZone.easy,
      PaceGuidanceBlockRole.recovery => TargetZone.recovery,
      PaceGuidanceBlockRole.coolDown => TargetZone.easy,
      PaceGuidanceBlockRole.stride => TargetZone.interval,
      PaceGuidanceBlockRole.work || null => null,
    };
  }
}
