import 'package:flutter/foundation.dart';

import '../domain/export_route_point.dart';
import '../domain/health_export_result.dart';
import '../domain/health_export_types.dart';
import 'health_client.dart';

// Tolerance window when looking up the workout we just wrote to associate
// the route. ±1s is too narrow because HealthKit's stored `dateFrom`/`dateTo`
// can drift slightly from `DateTime.now()`. ±5s reliably catches the match
// while staying tight enough that concurrent writes are rare. After filtering
// by activity type and the tolerance window, we pick the most-recently-started
// running workout in the window — under normal app flow that is the workout
// we just wrote (a concurrency mitigation, not a true closest-match search).
const _kWorkoutLookupTolerance = Duration(seconds: 5);

class HealthExportService {
  HealthExportService({required HealthClient client}) : _client = client;

  final HealthClient _client;

  /// Requests HealthKit authorization for WORKOUT + WORKOUT_ROUTE.
  /// Returns true if authorization was granted (or dialog shown on iOS).
  Future<bool> requestAuthorization() async {
    try {
      await _client.configure();
      return await _client.requestAuthorization(
        [
          HealthExportDataType.workout,
          HealthExportDataType.workoutRoute,
        ],
        permissions: [
          HealthExportAccess.readWrite,
          HealthExportAccess.readWrite,
        ],
      );
    } catch (e, st) {
      debugPrint('HealthKit authorization failed: $e\n$st');
      return false;
    }
  }

  /// Exports a run to Apple Health.
  /// - With route points: writes workout + route map
  /// - Without route points: writes workout only
  Future<HealthExportResult> exportRun({
    required DateTime start,
    required DateTime end,
    required double distanceKm,
    List<ExportRoutePoint>? routePoints,
  }) async {
    final hasRoute = routePoints != null && routePoints.isNotEmpty;
    String? routeBuilderId;

    try {
      if (hasRoute) {
        final builderId = await _client.startWorkoutRoute();
        routeBuilderId = builderId;

        final inserted = await _client.insertWorkoutRouteData(
          builderId: builderId,
          locations: routePoints,
        );

        if (!inserted) {
          await _client.discardWorkoutRoute(builderId);
          return const HealthExportFailure(
            'Failed to insert workout route data',
          );
        }

        final written = await _client.writeWorkoutData(
          activityType: HealthExportActivityType.running,
          start: start,
          end: end,
          totalDistanceMeters: (distanceKm * 1000).round(),
        );

        if (!written) {
          await _client.discardWorkoutRoute(builderId);
          return const HealthExportFailure('Failed to write workout data');
        }

        // Look up the workout we just wrote so we can attach the route.
        // Widen the search window slightly to absorb HealthKit timestamp
        // drift, then filter by activity type and pick the most-recently-
        // started running workout in the window.
        final workouts = await _client.getWorkoutData(
          start.subtract(_kWorkoutLookupTolerance),
          end.add(_kWorkoutLookupTolerance),
        );

        final candidates = workouts
            .where(
              (w) =>
                  w.activityType == HealthExportActivityType.running &&
                  (w.start.difference(start)).abs() <=
                      _kWorkoutLookupTolerance,
            )
            .toList();

        if (candidates.isEmpty) {
          await _client.discardWorkoutRoute(builderId);
          return const HealthExportFailure(
            'Workout UUID not found after write',
          );
        }

        // Pick the most-recently-started match (best proxy for the workout
        // we just wrote when multiple candidates exist).
        candidates.sort((a, b) => b.start.compareTo(a.start));
        final workoutUuid = candidates.first.uuid;

        await _client.finishWorkoutRoute(
          builderId: builderId,
          workoutUuid: workoutUuid,
          metadata: const {'source': 'RunFlow'},
        );
      } else {
        final written = await _client.writeWorkoutData(
          activityType: HealthExportActivityType.running,
          start: start,
          end: end,
          totalDistanceMeters: (distanceKm * 1000).round(),
        );

        if (!written) {
          return const HealthExportFailure('Failed to write workout data');
        }
      }

      return const HealthExportSuccess();
    } catch (e, st) {
      debugPrint('Health export failed: $e\n$st');
      if (routeBuilderId != null) {
        try {
          await _client.discardWorkoutRoute(routeBuilderId);
        } catch (_) {
          // Best effort cleanup
        }
      }
      return HealthExportFailure('Export failed: $e');
    }
  }
}
