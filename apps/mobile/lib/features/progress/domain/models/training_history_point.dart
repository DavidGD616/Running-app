enum TrainingHistoryRange { week, month, threeMonths, sixMonths, year, all }

class TrainingHistoryPoint {
  const TrainingHistoryPoint({
    required this.startDate,
    required this.endDate,
    required this.label,
    required this.distanceKm,
    required this.durationMinutes,
    required this.elevationMeters,
    this.isCurrent = false,
    this.isBest = false,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String label;
  final double distanceKm;
  final int durationMinutes;
  final int elevationMeters;
  final bool isCurrent;
  final bool isBest;

  int get timeHours => durationMinutes ~/ 60;
  int get timeMinutes => durationMinutes % 60;

  TrainingHistoryPoint copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? label,
    double? distanceKm,
    int? durationMinutes,
    int? elevationMeters,
    bool? isCurrent,
    bool? isBest,
  }) {
    return TrainingHistoryPoint(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      label: label ?? this.label,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      elevationMeters: elevationMeters ?? this.elevationMeters,
      isCurrent: isCurrent ?? this.isCurrent,
      isBest: isBest ?? this.isBest,
    );
  }
}
