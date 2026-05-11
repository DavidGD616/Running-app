import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/data/run_repository.dart';
import 'package:running_app/features/health_export/data/route_points_loader.dart';
import 'package:running_app/features/health_export/domain/export_route_point.dart';

void main() {
  group('toExportRoutePoints', () {
    test('maps RunRoutePoint fields to ExportRoutePoint', () {
      final now = DateTime(2024, 1, 1, 12, 0, 0);
      final points = [
        RunRoutePoint(
          runId: 'run-1',
          index: 0,
          lat: 37.7749,
          lng: -122.4194,
          accuracy: 5.0,
          altitude: 10.5,
          speed: 3.2,
          heading: 90.0,
          timestampMs: now.millisecondsSinceEpoch,
        ),
      ];

      final result = toExportRoutePoints(points);

      expect(result, hasLength(1));
      expect(
        result.first,
        ExportRoutePoint(
          lat: 37.7749,
          lng: -122.4194,
          timestamp: now,
          altitude: 10.5,
          speed: 3.2,
          horizontalAccuracy: 5.0,
          course: 90.0,
        ),
      );
    });

    test('preserves null altitude and speed', () {
      final now = DateTime(2024, 1, 1, 12, 0, 0);
      final points = [
        RunRoutePoint(
          runId: 'run-1',
          index: 0,
          lat: 37.7749,
          lng: -122.4194,
          accuracy: 5.0,
          timestampMs: now.millisecondsSinceEpoch,
        ),
      ];

      final result = toExportRoutePoints(points);

      expect(result.first.altitude, isNull);
      expect(result.first.speed, isNull);
    });

    test('sorts points by timestamp ascending', () {
      final t1 = DateTime(2024, 1, 1, 12, 0, 2);
      final t2 = DateTime(2024, 1, 1, 12, 0, 0);
      final t3 = DateTime(2024, 1, 1, 12, 0, 1);

      final points = [
        RunRoutePoint(
          runId: 'run-1',
          index: 0,
          lat: 1.0,
          lng: 1.0,
          accuracy: 5.0,
          timestampMs: t1.millisecondsSinceEpoch,
        ),
        RunRoutePoint(
          runId: 'run-1',
          index: 1,
          lat: 2.0,
          lng: 2.0,
          accuracy: 5.0,
          timestampMs: t2.millisecondsSinceEpoch,
        ),
        RunRoutePoint(
          runId: 'run-1',
          index: 2,
          lat: 3.0,
          lng: 3.0,
          accuracy: 5.0,
          timestampMs: t3.millisecondsSinceEpoch,
        ),
      ];

      final result = toExportRoutePoints(points);

      expect(result[0].timestamp, t2);
      expect(result[1].timestamp, t3);
      expect(result[2].timestamp, t1);
    });

    test('returns empty list when given empty list', () {
      final result = toExportRoutePoints([]);
      expect(result, isEmpty);
    });
  });
}
