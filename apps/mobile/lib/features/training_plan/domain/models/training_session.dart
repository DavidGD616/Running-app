import 'session_type.dart';

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
  });

  final String id;
  final DateTime date;
  final SessionType type;
  final SessionStatus status;
  final double? distanceKm;
  final int? durationMinutes;
  final String? description;
  final String? effortLabel;

  TrainingSession copyWith({
    String? id,
    DateTime? date,
    SessionType? type,
    SessionStatus? status,
    double? distanceKm,
    int? durationMinutes,
    String? description,
    String? effortLabel,
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
    );
  }
}
