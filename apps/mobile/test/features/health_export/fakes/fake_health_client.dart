import 'package:flutter/services.dart';
import 'package:running_app/features/health_export/data/health_client.dart';
import 'package:running_app/features/health_export/domain/export_route_point.dart';
import 'package:running_app/features/health_export/domain/health_export_types.dart';

class FakeHealthClient implements HealthClient {
  // Return values
  Future<void> configureReturn = Future.value();
  bool requestAuthorizationReturn = true;
  bool? hasPermissionsReturn = true;
  String startWorkoutRouteReturn = 'fake-builder-id';
  bool insertWorkoutRouteDataReturn = true;
  bool writeWorkoutDataReturn = true;
  List<HealthExportWorkout> getWorkoutDataReturn = [];
  String finishWorkoutRouteReturn = 'fake-workout-uuid';
  bool discardWorkoutRouteReturn = true;

  // Exception configuration
  bool throwPlatformException = false;

  // Call tracking
  final List<String> calls = [];
  int configureCallCount = 0;
  int requestAuthorizationCallCount = 0;
  int hasPermissionsCallCount = 0;
  int startWorkoutRouteCallCount = 0;
  int insertWorkoutRouteDataCallCount = 0;
  int writeWorkoutDataCallCount = 0;
  int getWorkoutDataCallCount = 0;
  int finishWorkoutRouteCallCount = 0;
  int discardWorkoutRouteCallCount = 0;

  // Captured arguments
  List<HealthExportDataType>? lastRequestAuthorizationTypes;
  List<HealthExportAccess>? lastRequestAuthorizationPermissions;
  List<HealthExportDataType>? lastHasPermissionsTypes;
  List<HealthExportAccess>? lastHasPermissionsPermissions;
  String? lastInsertWorkoutRouteDataBuilderId;
  List<ExportRoutePoint>? lastInsertWorkoutRouteDataLocations;
  HealthExportActivityType? lastWriteWorkoutDataActivityType;
  DateTime? lastWriteWorkoutDataStart;
  DateTime? lastWriteWorkoutDataEnd;
  int? lastWriteWorkoutDataTotalDistanceMeters;
  String? lastWriteWorkoutDataTitle;
  DateTime? lastGetWorkoutDataStart;
  DateTime? lastGetWorkoutDataEnd;
  String? lastFinishWorkoutRouteBuilderId;
  String? lastFinishWorkoutRouteWorkoutUuid;
  Map<String, dynamic>? lastFinishWorkoutRouteMetadata;
  String? lastDiscardWorkoutRouteBuilderId;

  void _maybeThrow() {
    if (throwPlatformException) {
      throw PlatformException(
        code: 'SIMULATOR_ERROR',
        message: 'HealthKit is not available in the simulator',
      );
    }
  }

  void _record(String name) {
    calls.add(name);
  }

  @override
  Future<void> configure() async {
    _record('configure');
    configureCallCount++;
    _maybeThrow();
    return configureReturn;
  }

  @override
  Future<bool> requestAuthorization(
    List<HealthExportDataType> types, {
    List<HealthExportAccess>? permissions,
  }) async {
    _record('requestAuthorization');
    requestAuthorizationCallCount++;
    lastRequestAuthorizationTypes = types;
    lastRequestAuthorizationPermissions = permissions;
    _maybeThrow();
    return requestAuthorizationReturn;
  }

  @override
  Future<bool?> hasPermissions(
    List<HealthExportDataType> types, {
    List<HealthExportAccess>? permissions,
  }) async {
    _record('hasPermissions');
    hasPermissionsCallCount++;
    lastHasPermissionsTypes = types;
    lastHasPermissionsPermissions = permissions;
    _maybeThrow();
    return hasPermissionsReturn;
  }

  @override
  Future<String> startWorkoutRoute() async {
    _record('startWorkoutRoute');
    startWorkoutRouteCallCount++;
    _maybeThrow();
    return startWorkoutRouteReturn;
  }

  @override
  Future<bool> insertWorkoutRouteData({
    required String builderId,
    required List<ExportRoutePoint> locations,
  }) async {
    _record('insertWorkoutRouteData');
    insertWorkoutRouteDataCallCount++;
    lastInsertWorkoutRouteDataBuilderId = builderId;
    lastInsertWorkoutRouteDataLocations = locations;
    _maybeThrow();
    return insertWorkoutRouteDataReturn;
  }

  @override
  Future<bool> writeWorkoutData({
    required HealthExportActivityType activityType,
    required DateTime start,
    required DateTime end,
    int? totalDistanceMeters,
    String? title,
  }) async {
    _record('writeWorkoutData');
    writeWorkoutDataCallCount++;
    lastWriteWorkoutDataActivityType = activityType;
    lastWriteWorkoutDataStart = start;
    lastWriteWorkoutDataEnd = end;
    lastWriteWorkoutDataTotalDistanceMeters = totalDistanceMeters;
    lastWriteWorkoutDataTitle = title;
    _maybeThrow();
    return writeWorkoutDataReturn;
  }

  @override
  Future<List<HealthExportWorkout>> getWorkoutData(
    DateTime start,
    DateTime end,
  ) async {
    _record('getWorkoutData');
    getWorkoutDataCallCount++;
    lastGetWorkoutDataStart = start;
    lastGetWorkoutDataEnd = end;
    _maybeThrow();
    return getWorkoutDataReturn;
  }

  @override
  Future<String> finishWorkoutRoute({
    required String builderId,
    required String workoutUuid,
    Map<String, dynamic>? metadata,
  }) async {
    _record('finishWorkoutRoute');
    finishWorkoutRouteCallCount++;
    lastFinishWorkoutRouteBuilderId = builderId;
    lastFinishWorkoutRouteWorkoutUuid = workoutUuid;
    lastFinishWorkoutRouteMetadata = metadata;
    _maybeThrow();
    return finishWorkoutRouteReturn;
  }

  @override
  Future<bool> discardWorkoutRoute(String builderId) async {
    _record('discardWorkoutRoute');
    discardWorkoutRouteCallCount++;
    lastDiscardWorkoutRouteBuilderId = builderId;
    _maybeThrow();
    return discardWorkoutRouteReturn;
  }
}
