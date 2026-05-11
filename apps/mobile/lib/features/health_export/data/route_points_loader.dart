import '../domain/export_route_point.dart';
import '../../active_run/data/run_repository.dart';

/// Converts raw [RunRoutePoint]s from the repository into
/// presentation-ready [ExportRoutePoint]s sorted by timestamp.
List<ExportRoutePoint> toExportRoutePoints(List<RunRoutePoint> points) {
  if (points.isEmpty) return const [];

  final sorted = List<RunRoutePoint>.from(points)
    ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

  return sorted
      .map(
        (p) => ExportRoutePoint(
          lat: p.lat,
          lng: p.lng,
          timestamp: DateTime.fromMillisecondsSinceEpoch(p.timestampMs),
          altitude: p.altitude,
          speed: p.speed,
          horizontalAccuracy: p.accuracy,
          course: p.heading,
        ),
      )
      .toList();
}
