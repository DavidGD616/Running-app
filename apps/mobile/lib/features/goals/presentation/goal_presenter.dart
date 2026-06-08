import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/models/goal.dart';

const Map<GoalRaceType, int> _goalWeeksByRace = {
  GoalRaceType.fiveK: 8,
  GoalRaceType.tenK: 10,
  GoalRaceType.halfMarathon: 12,
  GoalRaceType.marathon: 16,
  GoalRaceType.other: 12,
};

String goalRaceLabel(Goal? goal, AppLocalizations l10n) {
  if (goal == null) return '—';

  return switch (goal.targetRace) {
    GoalRaceType.fiveK => l10n.race5K,
    GoalRaceType.tenK => l10n.race10K,
    GoalRaceType.halfMarathon => l10n.raceHalfMarathon,
    GoalRaceType.marathon => l10n.raceMarathon,
    GoalRaceType.other => l10n.raceOther,
  };
}

String goalDescription(Goal? goal, AppLocalizations l10n) {
  final race = goalRaceLabel(goal, l10n);
  if (race == '—') return '—';
  return l10n.planReadyGoalDescription(race);
}

int? goalPlanWeeksForRace(GoalRaceType raceType) => _goalWeeksByRace[raceType];

String goalPlanWeeks(Goal? goal) {
  final weeks = goal == null ? null : goalPlanWeeksForRace(goal.targetRace);
  return weeks?.toString() ?? '—';
}

String formatGoalDate(BuildContext context, Goal? goal) {
  final eventDate = goal?.eventDate;
  if (eventDate == null) return AppLocalizations.of(context)!.no;

  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMMd(locale).format(eventDate);
}
