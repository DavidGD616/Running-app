import 'training_session.dart';
import 'session_type.dart';

class WeekProgress {
  const WeekProgress({
    required this.completedSessions,
    required this.totalSessions,
    required this.completedVolumeKm,
    required this.totalVolumeKm,
    required this.totalDurationMinutes,
  });

  final int completedSessions;
  final int totalSessions;
  final double completedVolumeKm;
  final double totalVolumeKm;

  /// Total planned duration in minutes for all running sessions this week.
  final int totalDurationMinutes;

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

    final totalMinutes = runningSessions.fold(
        0, (sum, s) => sum + (s.durationMinutes ?? 0));

    return WeekProgress(
      completedSessions: completed,
      totalSessions: runningSessions.length,
      completedVolumeKm: completedKm,
      totalVolumeKm: totalKm,
      totalDurationMinutes: totalMinutes,
    );
  }
}
