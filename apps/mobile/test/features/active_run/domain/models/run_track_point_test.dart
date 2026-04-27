import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/domain/models/run_track_point.dart';

void main() {
  group('RunTrackPoint', () {
    late DateTime now;

    setUp(() {
      now = DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch);
    });

    RunTrackPoint samplePoint() => RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          accuracy: 5.0,
          altitude: 10.0,
          speed: 3.5,
          heading: 180.0,
          source: RunTrackPointSource.gps,
        );

    group('field values', () {
      test('stores all 8 fields correctly', () {
        final point = samplePoint();
        expect(point.latitude, 37.7749);
        expect(point.longitude, -122.4194);
        expect(point.timestamp, now);
        expect(point.accuracy, 5.0);
        expect(point.altitude, 10.0);
        expect(point.speed, 3.5);
        expect(point.heading, 180.0);
        expect(point.source, RunTrackPointSource.gps);
      });
    });

    group('toMap / fromMap round-trip', () {
      test('preserves all fields through toMap and fromMap', () {
        final original = samplePoint();
        final map = original.toMap();
        final restored = RunTrackPoint.fromMap(map);

        expect(restored.latitude, original.latitude);
        expect(restored.longitude, original.longitude);
        expect(restored.timestamp, original.timestamp);
        expect(restored.accuracy, original.accuracy);
        expect(restored.altitude, original.altitude);
        expect(restored.speed, original.speed);
        expect(restored.heading, original.heading);
        expect(restored.source, original.source);
      });

      test('restored point equals original', () {
        final original = samplePoint();
        final restored = RunTrackPoint.fromMap(original.toMap());
        expect(restored, original);
      });

      test('toMap produces correct keys', () {
        final point = samplePoint();
        final map = point.toMap();
        expect(map.keys, {
          'latitude',
          'longitude',
          'timestamp_ms',
          'accuracy',
          'altitude',
          'speed',
          'heading',
          'source',
        });
      });

      test('fromMap handles null source gracefully', () {
        final map = {
          'latitude': 37.7749,
          'longitude': -122.4194,
          'timestamp_ms': now.millisecondsSinceEpoch,
          'accuracy': 5.0,
          'altitude': 10.0,
          'speed': 3.5,
          'heading': 180.0,
          'source': null,
        };
        final point = RunTrackPoint.fromMap(map);
        expect(point.source, RunTrackPointSource.unknown);
      });
    });

    group('RunTrackPointSource.fromString', () {
      test('parses gps correctly', () {
        expect(RunTrackPointSource.fromString('gps'), RunTrackPointSource.gps);
      });

      test('parses fused correctly', () {
        expect(RunTrackPointSource.fromString('fused'), RunTrackPointSource.fused);
      });

      test('parses network correctly', () {
        expect(RunTrackPointSource.fromString('network'), RunTrackPointSource.network);
      });

      test('parses passive correctly', () {
        expect(RunTrackPointSource.fromString('passive'), RunTrackPointSource.passive);
      });

      test('parses unknown correctly', () {
        expect(RunTrackPointSource.fromString('unknown'), RunTrackPointSource.unknown);
      });

      test('falls back to unknown for invalid value', () {
        expect(RunTrackPointSource.fromString('invalid'), RunTrackPointSource.unknown);
        expect(RunTrackPointSource.fromString(''), RunTrackPointSource.unknown);
        expect(RunTrackPointSource.fromString('GPS'), RunTrackPointSource.unknown);
      });
    });

    group('equality', () {
      test('two points with same fields are equal', () {
        final point1 = samplePoint();
        final point2 = RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          accuracy: 5.0,
          altitude: 10.0,
          speed: 3.5,
          heading: 180.0,
          source: RunTrackPointSource.gps,
        );
        expect(point1, point2);
      });

      test('two points with different latitude are not equal', () {
        final point1 = samplePoint();
        final point2 = RunTrackPoint(
          latitude: 37.7750,
          longitude: -122.4194,
          timestamp: now,
          accuracy: 5.0,
          altitude: 10.0,
          speed: 3.5,
          heading: 180.0,
          source: RunTrackPointSource.gps,
        );
        expect(point1, isNot(point2));
      });

      test('two points with different source are not equal', () {
        final point1 = samplePoint();
        final point2 = RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          accuracy: 5.0,
          altitude: 10.0,
          speed: 3.5,
          heading: 180.0,
          source: RunTrackPointSource.network,
        );
        expect(point1, isNot(point2));
      });
    });

    group('hashCode', () {
      test('two equal points have same hashCode', () {
        final point1 = samplePoint();
        final point2 = RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          accuracy: 5.0,
          altitude: 10.0,
          speed: 3.5,
          heading: 180.0,
          source: RunTrackPointSource.gps,
        );
        expect(point1.hashCode, point2.hashCode);
      });

      test('two different points have different hashCode', () {
        final point1 = samplePoint();
        final point2 = RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          accuracy: 5.0,
          altitude: 10.0,
          speed: 3.5,
          heading: 180.0,
          source: RunTrackPointSource.network,
        );
        expect(point1.hashCode, isNot(point2.hashCode));
      });
    });

    group('fromPosition', () {
      test('fromPosition factory extracts correct fields', () {
        final point = RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: now,
          accuracy: 5.0,
          altitude: 10.0,
          speed: 3.5,
          heading: 180.0,
          source: RunTrackPointSource.gps,
        );
        expect(point.latitude, 37.7749);
        expect(point.longitude, -122.4194);
        expect(point.timestamp, now);
        expect(point.accuracy, 5.0);
        expect(point.altitude, 10.0);
        expect(point.speed, 3.5);
        expect(point.heading, 180.0);
        expect(point.source, RunTrackPointSource.gps);
      });
    });
  });
}
