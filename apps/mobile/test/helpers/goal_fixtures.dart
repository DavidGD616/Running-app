import 'package:running_app/features/goals/domain/models/goal.dart';

Goal buildHalfMarathonTimeGoal({
  DateTime? eventDate,
  GoalStatus status = GoalStatus.active,
}) {
  return RaceGoal(
    event: RaceEvent(
      raceType: GoalRaceType.halfMarathon,
      eventDate: eventDate ?? DateTime(2026, 10, 18),
    ),
    kind: GoalKind.time,
    status: status,
  );
}

Goal buildFiveKRaceGoal({
  DateTime? eventDate,
  GoalStatus status = GoalStatus.active,
}) {
  return RaceGoal(
    event: RaceEvent(
      raceType: GoalRaceType.fiveK,
      eventDate: eventDate ?? DateTime(2026, 5, 1),
    ),
    kind: GoalKind.race,
    status: status,
  );
}
