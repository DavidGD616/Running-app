class PaceSmoother {
  const PaceSmoother({
    this.validPoints = const [],
    this.window = const Duration(seconds: 30),
    this.minPoints = 3,
    this.minDistanceMeters = 40,
    this.maxSpeedMetersPerSecond = 8.5,
  });

  final List<PaceDataPoint> validPoints;
  final Duration window;
  final int minPoints;
  final double minDistanceMeters;
  final double maxSpeedMetersPerSecond;

  int? get currentPaceSecondsPerKm {
    if (validPoints.length < minPoints) return null;

    double totalMeters = 0;
    int totalMilliseconds = 0;

    for (final point in validPoints) {
      totalMeters += point.distanceMeters;
      totalMilliseconds += point.durationMilliseconds;
    }

    if (totalMeters < minDistanceMeters || totalMilliseconds <= 0) return null;
    final totalSeconds = totalMilliseconds / 1000.0;
    final paceSecondsPerMeter = totalSeconds / totalMeters;
    return (paceSecondsPerMeter * 1000).round();
  }

  PaceSmoother add(
    double distanceMeters,
    int durationMilliseconds, {
    DateTime? at,
  }) {
    if (distanceMeters <= 0 || durationMilliseconds <= 0) {
      return this;
    }

    final durationSeconds = durationMilliseconds / 1000.0;
    if (distanceMeters / durationSeconds > maxSpeedMetersPerSecond) {
      return this;
    }

    final endedAt =
        at ??
        (validPoints.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(durationMilliseconds)
            : validPoints.last.endedAt.add(
                Duration(milliseconds: durationMilliseconds),
              ));

    final newPoint = PaceDataPoint(
      distanceMeters: distanceMeters,
      durationMilliseconds: durationMilliseconds,
      endedAt: endedAt,
    );
    final cutoff = endedAt.subtract(window);
    final newPoints = [
      ...validPoints.where((point) => !point.endedAt.isBefore(cutoff)),
      newPoint,
    ];

    return PaceSmoother(
      validPoints: List.unmodifiable(newPoints),
      window: window,
      minPoints: minPoints,
      minDistanceMeters: minDistanceMeters,
      maxSpeedMetersPerSecond: maxSpeedMetersPerSecond,
    );
  }

  PaceSmoother reset() {
    return PaceSmoother(
      window: window,
      minPoints: minPoints,
      minDistanceMeters: minDistanceMeters,
      maxSpeedMetersPerSecond: maxSpeedMetersPerSecond,
    );
  }

  PaceSmoother resetWithInitial(
    double distanceMeters,
    int durationMilliseconds, {
    DateTime? at,
  }) {
    return reset().add(distanceMeters, durationMilliseconds, at: at);
  }
}

class PaceDataPoint {
  const PaceDataPoint({
    required this.distanceMeters,
    required this.durationMilliseconds,
    required this.endedAt,
  });

  final double distanceMeters;
  final int durationMilliseconds;
  final DateTime endedAt;
}
