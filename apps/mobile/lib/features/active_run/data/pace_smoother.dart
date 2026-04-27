class PaceSmoother {
  const PaceSmoother({
    this.validPoints = const [],
  });

  static const int _windowSize = 5;

  final List<PaceDataPoint> validPoints;

  int? get currentPaceSecondsPerKm {
    if (validPoints.length < _windowSize) return null;
    final window = validPoints.length == _windowSize
        ? validPoints
        : validPoints.sublist(validPoints.length - _windowSize);

    double totalMeters = 0;
    int totalMilliseconds = 0;

    for (final point in window) {
      totalMeters += point.distanceMeters;
      totalMilliseconds += point.durationMilliseconds;
    }

    if (totalMeters <= 0) return null;
    final totalSeconds = totalMilliseconds / 1000.0;
    final paceSecondsPerMeter = totalSeconds / totalMeters;
    return (paceSecondsPerMeter * 1000).round();
  }

  PaceSmoother add(double distanceMeters, int durationMilliseconds) {
    if (distanceMeters <= 0 || durationMilliseconds <= 0) {
      return this;
    }

    final newPoint = PaceDataPoint(
      distanceMeters: distanceMeters,
      durationMilliseconds: durationMilliseconds,
    );

    final newPoints = [...validPoints, newPoint];
    return PaceSmoother(validPoints: newPoints);
  }

  PaceSmoother reset() {
    return const PaceSmoother(validPoints: []);
  }

  PaceSmoother resetWithInitial(double distanceMeters, int durationMilliseconds) {
    if (distanceMeters <= 0 || durationMilliseconds <= 0) {
      return const PaceSmoother(validPoints: []);
    }
    return PaceSmoother(
      validPoints: [
        PaceDataPoint(
          distanceMeters: distanceMeters,
          durationMilliseconds: durationMilliseconds,
        )
      ],
    );
  }
}

class PaceDataPoint {
  const PaceDataPoint({
    required this.distanceMeters,
    required this.durationMilliseconds,
  });

  final double distanceMeters;
  final int durationMilliseconds;
}
