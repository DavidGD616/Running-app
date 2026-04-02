import '../../../training_plan/domain/models/session_type.dart';

enum RecentSessionDateLabel {
  yesterday,
  tuesday,
  lastSunday,
}

class RecentSession {
  const RecentSession({
    required this.id,
    required this.dateLabel,
    required this.distanceKm,
    required this.durationMinutes,
    required this.type,
  });

  final String id;
  final RecentSessionDateLabel dateLabel;

  final double distanceKm;
  final int durationMinutes;

  /// Drives the icon and accent colour in the UI.
  final SessionType type;
}
