class WeeklyVolumeData {
  const WeeklyVolumeData({
    required this.distanceKm,
    required this.timeHours,
    required this.timeMinutes,
    required this.elevationMeters,
    this.dateRange,
  });

  final double distanceKm;
  final int timeHours;
  final int timeMinutes;
  final int elevationMeters;

  /// Human-readable date range, e.g. 'MAR 16 - MAR 22'.
  /// Null for the current (most recent) week.
  final String? dateRange;

  bool get isCurrentWeek => dateRange == null;
}
