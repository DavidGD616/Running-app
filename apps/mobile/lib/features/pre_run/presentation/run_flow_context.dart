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

class LogRunArgs {
  const LogRunArgs({required this.session, this.checkIn});

  final RunFlowSessionContext? session;
  final PreRunCheckIn? checkIn;
}

T? _enumFromKey<T extends Enum>(List<T> values, Object? raw) {
  final key = raw as String?;
  if (key == null || key.isEmpty) return null;
  for (final value in values) {
    if (value.name == key) return value;
  }
  return null;
}
