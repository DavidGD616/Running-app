import 'package:health/health.dart';

import '../domain/export_route_point.dart';
import '../domain/health_export_types.dart';

/// Plugin-neutral surface used by `HealthExportService`.
///
/// Only `PackageHealthClient` (below) imports `package:health`.
abstract class HealthClient {
  Future<void> configure();

  Future<bool> requestAuthorization(
    List<HealthExportDataType> types, {
    List<HealthExportAccess>? permissions,
  });

  Future<bool?> hasPermissions(
    List<HealthExportDataType> types, {
    List<HealthExportAccess>? permissions,
  });

  Future<String> startWorkoutRoute();

  Future<bool> insertWorkoutRouteData({
    required String builderId,
    required List<ExportRoutePoint> locations,
  });

  Future<bool> writeWorkoutData({
    required HealthExportActivityType activityType,
    required DateTime start,
    required DateTime end,
    int? totalDistanceMeters,
    String? title,
  });

  /// Returns workouts overlapping `[start, end]`. Used to look up the UUID
  /// of the workout just written so the route builder can be associated.
  Future<List<HealthExportWorkout>> getWorkoutData(
    DateTime start,
    DateTime end,
  );

  Future<String> finishWorkoutRoute({
    required String builderId,
    required String workoutUuid,
    Map<String, dynamic>? metadata,
  });

  Future<bool> discardWorkoutRoute(String builderId);
}

class PackageHealthClient implements HealthClient {
  final Health _health = Health();

  @override
  Future<void> configure() => _health.configure();

  @override
  Future<bool> requestAuthorization(
    List<HealthExportDataType> types, {
    List<HealthExportAccess>? permissions,
  }) {
    return _health.requestAuthorization(
      types.map(_toHealthDataType).toList(),
      permissions: permissions?.map(_toHealthDataAccess).toList(),
    );
  }

  @override
  Future<bool?> hasPermissions(
    List<HealthExportDataType> types, {
    List<HealthExportAccess>? permissions,
  }) {
    return _health.hasPermissions(
      types.map(_toHealthDataType).toList(),
      permissions: permissions?.map(_toHealthDataAccess).toList(),
    );
  }

  @override
  Future<String> startWorkoutRoute() => _health.startWorkoutRoute();

  @override
  Future<bool> insertWorkoutRouteData({
    required String builderId,
    required List<ExportRoutePoint> locations,
  }) {
    return _health.insertWorkoutRouteData(
      builderId: builderId,
      locations: locations.map(_toWorkoutRouteLocation).toList(),
    );
  }

  @override
  Future<bool> writeWorkoutData({
    required HealthExportActivityType activityType,
    required DateTime start,
    required DateTime end,
    int? totalDistanceMeters,
    String? title,
  }) {
    return _health.writeWorkoutData(
      activityType: _toHealthWorkoutActivityType(activityType),
      start: start,
      end: end,
      totalDistance: totalDistanceMeters,
      totalDistanceUnit: HealthDataUnit.METER,
      title: title,
    );
  }

  @override
  Future<List<HealthExportWorkout>> getWorkoutData(
    DateTime start,
    DateTime end,
  ) async {
    final points = await _health.getHealthDataFromTypes(
      startTime: start,
      endTime: end,
      types: [HealthDataType.WORKOUT],
    );

    final workouts = <HealthExportWorkout>[];
    for (final p in points) {
      final value = p.value;
      if (value is! WorkoutHealthValue) continue;
      final activity = _fromHealthWorkoutActivityType(value.workoutActivityType);
      if (activity == null) continue;
      workouts.add(
        HealthExportWorkout(
          uuid: p.uuid,
          activityType: activity,
          start: p.dateFrom,
          end: p.dateTo,
        ),
      );
    }
    return workouts;
  }

  @override
  Future<String> finishWorkoutRoute({
    required String builderId,
    required String workoutUuid,
    Map<String, dynamic>? metadata,
  }) => _health.finishWorkoutRoute(
    builderId: builderId,
    workoutUuid: workoutUuid,
    metadata: metadata,
  );

  @override
  Future<bool> discardWorkoutRoute(String builderId) =>
      _health.discardWorkoutRoute(builderId);

  // --- Conversions ---

  static HealthDataType _toHealthDataType(HealthExportDataType type) {
    return switch (type) {
      HealthExportDataType.workout => HealthDataType.WORKOUT,
      HealthExportDataType.workoutRoute => HealthDataType.WORKOUT_ROUTE,
      HealthExportDataType.distanceWalkingRunning =>
        HealthDataType.DISTANCE_WALKING_RUNNING,
      HealthExportDataType.exerciseTime => HealthDataType.EXERCISE_TIME,
    };
  }

  static HealthDataAccess _toHealthDataAccess(HealthExportAccess access) {
    return switch (access) {
      HealthExportAccess.read => HealthDataAccess.READ,
      HealthExportAccess.write => HealthDataAccess.WRITE,
      HealthExportAccess.readWrite => HealthDataAccess.READ_WRITE,
    };
  }

  static HealthWorkoutActivityType _toHealthWorkoutActivityType(
    HealthExportActivityType type,
  ) {
    return switch (type) {
      HealthExportActivityType.running => HealthWorkoutActivityType.RUNNING,
    };
  }

  static HealthExportActivityType? _fromHealthWorkoutActivityType(
    HealthWorkoutActivityType type,
  ) {
    return switch (type) {
      HealthWorkoutActivityType.RUNNING => HealthExportActivityType.running,
      _ => null,
    };
  }

  static WorkoutRouteLocation _toWorkoutRouteLocation(ExportRoutePoint p) {
    return WorkoutRouteLocation(
      latitude: p.lat,
      longitude: p.lng,
      timestamp: p.timestamp,
      altitude: p.altitude,
      speed: p.speed,
      course: p.course,
      horizontalAccuracy: p.horizontalAccuracy,
    );
  }
}
