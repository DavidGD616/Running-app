import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';

class LongestRunStats {
  const LongestRunStats({
    this.bestDistanceKm,
    this.previousBestKm,
  });

  final double? bestDistanceKm;
  final double? previousBestKm;

  double? get improvementKm {
    if (bestDistanceKm == null || previousBestKm == null) return null;
    final delta = bestDistanceKm! - previousBestKm!;
    return delta > 0 ? delta : null;
  }

  bool get hasRecord => bestDistanceKm != null;
}

LongestRunStats calculateLongestRunStats({
  required Iterable<TrainingSession> sessions,
  DateTime? clock,
}) {
  final now = clock ?? DateTime.now();
  final runs = sessions
      .where((s) =>
          s.status == SessionStatus.completed &&
          !s.type.isRest &&
          !s.date.isAfter(now) &&
          (s.distanceKm ?? 0) > 0)
      .toList();

  if (runs.isEmpty) return const LongestRunStats();

  runs.sort((a, b) {
    final distanceCmp = (b.distanceKm ?? 0)
        .compareTo(a.distanceKm ?? 0);
    if (distanceCmp != 0) return distanceCmp;
    return a.date.compareTo(b.date);
  });

  final best = runs.first.distanceKm ?? 0;
  double? previous;
  for (final run in runs.skip(1)) {
    final distance = run.distanceKm ?? 0;
    if (distance < best) {
      previous = distance;
      break;
    }
  }

  return LongestRunStats(
    bestDistanceKm: best,
    previousBestKm: previous,
  );
}
