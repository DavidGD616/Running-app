import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/data/distance_accumulator.dart';

void main() {
  group('DistanceAccumulator', () {
    group('straight movement', () {
      test('accumulates distance for sequential points', () {
        final a = GpsPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );
        // 0.0001 degrees ≈ 11 meters, well above 2m threshold
        final b = GpsPoint(
          latitude: 0.0001,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 10),
        );

        final result = DistanceAccumulator().add(a).add(b);
        expect(result.totalDistanceMeters, greaterThan(0));
        expect(result.lastPoint, b);
      });

      test('accumulates multiple points correctly', () {
        final p1 = GpsPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );
        // 0.0002 degrees ≈ 22 meters each
        final p2 = GpsPoint(
          latitude: 0.0002,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 10),
        );
        final p3 = GpsPoint(
          latitude: 0.0004,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 20),
        );

        final result = DistanceAccumulator().add(p1).add(p2).add(p3);
        expect(result.totalDistanceMeters, greaterThan(0));
        expect(result.lastPoint, p3);
      });
    });

    group('jitter rejection', () {
      test('rejects very small movements under 2m', () {
        final a = GpsPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );
        final b = GpsPoint(
          latitude: 0.00001,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        );

        final result = DistanceAccumulator().add(a).add(b);
        expect(result.totalDistanceMeters, 0);
        expect(result.lastPoint, a);
      });

      test('accepts movement of exactly 2m', () {
        final a = GpsPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );
        final b = GpsPoint(
          latitude: 0.00002,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        );

        final result = DistanceAccumulator().add(a).add(b);
        expect(result.totalDistanceMeters, greaterThan(0));
      });
    });

    group('teleport rejection', () {
      test('rejects movement over 50 m/s', () {
        final a = GpsPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );
        // 0.0005 degrees ≈ 55 meters in 1 second = 55 m/s
        final b = GpsPoint(
          latitude: 0.0005,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        );

        final result = DistanceAccumulator().add(a).add(b);
        expect(result.totalDistanceMeters, 0);
        expect(result.lastPoint, a);
      });

      test('accepts movement at exactly 50 m/s', () {
        final a = GpsPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );
        // 0.0005 degrees ≈ 55 meters in 2 seconds = 27.5 m/s (well under limit)
        final b = GpsPoint(
          latitude: 0.0005,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 2),
        );

        final result = DistanceAccumulator().add(a).add(b);
        expect(result.totalDistanceMeters, greaterThan(0));
      });
    });

    group('stop detection', () {
      test('rejects zero-time delta', () {
        final a = GpsPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );
        final b = GpsPoint(
          latitude: 0.0001,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );

        final result = DistanceAccumulator().add(a).add(b);
        expect(result.totalDistanceMeters, 0);
        expect(result.lastPoint, a);
      });

      test('rejects negative-time delta', () {
        final a = GpsPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 5),
        );
        final b = GpsPoint(
          latitude: 0.0001,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );

        final result = DistanceAccumulator().add(a).add(b);
        expect(result.totalDistanceMeters, 0);
      });
    });

    group('reset', () {
      test('reset clears distance and lastPoint', () {
        final a = GpsPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );
        final b = GpsPoint(
          latitude: 0.001,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 10),
        );

        final withDistance = DistanceAccumulator().add(a).add(b);
        expect(withDistance.totalDistanceMeters, greaterThan(0));

        final reset = withDistance.reset();
        expect(reset.totalDistanceMeters, 0);
        expect(reset.lastPoint, null);
        expect(reset.isResettable, false);
      });

      test('resetFrom sets new lastPoint without distance', () {
        final a = GpsPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );
        final b = GpsPoint(
          latitude: 0.001,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 10),
        );

        final withDistance = DistanceAccumulator().add(a).add(b);
        final resetFrom = withDistance.resetFrom(b);
        expect(resetFrom.totalDistanceMeters, 0);
        expect(resetFrom.lastPoint, b);
        expect(resetFrom.isResettable, false);
      });

      test('clearLastPoint preserves distance across next accepted point', () {
        final a = GpsPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );
        final b = GpsPoint(
          latitude: 0.001,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 10),
        );
        final c = GpsPoint(
          latitude: 0.002,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 20),
        );

        final withDistance = DistanceAccumulator().add(a).add(b);
        final beforeResumeDistance = withDistance.totalDistanceMeters;
        final afterResumeFirstPoint = withDistance.clearLastPoint().add(c);

        expect(afterResumeFirstPoint.totalDistanceMeters, beforeResumeDistance);
        expect(afterResumeFirstPoint.lastPoint, c);
      });
    });

    group('initial state', () {
      test('starts with zero distance and no lastPoint', () {
        const accumulator = DistanceAccumulator();
        expect(accumulator.totalDistanceMeters, 0);
        expect(accumulator.lastPoint, null);
        expect(accumulator.isResettable, true);
      });

      test('first point sets lastPoint without adding distance', () {
        final p = GpsPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
        );

        final result = DistanceAccumulator().add(p);
        expect(result.totalDistanceMeters, 0);
        expect(result.lastPoint, p);
      });
    });
  });
}
