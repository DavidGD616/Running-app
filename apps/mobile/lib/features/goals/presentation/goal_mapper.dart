import '../../profile/domain/models/runner_profile.dart';
import '../domain/models/goal.dart';

class GoalInput {
  const GoalInput({
    required this.race,
    required this.hasRaceDate,
    this.raceDate,
  });

  final RunnerGoalRace race;
  final bool hasRaceDate;
  final DateTime? raceDate;
}

GoalInput? goalInputFromRunnerProfile(RunnerProfile? profile) {
  if (profile == null) return null;
  return GoalInput(
    race: profile.goal.race,
    hasRaceDate: profile.goal.hasRaceDate,
    raceDate: profile.goal.raceDate,
  );
}

GoalInput? goalInputFromDraft(RunnerProfileDraft draft) {
  final race = draft.goal.race;
  final hasRaceDate = draft.goal.hasRaceDate;
  if (race == null || hasRaceDate == null) return null;

  return GoalInput(
    race: race,
    hasRaceDate: hasRaceDate,
    raceDate: draft.goal.raceDate,
  );
}

GoalRaceType goalRaceTypeFromRunnerRace(RunnerGoalRace race) {
  return switch (race) {
    RunnerGoalRace.fiveK => GoalRaceType.fiveK,
    RunnerGoalRace.tenK => GoalRaceType.tenK,
    RunnerGoalRace.halfMarathon => GoalRaceType.halfMarathon,
    RunnerGoalRace.marathon => GoalRaceType.marathon,
    RunnerGoalRace.other => GoalRaceType.other,
  };
}

Goal? goalFromInput(GoalInput input) {
  final raceType = goalRaceTypeFromRunnerRace(input.race);
  final eventDate = input.hasRaceDate ? input.raceDate : null;
  if (input.hasRaceDate && eventDate == null) return null;

  return RaceGoal(
    event: RaceEvent(raceType: raceType, eventDate: eventDate),
    targetRace: raceType,
    status: GoalStatus.active,
  );
}

Goal? goalFromRunnerProfileOrNull(RunnerProfile? profile) {
  final input = goalInputFromRunnerProfile(profile);
  return input == null ? null : goalFromInput(input);
}

Goal? goalFromDraftOrNull(RunnerProfileDraft draft) {
  final input = goalInputFromDraft(draft);
  return input == null ? null : goalFromInput(input);
}
