import '../../../profile/domain/models/runner_profile.dart';
import '../../../strava/domain/models/strava_coaching_profile.dart';
import '../../../training_plan/domain/models/model_json_utils.dart';

class ManualFitnessInput {
  const ManualFitnessInput({
    required this.experience,
    this.weeklyVolume,
    this.longestRun,
    this.canCompleteGoalDistance,
    this.raceDistanceBefore,
    this.benchmark,
    this.benchmarkTime,
  });

  final RunnerExperience experience;
  final WeeklyVolumeRange? weeklyVolume;
  final LongestRunRange? longestRun;
  final TernaryChoice? canCompleteGoalDistance;
  final RaceDistanceExperience? raceDistanceBefore;
  final BenchmarkType? benchmark;
  final Duration? benchmarkTime;

  Map<String, dynamic> toJson() {
    return {
      'experience': experience.key,
      'weeklyVolume': weeklyVolume?.key,
      'longestRun': longestRun?.key,
      'canCompleteGoalDistance': canCompleteGoalDistance?.key,
      'raceDistanceBefore': raceDistanceBefore?.key,
      'benchmark': benchmark?.key,
      'benchmarkTimeMs': benchmarkTime?.inMilliseconds,
    };
  }

  factory ManualFitnessInput.fromJson(Map<String, dynamic> json) {
    final context = 'manual fitness input';
    final experienceKey = requiredString(json, 'experience', context: context);
    final experience = RunnerExperience.fromKey(experienceKey);
    if (experience == null) {
      throw FormatException(
        'Invalid $context: unsupported experience "$experienceKey".',
      );
    }

    final weeklyVolume = optionalEnumFromKey(
      json,
      'weeklyVolume',
      context: context,
      parse: WeeklyVolumeRange.fromKey,
      fieldLabel: 'weeklyVolume',
    );
    final longestRun = optionalEnumFromKey(
      json,
      'longestRun',
      context: context,
      parse: LongestRunRange.fromKey,
      fieldLabel: 'longestRun',
    );
    final canCompleteGoalDistance = optionalEnumFromKey(
      json,
      'canCompleteGoalDistance',
      context: context,
      parse: TernaryChoice.fromKey,
      fieldLabel: 'canCompleteGoalDistance',
    );
    final raceDistanceBefore = optionalEnumFromKey(
      json,
      'raceDistanceBefore',
      context: context,
      parse: RaceDistanceExperience.fromKey,
      fieldLabel: 'raceDistanceBefore',
    );
    final benchmark = optionalEnumFromKey(
      json,
      'benchmark',
      context: context,
      parse: BenchmarkType.fromKey,
      fieldLabel: 'benchmark',
    );
    final benchmarkTime = optionalDurationMs(
      json,
      'benchmarkTimeMs',
      context: context,
    );

    if (benchmarkTime != null && benchmarkTime <= Duration.zero) {
      throw FormatException(
        'Invalid $context: benchmarkTimeMs must be > 0 when present.',
      );
    }

    final benchmarkNeedsTime =
        benchmark != null && benchmark != BenchmarkType.skip;
    if (benchmarkNeedsTime && benchmarkTime == null) {
      throw const FormatException(
        'Invalid manual fitness input: benchmarkTimeMs is required for a non-skip benchmark.',
      );
    }

    if (!benchmarkNeedsTime && benchmarkTime != null) {
      throw const FormatException(
        'Invalid manual fitness input: benchmarkTimeMs is only allowed when benchmark is not skip.',
      );
    }

    return ManualFitnessInput(
      experience: experience,
      weeklyVolume: weeklyVolume,
      longestRun: longestRun,
      canCompleteGoalDistance: canCompleteGoalDistance,
      raceDistanceBefore: raceDistanceBefore,
      benchmark: benchmark,
      benchmarkTime: benchmarkTime,
    );
  }
}

class ProfessionalPlanInput {
  const ProfessionalPlanInput({
    required this.goal,
    required this.fitnessSource,
    required this.acceptedRaceTarget,
    required this.schedule,
    required this.health,
    required this.strengthPreferences,
    required this.planIntensity,
    required this.locale,
    this.stravaCoachingProfile,
    this.manualFitness,
    this.unitPreference,
    this.raceCourseTerrain,
  });

  final GoalProfile goal;
  final FitnessSource fitnessSource;
  final StravaCoachingProfile? stravaCoachingProfile;
  final ManualFitnessInput? manualFitness;
  final AcceptedRaceTarget acceptedRaceTarget;
  final ScheduleProfile schedule;
  final HealthProfile health;
  final StrengthPreferences strengthPreferences;
  final PlanIntensity planIntensity;
  final String? unitPreference;
  final String locale;
  final RaceCourseTerrain? raceCourseTerrain;

  Map<String, dynamic> toJson() {
    return {
      'goal': _goalProfileToJson(goal),
      'fitnessSource': fitnessSource.key,
      'stravaCoachingProfile': stravaCoachingProfile?.toJson(),
      'manualFitness': manualFitness?.toJson(),
      'acceptedRaceTarget': acceptedRaceTarget.toJson(),
      'schedule': _scheduleProfileToJson(schedule),
      'health': _healthProfileToJson(health),
      'strengthPreferences': strengthPreferences.toJson(),
      'planIntensity': planIntensity.key,
      'unitPreference': unitPreference,
      'locale': locale,
      'raceCourseTerrain': raceCourseTerrain?.key,
    };
  }

  factory ProfessionalPlanInput.fromJson(Map<String, dynamic> json) {
    final context = 'professional plan input';

    final goal = _requiredGoalProfile(json, 'goal', context: context);

    final fitnessSourceKey = requiredString(
      json,
      'fitnessSource',
      context: context,
    );
    final fitnessSource = FitnessSource.fromKey(fitnessSourceKey);
    if (fitnessSource == null) {
      throw FormatException(
        'Invalid $context: unsupported fitnessSource "$fitnessSourceKey".',
      );
    }

    final stravaCoachingProfile = optionalNested(
      json,
      'stravaCoachingProfile',
      context: context,
      parse: StravaCoachingProfile.fromJson,
    );
    final manualFitness = optionalNested(
      json,
      'manualFitness',
      context: context,
      parse: ManualFitnessInput.fromJson,
    );

    final acceptedRaceTarget = requiredNested(
      json,
      'acceptedRaceTarget',
      context: context,
      parse: AcceptedRaceTarget.fromJson,
    );
    final schedule = _requiredScheduleProfile(
      json,
      'schedule',
      context: context,
    );
    final health = _requiredHealthProfile(json, 'health', context: context);
    final strengthPreferences = requiredNested(
      json,
      'strengthPreferences',
      context: context,
      parse: StrengthPreferences.fromJson,
    );

    final planIntensityKey = requiredString(
      json,
      'planIntensity',
      context: context,
    );
    final planIntensity = PlanIntensity.fromKey(planIntensityKey);
    if (planIntensity == null) {
      throw FormatException(
        'Invalid $context: unsupported planIntensity "$planIntensityKey".',
      );
    }

    final unitPreference = optionalString(
      json,
      'unitPreference',
      context: context,
    );
    final locale = requiredString(json, 'locale', context: context);

    final raceCourseTerrain = optionalEnumFromKey(
      json,
      'raceCourseTerrain',
      context: context,
      parse: RaceCourseTerrain.fromKey,
      fieldLabel: 'raceCourseTerrain',
    );

    _validateFitnessInputContract(
      fitnessSource: fitnessSource,
      stravaCoachingProfile: stravaCoachingProfile,
      manualFitness: manualFitness,
    );

    return ProfessionalPlanInput(
      goal: goal,
      fitnessSource: fitnessSource,
      stravaCoachingProfile: stravaCoachingProfile,
      manualFitness: manualFitness,
      acceptedRaceTarget: acceptedRaceTarget,
      schedule: schedule,
      health: health,
      strengthPreferences: strengthPreferences,
      planIntensity: planIntensity,
      unitPreference: unitPreference,
      locale: locale,
      raceCourseTerrain: raceCourseTerrain,
    );
  }
}

void _validateFitnessInputContract({
  required FitnessSource fitnessSource,
  required StravaCoachingProfile? stravaCoachingProfile,
  required ManualFitnessInput? manualFitness,
}) {
  if (fitnessSource == FitnessSource.manual) {
    if (manualFitness == null) {
      throw const FormatException(
        'Invalid professional plan input: manual source requires manualFitness.',
      );
    }
    if (stravaCoachingProfile != null) {
      throw const FormatException(
        'Invalid professional plan input: manual source cannot include stravaCoachingProfile.',
      );
    }
    return;
  }

  if (stravaCoachingProfile == null) {
    throw const FormatException(
      'Invalid professional plan input: strava source requires stravaCoachingProfile.',
    );
  }

  if (stravaCoachingProfile.dataConfidence == StravaDataConfidence.high &&
      manualFitness != null) {
    throw const FormatException(
      'Invalid professional plan input: strong Strava data must not include manualFitness.',
    );
  }

  // limited confidence is intentionally allowed without manualFitness:
  // the plan generator will produce a conservative base plan and
  // the user can supplement with manual details in a later iteration.
}

GoalProfile _requiredGoalProfile(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = requiredMap(json, key, context: context);
  final nestedContext = '$context.goal';

  final raceKey = requiredString(value, 'race', context: nestedContext);
  final race = RunnerGoalRace.fromKey(raceKey);
  if (race == null) {
    throw FormatException(
      'Invalid $nestedContext: unsupported race "$raceKey".',
    );
  }

  final hasRaceDate = requiredBool(
    value,
    'hasRaceDate',
    context: nestedContext,
  );
  final raceDate = optionalDateTime(value, 'raceDate', context: nestedContext);
  if (hasRaceDate && raceDate == null) {
    throw const FormatException(
      'Invalid professional plan input.goal: raceDate is required when hasRaceDate is true.',
    );
  }

  final priorityKey = requiredString(value, 'priority', context: nestedContext);
  final priority = GoalPriority.fromKey(priorityKey);
  if (priority == null) {
    throw FormatException(
      'Invalid $nestedContext: unsupported priority "$priorityKey".',
    );
  }

  final currentTime = optionalDurationMs(
    value,
    'currentTimeMs',
    context: nestedContext,
  );
  final targetTime = optionalDurationMs(
    value,
    'targetTimeMs',
    context: nestedContext,
  );

  if (currentTime != null && currentTime <= Duration.zero) {
    throw const FormatException(
      'Invalid professional plan input.goal: currentTimeMs must be > 0 when present.',
    );
  }
  if (targetTime != null && targetTime <= Duration.zero) {
    throw const FormatException(
      'Invalid professional plan input.goal: targetTimeMs must be > 0 when present.',
    );
  }

  final requiresTimes = priority == GoalPriority.improveTime;
  if (requiresTimes && (currentTime == null || targetTime == null)) {
    throw const FormatException(
      'Invalid professional plan input.goal: improve time priority requires currentTimeMs and targetTimeMs.',
    );
  }

  return GoalProfile(
    race: race,
    hasRaceDate: hasRaceDate,
    raceDate: hasRaceDate ? raceDate : null,
    priority: priority,
    currentTime: requiresTimes ? currentTime : null,
    targetTime: requiresTimes ? targetTime : null,
  );
}

ScheduleProfile _requiredScheduleProfile(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = requiredMap(json, key, context: context);
  final nestedContext = '$context.schedule';

  final trainingDays = requiredInt(
    value,
    'trainingDays',
    context: nestedContext,
  );
  if (trainingDays <= 0) {
    throw const FormatException(
      'Invalid professional plan input.schedule: trainingDays must be > 0.',
    );
  }

  final longRunDay = requiredEnumFromKey(
    value,
    'longRunDay',
    context: nestedContext,
    parse: WeekdayChoice.fromKey,
  );
  final weekdayTime = requiredEnumFromKey(
    value,
    'weekdayTime',
    context: nestedContext,
    parse: TimeSlot.fromKey,
  );
  final weekendTime = requiredEnumFromKey(
    value,
    'weekendTime',
    context: nestedContext,
    parse: TimeSlot.fromKey,
  );

  final hardDays = optionalCanonicalSet(
    value,
    'hardDays',
    context: nestedContext,
    parse: WeekdayChoice.fromKey,
  );
  final preferredTimeOfDay = optionalEnumFromKey(
    value,
    'preferredTimeOfDay',
    context: nestedContext,
    parse: PreferredTimeOfDay.fromKey,
    fieldLabel: 'preferredTimeOfDay',
  );

  return ScheduleProfile(
    trainingDays: trainingDays,
    longRunDay: longRunDay,
    weekdayTime: weekdayTime,
    weekendTime: weekendTime,
    hardDays: hardDays,
    preferredTimeOfDay: preferredTimeOfDay,
  );
}

HealthProfile _requiredHealthProfile(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = requiredMap(json, key, context: context);
  final nestedContext = '$context.health';

  final painLevel = requiredEnumFromKey(
    value,
    'painLevel',
    context: nestedContext,
    parse: PainLevelChoice.fromKey,
  );
  final injuryHistory = requiredEnumFromKey(
    value,
    'injuryHistory',
    context: nestedContext,
    parse: InjuryHistoryChoice.fromKey,
  );
  final hasHealthConditions = requiredEnumFromKey(
    value,
    'hasHealthConditions',
    context: nestedContext,
    parse: BinaryChoice.fromKey,
  );

  return HealthProfile(
    painLevel: painLevel,
    injuryHistory: injuryHistory,
    hasHealthConditions: hasHealthConditions,
  );
}

Map<String, dynamic> _goalProfileToJson(GoalProfile value) {
  return {
    'race': value.race.key,
    'hasRaceDate': value.hasRaceDate,
    'raceDate': value.raceDate?.toIso8601String(),
    'priority': value.priority.key,
    'currentTimeMs': value.currentTime?.inMilliseconds,
    'targetTimeMs': value.targetTime?.inMilliseconds,
  };
}

Map<String, dynamic> _scheduleProfileToJson(ScheduleProfile value) {
  return {
    'trainingDays': value.trainingDays,
    'longRunDay': value.longRunDay.key,
    'weekdayTime': value.weekdayTime.key,
    'weekendTime': value.weekendTime.key,
    'hardDays': sortedCanonicalKeys(value.hardDays),
    'preferredTimeOfDay': value.preferredTimeOfDay?.key,
  };
}

Map<String, dynamic> _healthProfileToJson(HealthProfile value) {
  return {
    'painLevel': value.painLevel.key,
    'injuryHistory': value.injuryHistory.key,
    'hasHealthConditions': value.hasHealthConditions.key,
  };
}
