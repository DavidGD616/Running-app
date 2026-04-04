import '../../../training_plan/domain/models/session_type.dart';

class RecentSession {
  const RecentSession({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.durationMinutes,
    required this.type,
  });

  final String id;
  final DateTime date;

  final double distanceKm;
  final int durationMinutes;

  /// Drives the icon and accent colour in the UI.
  final SessionType type;
}
