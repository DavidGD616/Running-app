import '../../../l10n/app_localizations.dart';
import '../domain/models/training_plan.dart';
import '../domain/models/training_session.dart';

String localizedTrainingPlanRace(
  TrainingPlanRaceType raceType,
  AppLocalizations l10n,
) {
  switch (raceType) {
    case TrainingPlanRaceType.fiveK:
      return l10n.race5K;
    case TrainingPlanRaceType.tenK:
      return l10n.race10K;
    case TrainingPlanRaceType.halfMarathon:
      return l10n.raceHalfMarathon;
    case TrainingPlanRaceType.marathon:
      return l10n.raceMarathon;
    case TrainingPlanRaceType.other:
      return l10n.raceOther;
  }
}

String localizedTrainingPlanName({
  required TrainingPlanRaceType raceType,
  required int totalWeeks,
  required AppLocalizations l10n,
}) {
  return l10n.planReadyWeekPlanName(
    totalWeeks.toString(),
    localizedTrainingPlanRace(raceType, l10n),
  );
}

String localizedTrainingSessionEffort(
  TrainingSessionEffort effort,
  AppLocalizations l10n,
) {
  switch (effort) {
    case TrainingSessionEffort.easy:
      return l10n.trainingPlanEffortEasy;
    case TrainingSessionEffort.moderate:
      return l10n.trainingPlanEffortModerate;
    case TrainingSessionEffort.hard:
      return l10n.trainingPlanEffortHard;
    case TrainingSessionEffort.veryEasy:
      return l10n.trainingPlanEffortVeryEasy;
  }
}
