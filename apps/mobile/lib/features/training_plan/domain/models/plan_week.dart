import 'training_session.dart';
import 'support_session.dart';

class PlanWeek {
  const PlanWeek({
    required this.weekNumber,
    required this.sessions,
    this.supportSessions = const [],
  });

  final int weekNumber;
  final List<TrainingSession> sessions;
  final List<SupportSession> supportSessions;
}
