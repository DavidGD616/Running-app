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
