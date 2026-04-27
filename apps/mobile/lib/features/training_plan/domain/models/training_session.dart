import 'model_json_utils.dart';
import 'session_type.dart';
import 'workout_step.dart';
import 'workout_target.dart';

enum WorkoutPhaseType { warmUp, main, coolDown }

enum TrainingSessionEffort { easy, moderate, hard, veryEasy }

class WorkoutPhase {
  const WorkoutPhase({
    required this.type,
    required this.iconAsset,
    required this.title,
    required this.duration,
    required this.note,
    this.recoveryNote,
  });

  final WorkoutPhaseType type;
  final String iconAsset;
  final String title;
  final String duration;
  final String note;
  final String? recoveryNote;
}

class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.date,
    required this.type,
    required this.status,
    this.weekNumber = 1,
    this.phase,
    this.distanceKm,
    this.durationMinutes,
    this.description,
    this.effort,
    this.phases = const [],
    this.workoutTarget,
    this.workoutSteps = const [],
    this.supplementalType,
    this.elevationGainMeters,
    this.intervalReps,
    this.intervalRepDistanceMeters,
    this.intervalRecoverySeconds,
    this.warmUpMinutes,
    this.coolDownMinutes,
  });

  final String id;
  final DateTime date;
  final SessionType type;
  final SessionStatus status;
  final int weekNumber;
  final String? phase;
  final double? distanceKm;
  final int? durationMinutes;
  final String? description;
  final TrainingSessionEffort? effort;
  final List<WorkoutPhase> phases;
  final WorkoutTarget? workoutTarget;
  final List<WorkoutStep> workoutSteps;
  final SupplementalSessionType? supplementalType;
  final int? elevationGainMeters;
  final int? intervalReps;
  final int? intervalRepDistanceMeters;
  final int? intervalRecoverySeconds;
  final int? warmUpMinutes;
  final int? coolDownMinutes;

  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'date': dateTimeToJson(date),
        'type': type.name,
        'status': status.name,
        'weekNumber': weekNumber,
        'phase': phase,
        'distanceKm': distanceKm,
        'durationMinutes': durationMinutes,
        'description': description,
        'effort': effort?.name,
        'workoutTarget': workoutTarget?.toJson(),
        'workoutSteps': workoutSteps.map((s) => s.toJson()).toList(),
        'supplementalType': supplementalType?.key,
        'elevationGainMeters': elevationGainMeters,
        'intervalReps': intervalReps,
        'intervalRepDistanceMeters': intervalRepDistanceMeters,
        'intervalRecoverySeconds': intervalRecoverySeconds,
        'warmUpMinutes': warmUpMinutes,
        'coolDownMinutes': coolDownMinutes,
        // phases intentionally excluded — rebuilt from structural fields
      };

  static TrainingSession? fromJson(Map<String, dynamic> json) {
    final id = stringOrNull(json['id']);
    final date = dateTimeFromJson(json['date']);
    final type = _sessionTypeFromName(stringOrNull(json['type']));
    final status = _sessionStatusFromName(stringOrNull(json['status'])) ??
        _deriveStatus(date);
    if (id == null || id.isEmpty || date == null || type == null) {
      return null;
    }

    final rawSteps = json['workoutSteps'];
    final workoutSteps = <WorkoutStep>[];
    if (rawSteps is List) {
      for (final item in rawSteps) {
        if (item is Map<String, dynamic>) {
          final step = WorkoutStep.fromJson(item);
          if (step != null) workoutSteps.add(step);
        }
      }
    }

    WorkoutTarget? workoutTarget;
    final rawTarget = json['workoutTarget'];
    if (rawTarget is Map<String, dynamic>) {
      workoutTarget = WorkoutTarget.fromJson(rawTarget);
    }

    return TrainingSession(
      id: id,
      date: date,
      type: type,
      status: status,
      weekNumber: intOrNull(json['weekNumber']) ?? 1,
      phase: stringOrNull(json['phase']),
      distanceKm: _doubleOrNull(json['distanceKm']),
      durationMinutes: intOrNull(json['durationMinutes']),
      description: stringOrNull(json['description']),
      effort: _effortFromName(stringOrNull(json['effort'])),
      workoutTarget: workoutTarget,
      workoutSteps: workoutSteps,
      supplementalType: supplementalSessionTypeFromKey(
          stringOrNull(json['supplementalType'])),
      elevationGainMeters: intOrNull(json['elevationGainMeters']),
      intervalReps: intOrNull(json['intervalReps']),
      intervalRepDistanceMeters: intOrNull(json['intervalRepDistanceMeters']),
      intervalRecoverySeconds: intOrNull(json['intervalRecoverySeconds']),
      warmUpMinutes: intOrNull(json['warmUpMinutes']),
      coolDownMinutes: intOrNull(json['coolDownMinutes']),
      // phases always empty on deserialization — rebuilt from structural fields
    );
  }

  bool get hasStructuredWorkout =>
      workoutTarget != null || workoutSteps.isNotEmpty;

  bool get isSupportSession => supplementalType != null;

  bool get isRunSession => !isSupportSession && type.isRunSession;

  bool get countsAsRun => !isSupportSession && type.countsAsRun;

  SessionCategory get category =>
      isSupportSession ? SessionCategory.recovery : type.category;

  TrainingSession copyWith({
    String? id,
    DateTime? date,
    SessionType? type,
    SessionStatus? status,
    int? weekNumber,
    String? phase,
    double? distanceKm,
    int? durationMinutes,
    String? description,
    TrainingSessionEffort? effort,
    List<WorkoutPhase>? phases,
    WorkoutTarget? workoutTarget,
    List<WorkoutStep>? workoutSteps,
    SupplementalSessionType? supplementalType,
    int? elevationGainMeters,
    int? intervalReps,
    int? intervalRepDistanceMeters,
    int? intervalRecoverySeconds,
    int? warmUpMinutes,
    int? coolDownMinutes,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      status: status ?? this.status,
      weekNumber: weekNumber ?? this.weekNumber,
      phase: phase ?? this.phase,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      description: description ?? this.description,
      effort: effort ?? this.effort,
      phases: phases ?? this.phases,
      workoutTarget: workoutTarget ?? this.workoutTarget,
      workoutSteps: workoutSteps ?? this.workoutSteps,
      supplementalType: supplementalType ?? this.supplementalType,
      elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
      intervalReps: intervalReps ?? this.intervalReps,
      intervalRepDistanceMeters:
          intervalRepDistanceMeters ?? this.intervalRepDistanceMeters,
      intervalRecoverySeconds:
          intervalRecoverySeconds ?? this.intervalRecoverySeconds,
      warmUpMinutes: warmUpMinutes ?? this.warmUpMinutes,
      coolDownMinutes: coolDownMinutes ?? this.coolDownMinutes,
    );
  }
}

SessionType? _sessionTypeFromName(String? name) {
  if (name == null || name.isEmpty) return null;
  for (final v in SessionType.values) {
    if (v.name == name) return v;
  }
  return null;
}

SessionStatus? _sessionStatusFromName(String? name) {
  if (name == null || name.isEmpty) return null;
  for (final v in SessionStatus.values) {
    if (v.name == name) return v;
  }
  return null;
}

SessionStatus _deriveStatus(DateTime? date) {
  if (date == null) return SessionStatus.upcoming;
  final today = DateTime.now();
  final sessionDay = DateTime(date.year, date.month, date.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  if (sessionDay == todayDay) return SessionStatus.today;
  return SessionStatus.upcoming;
}

TrainingSessionEffort? _effortFromName(String? name) {
  if (name == null || name.isEmpty) return null;
  for (final v in TrainingSessionEffort.values) {
    if (v.name == name) return v;
  }
  return null;
}

double? _doubleOrNull(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
