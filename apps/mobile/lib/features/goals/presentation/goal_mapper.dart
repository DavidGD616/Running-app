import '../../profile/domain/models/runner_profile.dart';
import '../domain/models/goal.dart';

class GoalInput {
  const GoalInput({
    required this.race,
    required this.hasRaceDate,
    required this.priority,
    this.raceDate,
    this.currentTime,
    this.targetTime,
  });

  final RunnerGoalRace race;
  final bool hasRaceDate;
  final DateTime? raceDate;
  final GoalPriority priority;
  final Duration? currentTime;
  final Duration? targetTime;
}

GoalInput? goalInputFromRunnerProfile(RunnerProfile? profile) {
  if (profile == null) return null;
  return GoalInput(
    race: profile.goal.race,
    hasRaceDate: profile.goal.hasRaceDate,
    raceDate: profile.goal.raceDate,
    priority: profile.goal.priority,
    currentTime: profile.goal.currentTime,
    targetTime: profile.goal.targetTime,
  );
}

GoalInput? goalInputFromDraft(RunnerProfileDraft draft) {
  final race = draft.goal.race;
  final priority = draft.goal.priority;
  final hasRaceDate = draft.goal.hasRaceDate;
  if (race == null || priority == null || hasRaceDate == null) return null;

  return GoalInput(
    race: race,
    hasRaceDate: hasRaceDate,
    raceDate: draft.goal.raceDate,
    priority: priority,
    currentTime: draft.goal.currentTime,
    targetTime: draft.goal.targetTime,
  );
}

GoalKind goalKindFromPriority(GoalPriority priority) {
  return switch (priority) {
    GoalPriority.improveTime => GoalKind.time,
    GoalPriority.consistency => GoalKind.consistency,
    GoalPriority.generalFitness => GoalKind.generalFitness,
    _ => GoalKind.race,
  };
}

GoalPriorityType goalPriorityTypeFromPriority(GoalPriority priority) {
  return switch (priority) {
    GoalPriority.justFinish => GoalPriorityType.justFinish,
    GoalPriority.finishStrong => GoalPriorityType.finishStrong,
    GoalPriority.improveTime => GoalPriorityType.improveTime,
    GoalPriority.consistency => GoalPriorityType.consistency,
    GoalPriority.generalFitness => GoalPriorityType.generalFitness,
  };
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
  final kind = goalKindFromPriority(input.priority);
  final priority = goalPriorityTypeFromPriority(input.priority);
  final raceType = goalRaceTypeFromRunnerRace(input.race);
  final eventDate = input.hasRaceDate ? input.raceDate : null;
  if (input.hasRaceDate && eventDate == null) return null;

  if (kind == GoalKind.time &&
      (input.currentTime == null || input.targetTime == null)) {
    return null;
  }

  final event = (kind == GoalKind.race || kind == GoalKind.time)
      ? RaceEvent(raceType: raceType, eventDate: eventDate)
      : null;

  if (kind == GoalKind.race) {
    return RaceGoal(
      event: event,
      targetRace: raceType,
      status: GoalStatus.active,
      priority: priority,
      currentTime: input.currentTime,
      targetTime: input.targetTime,
    );
  }

  if (kind == GoalKind.time) {
    return TimeGoal(
      targetRace: raceType,
      event: event,
      status: GoalStatus.active,
      priority: priority,
      eventDate: eventDate,
      currentTime: input.currentTime,
      targetTime: input.targetTime,
    );
  }

  return Goal(
    kind: kind,
    status: GoalStatus.active,
    priority: priority,
    targetRace: raceType,
    eventDate: eventDate,
    currentTime: input.currentTime,
    targetTime: input.targetTime,
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
