import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:running_app/features/active_run/domain/models/run_track_point.dart';

void main() {
  group('RunTrackPoint', () {
    test('toMap and fromMap round-trip preserves all fields', () {
      final original = RunTrackPoint(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime(2026, 4, 25, 10, 30, 0),
        accuracy: 5.0,
        altitude: 10.5,
        speed: 3.5,
        heading: 180.0,
        source: RunTrackPointSource.gps,
      );

      final map = original.toMap();
      final restored = RunTrackPoint.fromMap(map);

      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.timestamp.millisecondsSinceEpoch,
          original.timestamp.millisecondsSinceEpoch);
      expect(restored.accuracy, original.accuracy);
      expect(restored.altitude, original.altitude);
      expect(restored.speed, original.speed);
      expect(restored.heading, original.heading);
      expect(restored.source, original.source);
    });

    test('fromPosition creates RunTrackPoint with correct values', () {
      final position = Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime(2026, 4, 25, 10, 30, 0),
        accuracy: 5.0,
        altitude: 10.5,
        altitudeAccuracy: 2.0,
        heading: 180.0,
        headingAccuracy: 5.0,
        speed: 3.5,
        speedAccuracy: 1.0,
        floor: null,
        isMocked: false,
      );

      final point = RunTrackPoint.fromPosition(position);

      expect(point.latitude, position.latitude);
      expect(point.longitude, position.longitude);
      expect(point.timestamp, position.timestamp);
      expect(point.accuracy, position.accuracy);
      expect(point.altitude, position.altitude);
      expect(point.speed, position.speed);
      expect(point.heading, position.heading);
    });

    test('equality works correctly', () {
      final timestamp = DateTime(2026, 4, 25, 10, 30, 0);
      final point1 = RunTrackPoint(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: timestamp,
        accuracy: 5.0,
        altitude: 10.5,
        speed: 3.5,
        heading: 180.0,
        source: RunTrackPointSource.gps,
      );
      final point2 = RunTrackPoint(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: timestamp,
        accuracy: 5.0,
        altitude: 10.5,
        speed: 3.5,
        heading: 180.0,
        source: RunTrackPointSource.gps,
      );

      expect(point1, equals(point2));
      expect(point1.hashCode, equals(point2.hashCode));
    });

    test('different points are not equal', () {
      final timestamp = DateTime(2026, 4, 25, 10, 30, 0);
      final point1 = RunTrackPoint(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: timestamp,
        accuracy: 5.0,
        altitude: 10.5,
        speed: 3.5,
        heading: 180.0,
        source: RunTrackPointSource.gps,
      );
      final point2 = RunTrackPoint(
        latitude: 37.7750,
        longitude: -122.4194,
        timestamp: timestamp,
        accuracy: 5.0,
        altitude: 10.5,
        speed: 3.5,
        heading: 180.0,
        source: RunTrackPointSource.gps,
      );

      expect(point1, isNot(equals(point2)));
    });

    test('RunTrackPointSource fromString handles unknown values', () {
      expect(RunTrackPointSource.fromString('gps'), RunTrackPointSource.gps);
      expect(RunTrackPointSource.fromString('unknown'), RunTrackPointSource.unknown);
      expect(RunTrackPointSource.fromString('invalid'), RunTrackPointSource.unknown);
    });
  });
}
