import 'session_type.dart';

enum WorkoutPhaseType { warmUp, main, coolDown }

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
    this.distanceKm,
    this.durationMinutes,
    this.description,
    this.effortLabel,
    this.phases = const [],
    this.intervalReps,
    this.intervalRepDistance,
    this.intervalRecoverySeconds,
  });

  final String id;
  final DateTime date;
  final SessionType type;
  final SessionStatus status;
  final double? distanceKm;
  final int? durationMinutes;
  final String? description;
  final String? effortLabel;
  final List<WorkoutPhase> phases;
  final int? intervalReps;
  final String? intervalRepDistance;
  final int? intervalRecoverySeconds;

  TrainingSession copyWith({
    String? id,
    DateTime? date,
    SessionType? type,
    SessionStatus? status,
    double? distanceKm,
    int? durationMinutes,
    String? description,
    String? effortLabel,
    List<WorkoutPhase>? phases,
    int? intervalReps,
    String? intervalRepDistance,
    int? intervalRecoverySeconds,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      status: status ?? this.status,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      description: description ?? this.description,
      effortLabel: effortLabel ?? this.effortLabel,
      phases: phases ?? this.phases,
      intervalReps: intervalReps ?? this.intervalReps,
      intervalRepDistance: intervalRepDistance ?? this.intervalRepDistance,
      intervalRecoverySeconds: intervalRecoverySeconds ?? this.intervalRecoverySeconds,
    );
  }
}
