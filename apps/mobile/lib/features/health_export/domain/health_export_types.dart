// Neutral types exposed by `HealthClient`.
//
// These exist so that the only file in the app importing `package:health`
// is the `PackageHealthClient` adapter. Service code, fakes, and tests
// stay free of plugin types and can be unit-tested without the plugin.

/// Categories of HealthKit data that the export feature needs to access.
enum HealthExportDataType {
  workout,
  workoutRoute,
  distanceWalkingRunning,
  exerciseTime,
}

/// Read/write access mode requested for a given data type.
enum HealthExportAccess {
  read,
  write,
  readWrite,
}

/// Workout activity type. Single member for now — only running is exported.
enum HealthExportActivityType {
  running,
}

/// Lightweight workout record returned from a HealthKit query.
class HealthExportWorkout {
  const HealthExportWorkout({
    required this.uuid,
    required this.activityType,
    required this.start,
    required this.end,
  });

  final String uuid;
  final HealthExportActivityType activityType;
  final DateTime start;
  final DateTime end;
}
