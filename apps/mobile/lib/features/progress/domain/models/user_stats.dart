class UserStats {
  const UserStats({
    required this.streakWeeks,
    required this.totalDistanceKm,
    required this.totalTimeMinutes,
    required this.totalRuns,
    required this.avgPacePerKm,
    required this.distanceTrendPct,
    required this.timeTrendPct,
    required this.longestRunKm,
    required this.longestRunImprovementKm,
  });

  final int streakWeeks;
  final double totalDistanceKm;
  final int totalTimeMinutes;
  final int totalRuns;

  /// Formatted pace string, e.g. '6:15'.
  final String avgPacePerKm;

  /// Percentage change vs previous period, e.g. 14.0 means +14%.
  final double distanceTrendPct;
  final double timeTrendPct;

  final double longestRunKm;

  /// How many km longer the longest run is vs the previous personal best.
  final double longestRunImprovementKm;

  int get totalTimeHours => totalTimeMinutes ~/ 60;
  int get totalTimeRemainingMinutes => totalTimeMinutes % 60;
}
