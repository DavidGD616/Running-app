import 'package:flutter/material.dart';

import '../../../core/utils/unit_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../pre_run/presentation/run_flow_context.dart';
import '../../strava/domain/models/strava_coaching_profile.dart';
import '../../training_plan/domain/models/session_type.dart';
import '../../training_plan/domain/models/training_session.dart';
import '../../training_plan/domain/models/workout_step.dart';
import '../../training_plan/domain/models/workout_target.dart';
import '../../user_preferences/domain/user_preferences.dart';

class WorkoutGuidance {
  const WorkoutGuidance({
    required this.chips,
    required this.phases,
    required this.paceEffortRows,
    required this.howToRunIt,
    required this.whyItMatters,
  });

  final List<WorkoutGuidanceChip> chips;
  final List<WorkoutGuidancePhase> phases;
  final List<String> paceEffortRows;
  final String howToRunIt;
  final String whyItMatters;
}

class WorkoutGuidanceChip {
  const WorkoutGuidanceChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class WorkoutGuidancePhase {
  const WorkoutGuidancePhase({
    required this.title,
    required this.measure,
    required this.guidance,
    required this.kind,
  });

  final String title;
  final String measure;
  final String guidance;
  final WorkoutStepKind kind;
}

class _PaceBounds {
  const _PaceBounds({required this.minSecPerKm, required this.maxSecPerKm});

  final int minSecPerKm;
  final int maxSecPerKm;
}

class _DurationEstimate {
  const _DurationEstimate({required this.minSeconds, required this.maxSeconds});

  final double minSeconds;
  final double maxSeconds;

  int get minMinutes => (minSeconds / 60).round();
  int get maxMinutes => (maxSeconds / 60).round();
}

class _StepEstimate {
  const _StepEstimate({
    required this.minSeconds,
    required this.maxSeconds,
    required this.hasDistance,
    required this.canEstimate,
  });

  final double minSeconds;
  final double maxSeconds;
  final bool hasDistance;
  final bool canEstimate;

  _DurationEstimate toMinutes() {
    return _DurationEstimate(minSeconds: minSeconds, maxSeconds: maxSeconds);
  }
}

class WorkoutGuidancePresenter {
  const WorkoutGuidancePresenter({
    required this.l10n,
    required this.unitSystem,
    this.paceZones,
  });

  final AppLocalizations l10n;
  final UnitSystem unitSystem;
  final StravaPaceZones? paceZones;

  WorkoutGuidance fromTrainingSession(TrainingSession session) {
    return _build(
      type: session.type,
      distanceKm: session.distanceKm,
      durationMinutes: session.durationMinutes,
      workoutTarget: session.workoutTarget,
      workoutSteps: session.workoutSteps,
      description: session.description,
      warmUpMinutes: session.warmUpMinutes,
      coolDownMinutes: session.coolDownMinutes,
    );
  }

  WorkoutGuidance fromRunFlowSession(RunFlowSessionContext session) {
    return _build(
      type: session.sessionType,
      distanceKm: session.distanceKm,
      durationMinutes: session.durationMinutes,
      workoutTarget: session.workoutTarget,
      workoutSteps: session.workoutSteps,
      description: null,
      warmUpMinutes: session.warmUpMinutes,
      coolDownMinutes: session.coolDownMinutes,
    );
  }

  WorkoutGuidance _build({
    required SessionType type,
    required double? distanceKm,
    required int? durationMinutes,
    required WorkoutTarget? workoutTarget,
    required List<WorkoutStep> workoutSteps,
    required String? description,
    required int? warmUpMinutes,
    required int? coolDownMinutes,
  }) {
    final phases = workoutSteps.isNotEmpty
        ? _phasesFromSteps(type, workoutSteps, distanceKm)
        : _fallbackPhases(
            type,
            durationMinutes,
            warmUpMinutes,
            coolDownMinutes,
          );
    final rows = _paceEffortRows(type, workoutTarget, workoutSteps);
    final durationLabel = _durationLabel(
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      target: _primaryTarget(workoutTarget, workoutSteps),
      workoutSteps: workoutSteps,
    );

    return WorkoutGuidance(
      chips: [
        if (distanceKm != null)
          WorkoutGuidanceChip(
            label: l10n.sessionDetailTotalDistanceLabel,
            value: UnitFormatter.formatDistanceLabel(
              distanceKm,
              unitSystem,
              l10n,
            ),
            icon: Icons.route_outlined,
          ),
        WorkoutGuidanceChip(
          label: l10n.sessionDetailEstDurationLabel,
          value: durationLabel,
          icon: Icons.timer_outlined,
        ),
      ],
      phases: phases,
      paceEffortRows: rows,
      howToRunIt: description?.trim().isNotEmpty == true
          ? description!.trim()
          : l10n.workoutGuidanceDefaultHow,
      whyItMatters: l10n.workoutGuidanceWhyForSession(_sessionTypeLabel(type)),
    );
  }

  List<WorkoutGuidancePhase> _phasesFromSteps(
    SessionType type,
    List<WorkoutStep> steps,
    double? distanceKm,
  ) {
    final phases = <WorkoutGuidancePhase>[];
    final distanceMeasures = _distanceFirstWorkMeasures(
      type,
      steps,
      distanceKm,
    );
    var progressionWorkIndex = 0;
    var workIndex = 0;

    for (final step in steps) {
      String? measureOverride;
      if (step.kind == WorkoutStepKind.work && distanceMeasures != null) {
        measureOverride = distanceMeasures[workIndex];
        workIndex += 1;
      }
      if (step.kind == WorkoutStepKind.work &&
          type == SessionType.progressionRun) {
        final title = switch (progressionWorkIndex) {
          0 => l10n.activeRunEasyBlock,
          1 => l10n.activeRunSteadyBlock,
          _ => l10n.workoutGuidanceFirm,
        };
        progressionWorkIndex += 1;
        phases.add(_phase(step, title, measureOverride: measureOverride));
        continue;
      }

      phases.add(
        _phase(step, _stepTitle(step, type), measureOverride: measureOverride),
      );
    }

    return phases;
  }

  WorkoutGuidancePhase _phase(
    WorkoutStep step,
    String title, {
    String? measureOverride,
  }) {
    return WorkoutGuidancePhase(
      title: title,
      measure: measureOverride ?? _stepMeasure(step),
      guidance: _stepGuidance(step),
      kind: step.kind,
    );
  }

  List<String>? _distanceFirstWorkMeasures(
    SessionType type,
    List<WorkoutStep> steps,
    double? distanceKm,
  ) {
    if (distanceKm == null || distanceKm <= 0) return null;
    if (!_usesDistanceFirstPhaseMeasures(type)) return null;

    final workSteps = steps
        .where((step) => step.kind == WorkoutStepKind.work)
        .toList(growable: false);
    if (workSteps.isEmpty) return null;
    if (workSteps.any(
      (step) => step.distanceMeters != null && step.distanceMeters! > 0,
    )) {
      return null;
    }

    final buckets = _splitMeters(distanceKm, workSteps.length);
    return [
      for (final meters in buckets)
        UnitFormatter.formatWorkoutRepDistance(meters, unitSystem, l10n),
    ];
  }

  bool _usesDistanceFirstPhaseMeasures(SessionType type) {
    return switch (type) {
      SessionType.progressionRun || SessionType.racePaceRun => true,
      _ => false,
    };
  }

  List<int> _splitMeters(double distanceKm, int parts) {
    final totalMeters = (distanceKm * 1000).round();
    final base = totalMeters ~/ parts;
    final remainder = totalMeters % parts;
    return [
      for (var index = 0; index < parts; index++)
        base + (index < remainder ? 1 : 0),
    ];
  }

  List<WorkoutGuidancePhase> _fallbackPhases(
    SessionType type,
    int? durationMinutes,
    int? warmUpMinutes,
    int? coolDownMinutes,
  ) {
    final phases = <WorkoutGuidancePhase>[];
    if (warmUpMinutes != null && warmUpMinutes > 0) {
      phases.add(
        WorkoutGuidancePhase(
          title: l10n.sessionDetailWarmUp,
          measure: UnitFormatter.formatDuration(warmUpMinutes, l10n),
          guidance: zoneGuidance(TargetZone.easy),
          kind: WorkoutStepKind.warmUp,
        ),
      );
    }

    final mainMinutes = durationMinutes == null
        ? null
        : durationMinutes - (warmUpMinutes ?? 0) - (coolDownMinutes ?? 0);
    phases.add(
      WorkoutGuidancePhase(
        title: _sessionTypeLabel(type),
        measure: mainMinutes != null && mainMinutes > 0
            ? UnitFormatter.formatDuration(mainMinutes, l10n)
            : l10n.workoutGuidanceOpenMeasure,
        guidance: zoneGuidance(_defaultZone(type)),
        kind: WorkoutStepKind.work,
      ),
    );

    if (coolDownMinutes != null && coolDownMinutes > 0) {
      phases.add(
        WorkoutGuidancePhase(
          title: l10n.sessionDetailCoolDown,
          measure: UnitFormatter.formatDuration(coolDownMinutes, l10n),
          guidance: zoneGuidance(TargetZone.recovery),
          kind: WorkoutStepKind.coolDown,
        ),
      );
    }

    return phases;
  }

  List<String> _paceEffortRows(
    SessionType type,
    WorkoutTarget? workoutTarget,
    List<WorkoutStep> steps,
  ) {
    final rows = <String>[];
    final zones = <TargetZone>[];
    void addRow(String row) {
      if (!rows.contains(row)) rows.add(row);
    }

    void addZone(TargetZone? zone) {
      if (zone != null && !zones.contains(zone)) zones.add(zone);
    }

    for (final step in steps) {
      if (step.target != null) addRow(targetGuidance(step.target!));
      if (type == SessionType.progressionRun &&
          step.kind == WorkoutStepKind.work &&
          step.target?.zone == TargetZone.tempo) {
        addZone(TargetZone.tempo);
      } else {
        addZone(step.target?.zone);
      }
      for (final child in step.steps) {
        if (child.target != null) addRow(targetGuidance(child.target!));
        addZone(child.target?.zone);
      }
    }
    if (workoutTarget != null) addRow(targetGuidance(workoutTarget));
    addZone(workoutTarget?.zone);
    if (zones.isEmpty) addZone(_defaultZone(type));

    for (final zone in zones) {
      addRow(zoneGuidance(zone));
    }
    return rows;
  }

  String targetGuidance(WorkoutTarget target) {
    final label = _zoneLabel(target.zone);
    final cue = target.effortCue?.trim().isNotEmpty == true
        ? target.effortCue!.trim()
        : _zoneCue(target.zone);
    final pace = _paceRangeForTarget(target) ?? _paceRangeForZone(target.zone);
    if (pace == null) {
      return l10n.workoutGuidanceEffortOnly(label, cue);
    }
    return l10n.workoutGuidancePaceRange(label, pace, cue);
  }

  String zoneGuidance(TargetZone zone) {
    final label = _zoneLabel(zone);
    final cue = _zoneCue(zone);
    final pace = _paceRangeForZone(zone);
    if (pace == null) {
      return l10n.workoutGuidanceEffortOnly(label, cue);
    }
    return l10n.workoutGuidancePaceRange(label, pace, cue);
  }

  String _zoneLabel(TargetZone zone) {
    return switch (zone) {
      TargetZone.recovery => l10n.workoutGuidanceZoneRecovery,
      TargetZone.easy => l10n.workoutGuidanceZoneEasy,
      TargetZone.longRun => l10n.workoutGuidanceZoneLongRun,
      TargetZone.steady => l10n.workoutGuidanceZoneSteady,
      TargetZone.tempo => l10n.workoutGuidanceZoneTempo,
      TargetZone.threshold => l10n.workoutGuidanceZoneThreshold,
      TargetZone.racePace => l10n.workoutGuidanceZoneRacePace,
      TargetZone.interval => l10n.workoutGuidanceZoneInterval,
    };
  }

  String _zoneCue(TargetZone zone) {
    return switch (zone) {
      TargetZone.recovery => l10n.workoutGuidanceCueGentle,
      TargetZone.easy ||
      TargetZone.longRun => l10n.workoutGuidanceCueConversational,
      TargetZone.steady => l10n.workoutGuidanceCueControlled,
      TargetZone.tempo ||
      TargetZone.threshold ||
      TargetZone.racePace => l10n.workoutGuidanceCueComposed,
      TargetZone.interval => l10n.workoutGuidanceCueFast,
    };
  }

  String? _paceRangeForZone(TargetZone zone) {
    final paceZone = _paceZone(zone);
    return _paceRangeText(paceZone?.paceMinSecPerKm, paceZone?.paceMaxSecPerKm);
  }

  String? _paceRangeForTarget(WorkoutTarget target) {
    return _paceRangeText(target.paceMinSecPerKm, target.paceMaxSecPerKm);
  }

  String? _paceRangeText(int? min, int? max) {
    if (min == null && max == null) return null;

    final paceUnit = UnitFormatter.paceLabel(unitSystem, l10n);
    if (min != null && max != null) {
      return '${_formatPace(min)}-${_formatPace(max)} $paceUnit';
    }
    if (min != null) return '${_formatPace(min)}+ $paceUnit';
    return '<${_formatPace(max!)} $paceUnit';
  }

  StravaPaceZone? _paceZone(TargetZone zone) {
    final zones = paceZones;
    if (zones == null) return null;
    return switch (zone) {
      TargetZone.recovery => zones.recovery,
      TargetZone.easy => zones.easy,
      TargetZone.longRun => zones.longRun,
      TargetZone.steady => zones.steady,
      TargetZone.tempo => zones.tempo,
      TargetZone.threshold => zones.threshold,
      TargetZone.racePace => zones.racePace,
      TargetZone.interval => zones.intervals,
    };
  }

  String _durationLabel({
    required double? distanceKm,
    required int? durationMinutes,
    required WorkoutTarget? target,
    required List<WorkoutStep> workoutSteps,
  }) {
    if (durationMinutes != null) {
      return UnitFormatter.formatDuration(durationMinutes, l10n);
    }
    final estimate = _estimateDurationMinutes(
      sessionDistanceKm: distanceKm,
      fallbackTarget: target,
      workoutSteps: workoutSteps,
    );
    if (distanceKm == null && estimate == null) {
      return l10n.workoutGuidanceOpenMeasure;
    }
    if (estimate == null) {
      return l10n.workoutGuidanceDistanceBased;
    }

    final range = l10n.workoutGuidanceEstimatedDurationRange(
      estimate.minMinutes,
      estimate.maxMinutes,
    );
    return l10n.workoutGuidanceDistanceBasedWithEstimate(
      l10n.workoutGuidanceDistanceBased,
      range,
    );
  }

  _DurationEstimate? _estimateDurationMinutes({
    required double? sessionDistanceKm,
    required WorkoutTarget? fallbackTarget,
    required List<WorkoutStep> workoutSteps,
  }) {
    if (workoutSteps.isNotEmpty) {
      final estimate = _estimateSteps(workoutSteps, fallbackTarget);
      if (estimate.hasDistance) {
        return estimate.canEstimate ? estimate.toMinutes() : null;
      }
    }

    if (sessionDistanceKm == null || sessionDistanceKm <= 0) return null;
    final paces = _paceBoundsForTarget(fallbackTarget);
    if (paces == null) return null;
    return _DurationEstimate(
      minSeconds: sessionDistanceKm * paces.minSecPerKm,
      maxSeconds: sessionDistanceKm * paces.maxSecPerKm,
    );
  }

  _StepEstimate _estimateSteps(
    List<WorkoutStep> steps,
    WorkoutTarget? fallbackTarget,
  ) {
    var minSeconds = 0.0;
    var maxSeconds = 0.0;
    var hasDistance = false;
    var canEstimate = true;

    for (final step in steps) {
      final estimate = _estimateStep(step, fallbackTarget);
      minSeconds += estimate.minSeconds;
      maxSeconds += estimate.maxSeconds;
      hasDistance = hasDistance || estimate.hasDistance;
      canEstimate = canEstimate && estimate.canEstimate;
    }

    return _StepEstimate(
      minSeconds: minSeconds,
      maxSeconds: maxSeconds,
      hasDistance: hasDistance,
      canEstimate: canEstimate,
    );
  }

  _StepEstimate _estimateStep(WorkoutStep step, WorkoutTarget? fallbackTarget) {
    if (step.kind == WorkoutStepKind.repeat) {
      final nested = _estimateSteps(step.steps, fallbackTarget);
      final reps = step.repetitions ?? 1;
      return _StepEstimate(
        minSeconds: nested.minSeconds * reps,
        maxSeconds: nested.maxSeconds * reps,
        hasDistance: nested.hasDistance,
        canEstimate: nested.canEstimate,
      );
    }

    final duration = step.duration;
    if (duration != null && duration > Duration.zero) {
      return _StepEstimate(
        minSeconds: duration.inSeconds.toDouble(),
        maxSeconds: duration.inSeconds.toDouble(),
        hasDistance: false,
        canEstimate: true,
      );
    }

    final meters = step.distanceMeters;
    if (meters != null && meters > 0) {
      final paces = _paceBoundsForTarget(step.target ?? fallbackTarget);
      if (paces == null) {
        return const _StepEstimate(
          minSeconds: 0,
          maxSeconds: 0,
          hasDistance: true,
          canEstimate: false,
        );
      }
      final distanceKm = meters / 1000;
      return _StepEstimate(
        minSeconds: distanceKm * paces.minSecPerKm,
        maxSeconds: distanceKm * paces.maxSecPerKm,
        hasDistance: true,
        canEstimate: true,
      );
    }

    return const _StepEstimate(
      minSeconds: 0,
      maxSeconds: 0,
      hasDistance: false,
      canEstimate: true,
    );
  }

  _PaceBounds? _paceBoundsForTarget(WorkoutTarget? target) {
    final zone = target?.zone ?? TargetZone.easy;
    final paceZone = _paceZone(zone);
    final minPace = target?.paceMinSecPerKm ?? paceZone?.paceMinSecPerKm;
    final maxPace = target?.paceMaxSecPerKm ?? paceZone?.paceMaxSecPerKm;
    if (minPace == null || maxPace == null) return null;
    return _PaceBounds(minSecPerKm: minPace, maxSecPerKm: maxPace);
  }

  WorkoutTarget? _primaryTarget(
    WorkoutTarget? workoutTarget,
    List<WorkoutStep> steps,
  ) {
    for (final step in steps) {
      if (step.kind == WorkoutStepKind.work && step.target != null) {
        return step.target;
      }
      for (final child in step.steps) {
        if (child.kind == WorkoutStepKind.work && child.target != null) {
          return child.target;
        }
      }
    }
    return workoutTarget;
  }

  String _stepTitle(WorkoutStep step, SessionType type) {
    return switch (step.kind) {
      WorkoutStepKind.warmUp => l10n.sessionDetailWarmUp,
      WorkoutStepKind.coolDown => l10n.sessionDetailCoolDown,
      WorkoutStepKind.recovery => l10n.activeRunRecovery,
      WorkoutStepKind.stride => l10n.activeRunStride,
      WorkoutStepKind.repeat => _repeatTitle(step, type),
      WorkoutStepKind.work => _sessionTypeLabel(type),
    };
  }

  String _repeatTitle(WorkoutStep step, SessionType type) {
    if (step.steps.any((child) => child.kind == WorkoutStepKind.stride)) {
      return l10n.sessionDetailStrides;
    }
    return switch (type) {
      SessionType.hillRepeats => l10n.sessionTypeHillRepeats,
      SessionType.fartlek => l10n.sessionTypeFartlek,
      _ => l10n.weeklyPlanSessionIntervals,
    };
  }

  String _stepMeasure(WorkoutStep step) {
    if (step.kind == WorkoutStepKind.repeat) {
      final work =
          _childStep(step, WorkoutStepKind.work) ??
          _childStep(step, WorkoutStepKind.stride);
      final recovery = _childStep(step, WorkoutStepKind.recovery);
      return l10n.workoutGuidanceRepeatMeasure(
        step.repetitions ?? 1,
        work == null ? l10n.workoutGuidanceOpenMeasure : _stepMeasure(work),
        recovery == null
            ? l10n.workoutGuidanceOpenMeasure
            : _stepMeasure(recovery),
      );
    }

    if (step.distanceMeters != null && step.distanceMeters! > 0) {
      return UnitFormatter.formatWorkoutRepDistance(
        step.distanceMeters!,
        unitSystem,
        l10n,
      );
    }
    final duration = step.duration;
    if (duration != null && duration > Duration.zero) {
      if (duration.inSeconds < 120) {
        return l10n.preRunWorkoutPreviewDurationSeconds(duration.inSeconds);
      }
      return UnitFormatter.formatDuration(duration.inMinutes, l10n);
    }
    return l10n.workoutGuidanceOpenMeasure;
  }

  String _stepGuidance(WorkoutStep step) {
    final target = step.target;
    if (target != null) return targetGuidance(target);

    if (step.kind == WorkoutStepKind.repeat) {
      final workTarget = _childStep(step, WorkoutStepKind.work)?.target;
      if (workTarget != null) return targetGuidance(workTarget);

      final strideTarget = _childStep(step, WorkoutStepKind.stride)?.target;
      if (strideTarget != null) return targetGuidance(strideTarget);

      final recoveryTarget = _childStep(step, WorkoutStepKind.recovery)?.target;
      if (recoveryTarget != null) return targetGuidance(recoveryTarget);
    }

    return l10n.workoutGuidanceDefaultHow;
  }

  WorkoutStep? _childStep(WorkoutStep parent, WorkoutStepKind kind) {
    for (final child in parent.steps) {
      if (child.kind == kind) return child;
    }
    return null;
  }

  String _formatPace(int secondsPerKm) {
    final convertedSeconds = unitSystem == UnitSystem.km
        ? secondsPerKm
        : (secondsPerKm * 1.609344).round();
    final minutes = convertedSeconds ~/ 60;
    final seconds = convertedSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  TargetZone _defaultZone(SessionType type) {
    return switch (type) {
      SessionType.recoveryRun => TargetZone.recovery,
      SessionType.longRun => TargetZone.longRun,
      SessionType.progressionRun => TargetZone.steady,
      SessionType.intervals || SessionType.hillRepeats => TargetZone.interval,
      SessionType.fartlek || SessionType.tempoRun => TargetZone.tempo,
      SessionType.thresholdRun => TargetZone.threshold,
      SessionType.racePaceRun => TargetZone.racePace,
      _ => TargetZone.easy,
    };
  }

  String _sessionTypeLabel(SessionType type) {
    return switch (type) {
      SessionType.restDay => l10n.sessionTypeRestDay,
      SessionType.raceDay => l10n.raceDayInfoTitle,
      SessionType.easyRun => l10n.weeklyPlanSessionEasyRun,
      SessionType.longRun => l10n.weeklyPlanSessionLongRun,
      SessionType.progressionRun => l10n.sessionTypeProgressionRun,
      SessionType.intervals => l10n.weeklyPlanSessionIntervals,
      SessionType.hillRepeats => l10n.sessionTypeHillRepeats,
      SessionType.fartlek => l10n.sessionTypeFartlek,
      SessionType.tempoRun => l10n.sessionTypeTempoRun,
      SessionType.thresholdRun => l10n.sessionTypeThresholdRun,
      SessionType.racePaceRun => l10n.sessionTypeRacePaceRun,
      SessionType.recoveryRun => l10n.weeklyPlanSessionRecoveryRun,
      SessionType.crossTraining => l10n.sessionTypeCrossTraining,
    };
  }
}
