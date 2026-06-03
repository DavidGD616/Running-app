import '../../../l10n/app_localizations.dart';
import '../domain/models/training_plan.dart';
import '../domain/models/training_session.dart';
import '../domain/models/support_session.dart';

String localizedPhaseLabel(
  String? phase,
  AppLocalizations l10n,
) {
  switch (phase) {
    case 'base':
      return l10n.phaseBase;
    case 'build':
      return l10n.phaseBuild;
    case 'specific':
      return l10n.phaseSpecific;
    case 'peak':
      return l10n.phasePeak;
    case 'taperRace':
      return l10n.phaseTaperRace;
    default:
      return '';
  }
}

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

List<String> localizedSupportSessionSubtitles(
  SupportSession session,
  AppLocalizations l10n,
) {
  final details = <String>[];

  final load = _localizedSupportSessionFieldValue(
    label: l10n.planSupportSessionLoadLabel,
    value: session.load,
    valueMap: {
      'light': l10n.supportSessionLoadLight,
      'moderate': l10n.supportSessionLoadModerate,
      'medium': l10n.supportSessionLoadModerate,
      'heavy': l10n.supportSessionLoadHigh,
      'high': l10n.supportSessionLoadHigh,
    },
    l10n: l10n,
  );
  if (load != null) details.add(load);

  final timing = _localizedSupportSessionFieldValue(
    label: l10n.planSupportSessionTimingLabel,
    value: session.timingGuidance,
    valueMap: {
      'on_off_days': l10n.supportSessionTimingOnOffDays,
      'off_days': l10n.supportSessionTimingOnOffDays,
      'same_day': l10n.supportSessionTimingSameDay,
      'same_day_with_workout': l10n.supportSessionTimingSameDay,
      'next_day': l10n.supportSessionTimingNextDay,
    },
    l10n: l10n,
  );
  if (timing != null) details.add(timing);

  final interference = _localizedSupportSessionFieldValue(
    label: l10n.planSupportSessionInterferenceLabel,
    value: session.interferenceRule,
    valueMap: {
      'avoid_day_before_long_run': l10n
          .supportSessionInterferenceAvoidDayBeforeLongRun,
      'avoid_day_before_race': l10n.supportSessionInterferenceAvoidDayBeforeRace,
      'avoid_day_before_key_workout':
          l10n.supportSessionInterferenceAvoidDayBeforeKeyWorkout,
    },
    l10n: l10n,
  );
  if (interference != null) details.add(interference);

  final taper = _localizedSupportSessionFieldValue(
    label: l10n.planSupportSessionTaperLabel,
    value: session.taperAdjustment,
    valueMap: {
      'reduce_load_week_before_race':
          l10n.supportSessionTaperReduceLoadWeekBeforeRace,
      'reduce_load':
          l10n.supportSessionTaperReduceLoad,
    },
    l10n: l10n,
  );
  if (taper != null) details.add(taper);

  final note = session.notes?.trim();
  if (note != null && note.isNotEmpty) {
    details.insert(0, note);
  }

  return details;
}

String? _localizedSupportSessionFieldValue({
  required String label,
  required String? value,
  required Map<String, String> valueMap,
  required AppLocalizations l10n,
}) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final normalized = trimmed.toLowerCase();
  final localizedValue = valueMap[normalized] ?? _humanizeValue(trimmed);
  return '$label: $localizedValue';
}

String _humanizeValue(String value) {
  final replaced = value.replaceAll('_', ' ').trim();
  if (replaced.isEmpty) return value;
  return replaced[0].toUpperCase() + replaced.substring(1);
}
