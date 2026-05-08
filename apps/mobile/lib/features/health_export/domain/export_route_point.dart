import 'package:flutter/foundation.dart';

@immutable
class ExportRoutePoint {
  const ExportRoutePoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.altitude,
    this.speed,
    this.horizontalAccuracy,
    this.course,
  });

  final double lat;
  final double lng;
  final DateTime timestamp;
  final double? altitude;
  final double? speed;

  /// Horizontal positional accuracy in metres (sourced from
  /// `RunRoutePoint.accuracy`). Maps to HealthKit's `horizontalAccuracy`.
  final double? horizontalAccuracy;

  /// Bearing in degrees (sourced from `RunRoutePoint.heading`).
  /// Maps to HealthKit's `course` (iOS only).
  final double? course;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportRoutePoint &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng &&
          timestamp == other.timestamp &&
          altitude == other.altitude &&
          speed == other.speed &&
          horizontalAccuracy == other.horizontalAccuracy &&
          course == other.course;

  @override
  int get hashCode => Object.hash(
    lat,
    lng,
    timestamp,
    altitude,
    speed,
    horizontalAccuracy,
    course,
  );

  @override
  String toString() {
    return 'ExportRoutePoint(lat: $lat, lng: $lng, timestamp: $timestamp, '
        'altitude: $altitude, speed: $speed, '
        'horizontalAccuracy: $horizontalAccuracy, course: $course)';
  }
}
