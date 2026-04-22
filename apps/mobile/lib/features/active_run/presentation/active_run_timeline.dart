import '../../pre_run/presentation/run_flow_context.dart';
import '../../training_plan/domain/models/workout_step.dart';
import '../../training_plan/domain/models/workout_target.dart';

enum ActiveRunBlockKind { warmUp, work, recovery, coolDown, stride }

class ActiveRunTimelineBlock {
  const ActiveRunTimelineBlock({
    required this.kind,
    this.target,
    this.duration,
    this.distanceMeters,
    this.repIndex,
    this.totalReps,
  });

  final ActiveRunBlockKind kind;
  final WorkoutTarget? target;
  final Duration? duration;
  final int? distanceMeters;
  final int? repIndex;
  final int? totalReps;

  bool get isDistanceBased => distanceMeters != null && distanceMeters! > 0;
  bool get isDurationBased => duration != null && duration! > Duration.zero;
  bool get isRepBlock => repIndex != null && totalReps != null;
}

class ActiveRunTimeline {
  const ActiveRunTimeline({required this.blocks});

  final List<ActiveRunTimelineBlock> blocks;

  bool get isEmpty => blocks.isEmpty;
  bool get isNotEmpty => blocks.isNotEmpty;

  factory ActiveRunTimeline.fromSession(RunFlowSessionContext? session) {
    if (session == null || !session.isRunSession) {
      return const ActiveRunTimeline(blocks: []);
    }

    if (session.workoutSteps.isNotEmpty) {
      return ActiveRunTimeline(blocks: _flattenSteps(session.workoutSteps));
    }

    return ActiveRunTimeline(blocks: _fallbackBlocksFor(session));
  }

  static List<ActiveRunTimelineBlock> _flattenSteps(
    List<WorkoutStep> steps, {
    int? repIndex,
    int? totalReps,
  }) {
    final blocks = <ActiveRunTimelineBlock>[];

    for (final step in steps) {
      if (step.kind == WorkoutStepKind.repeat) {
        final repetitions = step.repetitions ?? 0;
        if (repetitions <= 0 || step.steps.isEmpty) continue;
        for (var i = 1; i <= repetitions; i++) {
          blocks.addAll(
            _flattenSteps(step.steps, repIndex: i, totalReps: repetitions),
          );
        }
        continue;
      }

      final kind = switch (step.kind) {
        WorkoutStepKind.warmUp => ActiveRunBlockKind.warmUp,
        WorkoutStepKind.work => ActiveRunBlockKind.work,
        WorkoutStepKind.recovery => ActiveRunBlockKind.recovery,
        WorkoutStepKind.coolDown => ActiveRunBlockKind.coolDown,
        WorkoutStepKind.stride => ActiveRunBlockKind.stride,
        WorkoutStepKind.repeat => null,
      };
      if (kind == null) continue;

      blocks.add(
        ActiveRunTimelineBlock(
          kind: kind,
          target: step.target,
          duration: step.duration,
          distanceMeters: step.distanceMeters,
          repIndex: repIndex,
          totalReps: totalReps,
        ),
      );
    }

    return blocks;
  }

  static List<ActiveRunTimelineBlock> _fallbackBlocksFor(
    RunFlowSessionContext session,
  ) {
    final warmUp = session.warmUpMinutes ?? 0;
    final coolDown = session.coolDownMinutes ?? 0;
    final total = session.durationMinutes ?? 0;
    final main = total - warmUp - coolDown;
    final blocks = <ActiveRunTimelineBlock>[];

    if (warmUp > 0) {
      blocks.add(
        const ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.warmUp,
          duration: Duration.zero,
          target: WorkoutTarget.effort(TargetZone.easy),
        ).copyWith(duration: Duration(minutes: warmUp)),
      );
    }

    if (main > 0) {
      blocks.add(
        ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          duration: Duration(minutes: main),
          target: session.workoutTarget,
        ),
      );
    }

    if (coolDown > 0) {
      blocks.add(
        const ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.coolDown,
          duration: Duration.zero,
          target: WorkoutTarget.effort(TargetZone.recovery),
        ).copyWith(duration: Duration(minutes: coolDown)),
      );
    }

    return blocks;
  }
}

extension on ActiveRunTimelineBlock {
  ActiveRunTimelineBlock copyWith({Duration? duration}) {
    return ActiveRunTimelineBlock(
      kind: kind,
      target: target,
      duration: duration ?? this.duration,
      distanceMeters: distanceMeters,
      repIndex: repIndex,
      totalReps: totalReps,
    );
  }
}
