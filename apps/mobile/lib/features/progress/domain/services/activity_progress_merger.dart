import '../../../activity/activity.dart';
import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';

List<TrainingSession> buildEffectiveCompletedRunSessions({
  required Iterable<TrainingSession> plannedSessions,
  required Iterable<ActivityRecord> activities,
}) {
  final plannedSessionById = {
    for (final session in plannedSessions) session.id: session,
  };
  final completedRunActivities =
      activities
          .where(
            (activity) =>
                activity.isCompleted && activity.kind == ActivityKind.run,
          )
          .toList(growable: false)
        ..sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));

  final linkedSessionIds = completedRunActivities
      .where((activity) => activity.hasLinkedSession)
      .map((activity) => activity.linkedSessionId!)
      .toSet();

  final fallbackSessions =
      plannedSessions
          .where(
            (session) =>
                session.countsAsRun &&
                session.status == SessionStatus.completed &&
                !linkedSessionIds.contains(session.id),
          )
          .toList(growable: false)
        ..sort((a, b) => b.date.compareTo(a.date));

  final activitySessions = completedRunActivities
      .map(
        (activity) => _activityToTrainingSession(
          activity,
          linkedSession: activity.hasLinkedSession
              ? plannedSessionById[activity.linkedSessionId!]
              : null,
        ),
      )
      .toList(growable: false);

  final merged = [...activitySessions, ...fallbackSessions];
  merged.sort((a, b) => b.date.compareTo(a.date));
  return merged;
}

Set<String> linkedSessionIdsForCompletedActivities(
  Iterable<ActivityRecord> activities,
) {
  return activities
      .where((activity) => activity.isCompleted && activity.hasLinkedSession)
      .map((activity) => activity.linkedSessionId!)
      .toSet();
}

TrainingSession _activityToTrainingSession(
  ActivityRecord activity, {
  TrainingSession? linkedSession,
}) {
  final durationMinutes = activity.derivedDuration?.inMinutes;
  final mappedEffort = switch (activity.perceivedEffort) {
    ActivityPerceivedEffort.veryEasy => TrainingSessionEffort.veryEasy,
    ActivityPerceivedEffort.easy => TrainingSessionEffort.easy,
    ActivityPerceivedEffort.moderate => TrainingSessionEffort.moderate,
    ActivityPerceivedEffort.hard => TrainingSessionEffort.hard,
    ActivityPerceivedEffort.veryHard => TrainingSessionEffort.hard,
    null => null,
  };

  if (linkedSession != null) {
    return linkedSession.copyWith(
      date: activity.sortTimestamp,
      status: SessionStatus.completed,
      distanceKm: activity.actualDistanceKm ?? linkedSession.distanceKm,
      durationMinutes: durationMinutes ?? linkedSession.durationMinutes,
      elevationGainMeters:
          activity.actualElevationGainMeters ?? linkedSession.elevationGainMeters,
      effort: mappedEffort ?? linkedSession.effort,
      description: activity.notes ?? linkedSession.description,
    );
  }

  return TrainingSession(
    id: activity.linkedSessionId ?? activity.id,
    date: activity.sortTimestamp,
    type: SessionType.easyRun,
    status: SessionStatus.completed,
    distanceKm: activity.actualDistanceKm,
    durationMinutes: durationMinutes,
    elevationGainMeters: activity.actualElevationGainMeters,
    effort: mappedEffort,
    description: activity.notes,
  );
}
