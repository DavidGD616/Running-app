import 'workout_target.dart';

enum WorkoutStepKind { warmUp, work, recovery, coolDown, repeat, stride }

class WorkoutStep {
  const WorkoutStep({
    required this.kind,
    this.target,
    this.duration,
    this.distanceMeters,
    this.repetitions,
    this.steps = const [],
  });

  static const int schemaVersion = 1;

  final WorkoutStepKind kind;
  final WorkoutTarget? target;
  final Duration? duration;
  final int? distanceMeters;
  final int? repetitions;
  final List<WorkoutStep> steps;

  bool get hasNestedSteps => steps.isNotEmpty;

  bool get isRepeating =>
      kind == WorkoutStepKind.repeat && (repetitions ?? 0) > 1;

  const WorkoutStep.warmUp({
    this.target,
    this.duration,
    this.distanceMeters,
    this.repetitions,
    this.steps = const [],
  }) : kind = WorkoutStepKind.warmUp;

  const WorkoutStep.work({
    this.target,
    this.duration,
    this.distanceMeters,
    this.repetitions,
    this.steps = const [],
  }) : kind = WorkoutStepKind.work;

  const WorkoutStep.recovery({
    this.target,
    this.duration,
    this.distanceMeters,
    this.repetitions,
    this.steps = const [],
  }) : kind = WorkoutStepKind.recovery;

  const WorkoutStep.coolDown({
    this.target,
    this.duration,
    this.distanceMeters,
    this.repetitions,
    this.steps = const [],
  }) : kind = WorkoutStepKind.coolDown;

  const WorkoutStep.repeat({
    required this.repetitions,
    required this.steps,
    this.target,
    this.duration,
    this.distanceMeters,
  }) : kind = WorkoutStepKind.repeat;

  const WorkoutStep.stride({
    this.target,
    this.duration,
    this.distanceMeters,
    this.repetitions,
    this.steps = const [],
  }) : kind = WorkoutStepKind.stride;

  WorkoutStep copyWith({
    WorkoutStepKind? kind,
    WorkoutTarget? target,
    Duration? duration,
    int? distanceMeters,
    int? repetitions,
    List<WorkoutStep>? steps,
  }) {
    return WorkoutStep(
      kind: kind ?? this.kind,
      target: target ?? this.target,
      duration: duration ?? this.duration,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      repetitions: repetitions ?? this.repetitions,
      steps: steps ?? this.steps,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'kind': kind.name,
      'target': target?.toJson(),
      'durationMs': duration?.inMilliseconds,
      'distanceMeters': distanceMeters,
      'repetitions': repetitions,
      'steps': steps.map((step) => step.toJson()).toList(growable: false),
    };
  }

  static WorkoutStep? fromJson(Map<String, dynamic> json) {
    final kind = _stepKindFromKey(json['kind'] as String?);
    if (kind == null) return null;

    final steps = <WorkoutStep>[];
    final rawSteps = json['steps'];
    if (rawSteps is List) {
      for (final item in rawSteps) {
        if (item is Map<String, dynamic>) {
          final step = WorkoutStep.fromJson(item);
          if (step != null) steps.add(step);
        } else if (item is Map) {
          final step = WorkoutStep.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          );
          if (step != null) steps.add(step);
        }
      }
    }

    WorkoutTarget? target;
    final rawTarget = json['target'];
    if (rawTarget is Map<String, dynamic>) {
      target = WorkoutTarget.fromJson(rawTarget);
    } else if (rawTarget is Map) {
      target = WorkoutTarget.fromJson(
        rawTarget.map((key, value) => MapEntry('$key', value)),
      );
    }

    return WorkoutStep(
      kind: kind,
      target: target,
      duration: _durationFromJson(json['durationMs']),
      distanceMeters: _intFromJson(json['distanceMeters']),
      repetitions: _intFromJson(json['repetitions']),
      steps: steps,
    );
  }
}

WorkoutStepKind? _stepKindFromKey(String? key) {
  if (key == null || key.isEmpty) return null;
  for (final value in WorkoutStepKind.values) {
    if (value.name == key) return value;
  }
  return null;
}

int? _intFromJson(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

Duration? _durationFromJson(Object? value) {
  final milliseconds = _intFromJson(value);
  return milliseconds == null ? null : Duration(milliseconds: milliseconds);
}
