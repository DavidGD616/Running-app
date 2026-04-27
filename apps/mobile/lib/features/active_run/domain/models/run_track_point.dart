import 'package:geolocator/geolocator.dart';

enum RunTrackPointSource {
  gps,
  fused,
  network,
  passive,
  unknown;

  static RunTrackPointSource fromPosition(Position position) {
    return unknown;
  }

  static RunTrackPointSource fromString(String value) {
    return RunTrackPointSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RunTrackPointSource.unknown,
    );
  }
}

class RunTrackPoint {
  const RunTrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.altitude,
    required this.speed,
    required this.heading,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double altitude;
  final double speed;
  final double heading;
  final RunTrackPointSource source;

  factory RunTrackPoint.fromPosition(Position position) {
    return RunTrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      source: RunTrackPointSource.fromPosition(position),
    );
  }

  factory RunTrackPoint.fromMap(Map<String, dynamic> map) {
    return RunTrackPoint(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp_ms'] as num).toInt(),
      ),
      accuracy: (map['accuracy'] as num).toDouble(),
      altitude: (map['altitude'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      heading: (map['heading'] as num).toDouble(),
      source: RunTrackPointSource.fromString(
        (map['source'] as String?) ?? 'unknown',
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp_ms': timestamp.millisecondsSinceEpoch,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'source': source.name,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RunTrackPoint &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.timestamp == timestamp &&
        other.accuracy == accuracy &&
        other.altitude == altitude &&
        other.speed == speed &&
        other.heading == heading &&
        other.source == source;
  }

  @override
  int get hashCode {
    return Object.hash(
      latitude,
      longitude,
      timestamp,
      accuracy,
      altitude,
      speed,
      heading,
      source,
    );
  }
}
