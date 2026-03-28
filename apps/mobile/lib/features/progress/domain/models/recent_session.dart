import '../../../training_plan/domain/models/session_type.dart';

class RecentSession {
  const RecentSession({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.distanceKm,
    required this.durationMinutes,
    required this.type,
  });

  final String id;
  final String title;

  /// Human-readable date label, e.g. 'Yesterday', 'Tuesday', 'Last Sunday'.
  final String dateLabel;

  final double distanceKm;
  final int durationMinutes;

  /// Drives the icon and accent colour in the UI.
  final SessionType type;
}
