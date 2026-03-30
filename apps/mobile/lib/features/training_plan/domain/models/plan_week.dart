import 'training_session.dart';

class PlanWeek {
  const PlanWeek({
    required this.weekNumber,
    required this.sessions,
  });

  final int weekNumber;
  final List<TrainingSession> sessions;
}
