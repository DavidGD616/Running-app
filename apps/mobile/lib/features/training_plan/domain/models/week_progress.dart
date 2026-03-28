import 'training_session.dart';
import 'session_type.dart';

class WeekProgress {
  const WeekProgress({
    required this.completedSessions,
    required this.totalSessions,
    required this.completedVolumeKm,
    required this.totalVolumeKm,
  });

  final int completedSessions;
  final int totalSessions;
  final double completedVolumeKm;
  final double totalVolumeKm;

  factory WeekProgress.fromSessions(List<TrainingSession> sessions) {
    final runningSessions =
        sessions.where((s) => s.type != SessionType.rest).toList();

    final completed = runningSessions
        .where((s) => s.status == SessionStatus.completed)
        .length;

    final completedKm = runningSessions
        .where((s) => s.status == SessionStatus.completed)
        .fold(0.0, (sum, s) => sum + (s.distanceKm ?? 0.0));

    final totalKm = runningSessions.fold(
        0.0, (sum, s) => sum + (s.distanceKm ?? 0.0));

    return WeekProgress(
      completedSessions: completed,
      totalSessions: runningSessions.length,
      completedVolumeKm: completedKm,
      totalVolumeKm: totalKm,
    );
  }
}
