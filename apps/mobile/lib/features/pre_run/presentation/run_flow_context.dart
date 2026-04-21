import '../../training_plan/domain/models/session_type.dart';
import '../../training_plan/domain/models/training_session.dart';
import '../../training_plan/domain/models/workout_step.dart';
import '../../training_plan/domain/models/workout_target.dart';

enum PreRunLegCondition { fresh, normal, heavy }

extension PreRunLegConditionKey on PreRunLegCondition {
  String get key => name;
}

enum PreRunPainLevel { none, mild, moderate, sharp }

extension PreRunPainLevelKey on PreRunPainLevel {
  String get key => name;
}

enum PreRunSleepLevel { great, okay, poor }

extension PreRunSleepLevelKey on PreRunSleepLevel {
  String get key => name;
}

enum PreRunReadinessLevel { letsGo, notFullyReady }

extension PreRunReadinessLevelKey on PreRunReadinessLevel {
  String get key => name;
}

class RunFlowSessionContext {
  const RunFlowSessionContext({
    required this.sessionId,
    required this.sessionDate,
    required this.sessionType,
    required this.weekNumber,
    required this.workoutTarget,
    required this.workoutSteps,
    required this.supplementalType,
    required this.isRunSession,
    required this.distanceKm,
    required this.durationMinutes,
    required this.elevationGainMeters,
    required this.intervalReps,
    required this.intervalRepDistanceMeters,
    required this.intervalRecoverySeconds,
    required this.warmUpMinutes,
    required this.coolDownMinutes,
  });

  factory RunFlowSessionContext.fromSession(TrainingSession session) {
    return RunFlowSessionContext(
      sessionId: session.id,
      sessionDate: session.date,
      sessionType: session.type,
      weekNumber: session.weekNumber,
      workoutTarget: session.workoutTarget,
      workoutSteps: List.unmodifiable(session.workoutSteps),
      supplementalType: session.supplementalType,
      isRunSession: session.isRunSession,
      distanceKm: session.distanceKm,
      durationMinutes: session.durationMinutes,
      elevationGainMeters: session.elevationGainMeters,
      intervalReps: session.intervalReps,
      intervalRepDistanceMeters: session.intervalRepDistanceMeters,
      intervalRecoverySeconds: session.intervalRecoverySeconds,
      warmUpMinutes: session.warmUpMinutes,
      coolDownMinutes: session.coolDownMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'sessionDate': sessionDate.toIso8601String(),
      'sessionType': sessionType.name,
      'weekNumber': weekNumber,
      'workoutTarget': workoutTarget?.toJson(),
      'workoutSteps': workoutSteps.map((s) => s.toJson()).toList(),
      'supplementalType': supplementalType?.key,
      'isRunSession': isRunSession,
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'elevationGainMeters': elevationGainMeters,
      'intervalReps': intervalReps,
      'intervalRepDistanceMeters': intervalRepDistanceMeters,
      'intervalRecoverySeconds': intervalRecoverySeconds,
      'warmUpMinutes': warmUpMinutes,
      'coolDownMinutes': coolDownMinutes,
    };
  }

  factory RunFlowSessionContext.fromJson(Map<String, dynamic> json) {
    final sessionTypeRaw = json['sessionType'] as String?;
    final sessionType = sessionTypeRaw != null
        ? SessionType.values.cast<SessionType?>().firstWhere(
              (e) => e?.name == sessionTypeRaw,
              orElse: () => null,
            )
        : null;
    if (sessionType == null) {
      throw FormatException('Invalid or missing sessionType in JSON: $sessionTypeRaw');
    }
    return RunFlowSessionContext(
      sessionId: json['sessionId'] as String,
      sessionDate: DateTime.parse(json['sessionDate'] as String),
      sessionType: sessionType,
      weekNumber: json['weekNumber'] as int? ?? 1,
      workoutTarget: json['workoutTarget'] != null
          ? WorkoutTarget.fromJson(json['workoutTarget'] as Map<String, dynamic>)
          : null,
      workoutSteps: (json['workoutSteps'] as List?)
              ?.map((s) => WorkoutStep.fromJson(s as Map<String, dynamic>))
              .whereType<WorkoutStep>()
              .toList() ??
          [],
      supplementalType: supplementalSessionTypeFromKey(
          json['supplementalType'] as String?),
      isRunSession: json['isRunSession'] as bool? ?? true,
      distanceKm: _doubleOrNull(json['distanceKm']),
      durationMinutes: json['durationMinutes'] as int?,
      elevationGainMeters: json['elevationGainMeters'] as int?,
      intervalReps: json['intervalReps'] as int?,
      intervalRepDistanceMeters: json['intervalRepDistanceMeters'] as int?,
      intervalRecoverySeconds: json['intervalRecoverySeconds'] as int?,
      warmUpMinutes: json['warmUpMinutes'] as int?,
      coolDownMinutes: json['coolDownMinutes'] as int?,
    );
  }

  final String sessionId;
  final DateTime sessionDate;
  final SessionType sessionType;
  final int weekNumber;
  final WorkoutTarget? workoutTarget;
  final List<WorkoutStep> workoutSteps;
  final SupplementalSessionType? supplementalType;
  final bool isRunSession;
  final double? distanceKm;
  final int? durationMinutes;
  final int? elevationGainMeters;
  final int? intervalReps;
  final int? intervalRepDistanceMeters;
  final int? intervalRecoverySeconds;
  final int? warmUpMinutes;
  final int? coolDownMinutes;

  bool get isRest => sessionType.isRest;
  bool get hasStructuredWorkout =>
      workoutTarget != null || workoutSteps.isNotEmpty;
}

class PreRunCheckIn {
  const PreRunCheckIn({
    required this.legs,
    required this.pain,
    required this.sleep,
    required this.readiness,
  });

  final PreRunLegCondition? legs;
  final PreRunPainLevel? pain;
  final PreRunSleepLevel? sleep;
  final PreRunReadinessLevel? readiness;

  Map<String, dynamic> toJson() {
    return {
      'legs': legs?.key,
      'pain': pain?.key,
      'sleep': sleep?.key,
      'readiness': readiness?.key,
    };
  }

  factory PreRunCheckIn.fromJson(Map<String, dynamic> json) {
    return PreRunCheckIn(
      legs: _enumFromKey(PreRunLegCondition.values, json['legs']),
      pain: _enumFromKey(PreRunPainLevel.values, json['pain']),
      sleep: _enumFromKey(PreRunSleepLevel.values, json['sleep']),
      readiness: _enumFromKey(PreRunReadinessLevel.values, json['readiness']),
    );
  }
}

class PreRunArgs {
  const PreRunArgs({required this.session});

  factory PreRunArgs.fromSession(TrainingSession session) {
    return PreRunArgs(session: RunFlowSessionContext.fromSession(session));
  }

  final RunFlowSessionContext session;
}

class ActiveRunArgs {
  const ActiveRunArgs({required this.session, this.checkIn});

  final RunFlowSessionContext? session;
  final PreRunCheckIn? checkIn;
}

class LogRunArgs {
  const LogRunArgs({
    required this.session,
    this.checkIn,
    this.actualDuration,
    this.actualDistanceKm,
  });

  final RunFlowSessionContext? session;
  final PreRunCheckIn? checkIn;
  final Duration? actualDuration;
  final double? actualDistanceKm;
}

T? _enumFromKey<T extends Enum>(List<T> values, Object? raw) {
  final key = raw as String?;
  if (key == null || key.isEmpty) return null;
  for (final value in values) {
    if (value.name == key) return value;
  }
  return null;
}

double? _doubleOrNull(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
