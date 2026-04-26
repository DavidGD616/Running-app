import 'package:geolocator/geolocator.dart';

class GpsPoint {
  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  factory GpsPoint.fromPosition(Position position) {
    return GpsPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
    );
  }

  @override
  String toString() =>
      'GpsPoint(lat: $latitude, lng: $longitude, ts: $timestamp)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GpsPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(latitude, longitude, timestamp);
}

class DistanceAccumulator {
  const DistanceAccumulator({
    this.totalDistanceMeters = 0,
    this.lastPoint,
    this.isResettable = true,
  });

  final double totalDistanceMeters;
  final GpsPoint? lastPoint;
  final bool isResettable;

  static const double _minDeltaMeters = 2.0;
  static const double _maxSpeedMetersPerSecond = 50.0;

  DistanceAccumulator add(GpsPoint point) {
    final last = lastPoint;
    if (last == null) {
      return DistanceAccumulator(
        totalDistanceMeters: totalDistanceMeters,
        lastPoint: point,
        isResettable: true,
      );
    }

    final deltaMeters = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      point.latitude,
      point.longitude,
    );

    if (deltaMeters < _minDeltaMeters) {
      return DistanceAccumulator(
        totalDistanceMeters: totalDistanceMeters,
        lastPoint: last,
        isResettable: true,
      );
    }

    final deltaSeconds =
        point.timestamp.difference(last.timestamp).inMilliseconds / 1000.0;
    if (deltaSeconds <= 0) {
      return DistanceAccumulator(
        totalDistanceMeters: totalDistanceMeters,
        lastPoint: last,
        isResettable: true,
      );
    }

    final speedMps = deltaMeters / deltaSeconds;
    if (speedMps > _maxSpeedMetersPerSecond) {
      return DistanceAccumulator(
        totalDistanceMeters: totalDistanceMeters,
        lastPoint: last,
        isResettable: true,
      );
    }

    return DistanceAccumulator(
      totalDistanceMeters: totalDistanceMeters + deltaMeters,
      lastPoint: point,
      isResettable: true,
    );
  }

  DistanceAccumulator reset() {
    return const DistanceAccumulator(
      totalDistanceMeters: 0,
      lastPoint: null,
      isResettable: false,
    );
  }

  DistanceAccumulator resetFrom(GpsPoint point) {
    return DistanceAccumulator(
      totalDistanceMeters: 0,
      lastPoint: point,
      isResettable: false,
    );
  }

  DistanceAccumulator clearLastPoint() {
    return DistanceAccumulator(
      totalDistanceMeters: totalDistanceMeters,
      lastPoint: null,
      isResettable: true,
    );
  }
}
