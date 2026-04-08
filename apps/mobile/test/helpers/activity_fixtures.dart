import 'package:running_app/features/activity/domain/models/activity_record.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';

RunActivity buildRunActivity({
  required String id,
  required DateTime recordedAt,
  String? linkedSessionId,
  ActivitySource source = ActivitySource.manual,
  ActivityCompletionStatus completionStatus =
      ActivityCompletionStatus.completed,
  DateTime? startedAt,
  DateTime? endedAt,
  Duration? actualDuration,
  double? actualDistanceKm = 6.02,
  int? actualElevationGainMeters = 120,
  ActivityPerceivedEffort? perceivedEffort = ActivityPerceivedEffort.moderate,
  String? notes = 'Steady effort',
}) {
  return RunActivity(
    id: id,
    source: source,
    completionStatus: completionStatus,
    recordedAt: recordedAt,
    startedAt: startedAt,
    endedAt: endedAt,
    actualDuration: actualDuration,
    actualDistanceKm: actualDistanceKm,
    actualElevationGainMeters: actualElevationGainMeters,
    perceivedEffort: perceivedEffort,
    linkedSessionId: linkedSessionId,
    notes: notes,
  );
}

TrainingSession buildPlannedRunSession({
  required String id,
  required DateTime date,
  required SessionStatus status,
  SessionType type = SessionType.easyRun,
  int weekNumber = 4,
  double? distanceKm = 8.0,
  int? durationMinutes = 42,
  int? elevationGainMeters = 96,
}) {
  return TrainingSession(
    id: id,
    date: date,
    type: type,
    status: status,
    weekNumber: weekNumber,
    distanceKm: distanceKm,
    durationMinutes: durationMinutes,
    elevationGainMeters: elevationGainMeters,
  );
}

TrainingPlan buildTestTrainingPlan({
  required List<TrainingSession> sessions,
  int currentWeekNumber = 4,
  TrainingPlanRaceType raceType = TrainingPlanRaceType.halfMarathon,
}) {
  return TrainingPlan(
    id: 'test-plan',
    raceType: raceType,
    totalWeeks: 12,
    currentWeekNumber: currentWeekNumber,
    sessions: sessions,
  );
}
