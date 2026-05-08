import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/health_export/data/health_export_service.dart';
import 'package:running_app/features/health_export/domain/export_route_point.dart';
import 'package:running_app/features/health_export/domain/health_export_result.dart';
import 'package:running_app/features/health_export/domain/health_export_types.dart';
import '../fakes/fake_health_client.dart';

void main() {
  group('HealthExportService', () {
    late FakeHealthClient fakeClient;
    late HealthExportService service;

    setUp(() {
      fakeClient = FakeHealthClient();
      service = HealthExportService(client: fakeClient);
    });

    group('requestAuthorization', () {
      test('returns true on success', () async {
        fakeClient.requestAuthorizationReturn = true;

        final result = await service.requestAuthorization();

        expect(result, isTrue);
        expect(fakeClient.configureCallCount, 1);
        expect(fakeClient.requestAuthorizationCallCount, 1);
        expect(
          fakeClient.lastRequestAuthorizationTypes,
          [
            HealthExportDataType.workout,
            HealthExportDataType.workoutRoute,
          ],
        );
        expect(
          fakeClient.lastRequestAuthorizationPermissions,
          [
            HealthExportAccess.readWrite,
            HealthExportAccess.readWrite,
          ],
        );
      });

      test('returns false on exception', () async {
        fakeClient.throwPlatformException = true;

        final result = await service.requestAuthorization();

        expect(result, isFalse);
      });
    });

    group('exportRun', () {
      final start = DateTime(2024, 1, 1, 12, 0, 0);
      final end = DateTime(2024, 1, 1, 12, 30, 0);
      const distanceKm = 5.0;

      final routePoints = [
        ExportRoutePoint(
          lat: 37.7749,
          lng: -122.4194,
          timestamp: start,
          altitude: 10.0,
          speed: 3.5,
        ),
        ExportRoutePoint(
          lat: 37.7750,
          lng: -122.4195,
          timestamp: start.add(const Duration(seconds: 10)),
          altitude: 11.0,
          speed: 3.6,
        ),
      ];

      HealthExportWorkout mockWorkout({
        required String uuid,
        DateTime? startOverride,
        DateTime? endOverride,
        HealthExportActivityType activityType =
            HealthExportActivityType.running,
      }) {
        return HealthExportWorkout(
          uuid: uuid,
          activityType: activityType,
          start: startOverride ?? start,
          end: endOverride ?? end,
        );
      }

      test('with route points succeeds', () async {
        fakeClient.startWorkoutRouteReturn = 'builder-123';
        fakeClient.insertWorkoutRouteDataReturn = true;
        fakeClient.writeWorkoutDataReturn = true;
        fakeClient.getWorkoutDataReturn = [
          mockWorkout(uuid: 'workout-uuid-789'),
        ];
        fakeClient.finishWorkoutRouteReturn = 'route-456';

        final result = await service.exportRun(
          start: start,
          end: end,
          distanceKm: distanceKm,
          routePoints: routePoints,
        );

        expect(result, isA<HealthExportSuccess>());
        expect(fakeClient.startWorkoutRouteCallCount, 1);
        expect(fakeClient.insertWorkoutRouteDataCallCount, 1);
        expect(fakeClient.writeWorkoutDataCallCount, 1);
        expect(fakeClient.getWorkoutDataCallCount, 1);
        expect(fakeClient.finishWorkoutRouteCallCount, 1);
        expect(fakeClient.discardWorkoutRouteCallCount, 0);

        expect(fakeClient.lastInsertWorkoutRouteDataBuilderId, 'builder-123');
        expect(fakeClient.lastInsertWorkoutRouteDataLocations, hasLength(2));
        expect(fakeClient.lastFinishWorkoutRouteBuilderId, 'builder-123');
        expect(fakeClient.lastFinishWorkoutRouteWorkoutUuid, 'workout-uuid-789');
        expect(
          fakeClient.lastFinishWorkoutRouteMetadata,
          {'source': 'RunFlow'},
        );
        expect(
          fakeClient.lastWriteWorkoutDataActivityType,
          HealthExportActivityType.running,
        );
        expect(fakeClient.lastWriteWorkoutDataStart, start);
        expect(fakeClient.lastWriteWorkoutDataEnd, end);
        expect(fakeClient.lastWriteWorkoutDataTotalDistanceMeters, 5000);
      });

      test('without route points succeeds', () async {
        fakeClient.writeWorkoutDataReturn = true;

        final result = await service.exportRun(
          start: start,
          end: end,
          distanceKm: distanceKm,
        );

        expect(result, isA<HealthExportSuccess>());
        expect(fakeClient.startWorkoutRouteCallCount, 0);
        expect(fakeClient.insertWorkoutRouteDataCallCount, 0);
        expect(fakeClient.writeWorkoutDataCallCount, 1);
        expect(fakeClient.getWorkoutDataCallCount, 0);
        expect(fakeClient.finishWorkoutRouteCallCount, 0);
        expect(fakeClient.discardWorkoutRouteCallCount, 0);

        expect(fakeClient.lastWriteWorkoutDataTotalDistanceMeters, 5000);
      });

      test(
        'returns failure when insertWorkoutRouteData fails',
        () async {
          fakeClient.startWorkoutRouteReturn = 'builder-123';
          fakeClient.insertWorkoutRouteDataReturn = false;

          final result = await service.exportRun(
            start: start,
            end: end,
            distanceKm: distanceKm,
            routePoints: routePoints,
          );

          expect(result, isA<HealthExportFailure>());
          expect(
            (result as HealthExportFailure).reason,
            'Failed to insert workout route data',
          );
          expect(fakeClient.discardWorkoutRouteCallCount, 1);
          expect(fakeClient.lastDiscardWorkoutRouteBuilderId, 'builder-123');
          expect(fakeClient.writeWorkoutDataCallCount, 0);
        },
      );

      test('returns failure when writeWorkoutData fails', () async {
        fakeClient.writeWorkoutDataReturn = false;

        final result = await service.exportRun(
          start: start,
          end: end,
          distanceKm: distanceKm,
        );

        expect(result, isA<HealthExportFailure>());
        expect(
          (result as HealthExportFailure).reason,
          'Failed to write workout data',
        );
        expect(fakeClient.writeWorkoutDataCallCount, 1);
      });

      test(
        'returns failure when writeWorkoutData fails with route points',
        () async {
          fakeClient.startWorkoutRouteReturn = 'builder-123';
          fakeClient.insertWorkoutRouteDataReturn = true;
          fakeClient.writeWorkoutDataReturn = false;

          final result = await service.exportRun(
            start: start,
            end: end,
            distanceKm: distanceKm,
            routePoints: routePoints,
          );

          expect(result, isA<HealthExportFailure>());
          expect(
            (result as HealthExportFailure).reason,
            'Failed to write workout data',
          );
          expect(fakeClient.writeWorkoutDataCallCount, 1);
          expect(fakeClient.discardWorkoutRouteCallCount, 1);
          expect(fakeClient.lastDiscardWorkoutRouteBuilderId, 'builder-123');
        },
      );

      test(
        'returns failure when workout query returns no running matches',
        () async {
          fakeClient.startWorkoutRouteReturn = 'builder-123';
          fakeClient.insertWorkoutRouteDataReturn = true;
          fakeClient.writeWorkoutDataReturn = true;
          fakeClient.getWorkoutDataReturn = [];

          final result = await service.exportRun(
            start: start,
            end: end,
            distanceKm: distanceKm,
            routePoints: routePoints,
          );

          expect(result, isA<HealthExportFailure>());
          expect(
            (result as HealthExportFailure).reason,
            'Workout UUID not found after write',
          );
          expect(fakeClient.discardWorkoutRouteCallCount, 1);
          expect(fakeClient.lastDiscardWorkoutRouteBuilderId, 'builder-123');
        },
      );

      test(
        'picks the most recent running workout when multiple candidates fall '
        'within the lookup window',
        () async {
          fakeClient.startWorkoutRouteReturn = 'builder-123';
          fakeClient.insertWorkoutRouteDataReturn = true;
          fakeClient.writeWorkoutDataReturn = true;
          // Two running workouts within ±5s; the one whose start is closest
          // (here equal to `start`, the latest) should win.
          fakeClient.getWorkoutDataReturn = [
            mockWorkout(
              uuid: 'older-running',
              startOverride: start.subtract(const Duration(seconds: 4)),
              endOverride: end.subtract(const Duration(seconds: 4)),
            ),
            mockWorkout(uuid: 'just-written-running'),
          ];

          final result = await service.exportRun(
            start: start,
            end: end,
            distanceKm: distanceKm,
            routePoints: routePoints,
          );

          expect(result, isA<HealthExportSuccess>());
          expect(fakeClient.finishWorkoutRouteCallCount, 1);
          expect(
            fakeClient.lastFinishWorkoutRouteWorkoutUuid,
            'just-written-running',
          );
          expect(fakeClient.discardWorkoutRouteCallCount, 0);
        },
      );

      test(
        'returns failure when workout falls outside lookup window',
        () async {
          fakeClient.startWorkoutRouteReturn = 'builder-123';
          fakeClient.insertWorkoutRouteDataReturn = true;
          fakeClient.writeWorkoutDataReturn = true;
          // Workout at +30s is outside the ±5s lookup window, so it should
          // not be found and export should fail.
          fakeClient.getWorkoutDataReturn = [
            HealthExportWorkout(
              uuid: 'running-uuid',
              // Workout at +30s is outside the ±5s lookup tolerance, so it won't match.
              activityType: HealthExportActivityType.running,
              start: start.add(const Duration(seconds: 30)),
              end: end,
            ),
          ];

          final result = await service.exportRun(
            start: start,
            end: end,
            distanceKm: distanceKm,
            routePoints: routePoints,
          );

          expect(result, isA<HealthExportFailure>());
          expect(
            (result as HealthExportFailure).reason,
            'Workout UUID not found after write',
          );
          expect(fakeClient.discardWorkoutRouteCallCount, 1);
        },
      );

      test('returns failure when startWorkoutRoute throws', () async {
        fakeClient.throwPlatformException = true;

        final result = await service.exportRun(
          start: start,
          end: end,
          distanceKm: distanceKm,
          routePoints: routePoints,
        );

        expect(result, isA<HealthExportFailure>());
        expect(
          (result as HealthExportFailure).reason,
          contains('Export failed:'),
        );
        expect(fakeClient.discardWorkoutRouteCallCount, 0);
      });

      test('discards route on failure', () async {
        final throwingClient = _FakeHealthClientThrowsOnFinish()
          ..startWorkoutRouteReturn = 'builder-123'
          ..insertWorkoutRouteDataReturn = true
          ..writeWorkoutDataReturn = true
          ..getWorkoutDataReturn = [
            mockWorkout(uuid: 'workout-uuid-789'),
          ];
        service = HealthExportService(client: throwingClient);

        final result = await service.exportRun(
          start: start,
          end: end,
          distanceKm: distanceKm,
          routePoints: routePoints,
        );

        expect(result, isA<HealthExportFailure>());
        expect(throwingClient.discardWorkoutRouteCallCount, 1);
        expect(throwingClient.lastDiscardWorkoutRouteBuilderId, 'builder-123');
        expect(
          (result as HealthExportFailure).reason,
          contains('Export failed:'),
        );
      });

      test(
        'returns HealthExportFailure when client throws PlatformException – auth denial handled at provider level',
        () async {
          fakeClient.throwPlatformException = true;

          final result = await service.exportRun(
            start: start,
            end: end,
            distanceKm: distanceKm,
          );

          expect(result, isA<HealthExportFailure>());
        },
      );
    });
  });
}

class _FakeHealthClientThrowsOnFinish extends FakeHealthClient {
  @override
  Future<String> finishWorkoutRoute({
    required String builderId,
    required String workoutUuid,
    Map<String, dynamic>? metadata,
  }) async {
    throw PlatformException(
      code: 'FINISH_ERROR',
      message: 'Failed to finish route',
    );
  }
}
