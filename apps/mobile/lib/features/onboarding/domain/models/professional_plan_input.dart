import '../../../profile/domain/models/runner_profile.dart';
import '../../../strava/domain/models/strava_coaching_profile.dart';
import '../../../training_plan/domain/models/model_json_utils.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import 'dart:math' as math;

/// Builds a [ProfessionalPlanInput] from the current onboarding draft and user
/// profile values. Returns `null` when required canonical values are missing.
ProfessionalPlanInput? buildProfessionalPlanInputFromOnboardingDraft({
  required RunnerProfileDraft draft,
  required UserPreferences preferences,
  required String locale,
  bool includePlanStartDate = true,
}) {
  final goal = draft.goal.toProfileOrNull();
  final health = draft.health.toProfileOrNull();
  final strengthPreferences = draft.strength.toProfileOrNull();
  final planIntensity = _planIntensityFromPreference(
    draft.trainingPreferences.planPreference,
  );
  final fitnessSource = FitnessSource.fromKey(draft.fitness.fitnessSource);

  if (goal == null ||
      health == null ||
      strengthPreferences == null ||
      planIntensity == null ||
      fitnessSource == null) {
    return null;
  }

  final acceptedRaceTarget = draft.acceptedRaceTarget;
  if (acceptedRaceTarget == null ||
      !_raceTargetMatchesGoal(acceptedRaceTarget, goal.race)) {
    return null;
  }

  final ManualFitnessInput? manualFitness;
  final StravaCoachingProfile? stravaCoachingProfile;
  final ScheduleProfile? schedule = _scheduleForProfessionalInput(
    draft.schedule,
    includePlanStartDate: includePlanStartDate,
  );

  if (schedule == null) return null;

  switch (fitnessSource) {
    case FitnessSource.manual:
      manualFitness = _manualFitnessFromDraft(draft.fitness);
      stravaCoachingProfile = null;
      if (manualFitness == null) return null;
    case FitnessSource.strava:
      stravaCoachingProfile = draft.fitness.stravaCoachingProfile;
      if (stravaCoachingProfile == null) return null;
      manualFitness = null;
  }

  return ProfessionalPlanInput(
    goal: goal,
    fitnessSource: fitnessSource,
    acceptedRaceTarget: acceptedRaceTarget,
    schedule: schedule,
    health: health,
    strengthPreferences: strengthPreferences,
    planIntensity: planIntensity,
    stravaCoachingProfile: stravaCoachingProfile,
    manualFitness: manualFitness,
    unitPreference: _unitPreferenceFrom(preferences.unitSystem),
    locale: locale,
    raceCourseTerrain: _raceCourseTerrainFrom(
      draft.fitness.stravaCoachingProfile,
    ),
  );
}

PlanIntensity? _planIntensityFromPreference(PlanPreferenceChoice? preference) {
  return switch (preference) {
    PlanPreferenceChoice.safest => PlanIntensity.conservative,
    PlanPreferenceChoice.balanced => PlanIntensity.balanced,
    PlanPreferenceChoice.performance => PlanIntensity.ambitious,
    _ => null,
  };
}

AcceptedRaceTarget? suggestedRaceTargetFromDraft(RunnerProfileDraft draft) {
  final goal = draft.goal;
  final goalDistance = _goalDistanceKm(goal.race);
  if (goalDistance == null) return null;

  final profileTargets = draft.fitness.stravaCoachingProfile?.raceTargets;
  if (profileTargets != null && profileTargets.isNotEmpty) {
    final matchingTarget = _matchingRaceTarget(profileTargets, goalDistance);
    if (matchingTarget != null) {
      return AcceptedRaceTarget(
        distanceKm: matchingTarget.distanceKm,
        primaryTime: matchingTarget.primaryTime,
        stretchTime: matchingTarget.stretchTime,
        confidence: matchingTarget.confidence,
        evidence: matchingTarget.evidence,
      );
    }
  }

  final fallbackRaceTargetTime = _fallbackRaceTargetTimeFromDraft(
    draft,
    goalDistance,
  );
  if (fallbackRaceTargetTime == null) return null;

  return AcceptedRaceTarget(
    distanceKm: goalDistance,
    primaryTime: fallbackRaceTargetTime,
    stretchTime: null,
    confidence: null,
    evidence: const [],
  );
}

StravaRaceTargetEstimate? _matchingRaceTarget(
  List<StravaRaceTargetEstimate> targets,
  double goalDistanceKm,
) {
  for (final target in targets) {
    if ((target.distanceKm - goalDistanceKm).abs() <=
        _raceDistanceToleranceKm) {
      return target;
    }
  }
  return null;
}

Duration? _fallbackRaceTargetTimeFromDraft(
  RunnerProfileDraft draft,
  double goalDistance,
) {
  final benchmarkTime = _projectedBenchmarkTimeForGoal(
    goalDistanceKm: goalDistance,
    benchmarkType: draft.fitness.benchmark,
    benchmarkTime: draft.fitness.benchmarkTime,
  );
  if (benchmarkTime != null) return benchmarkTime;

  return null;
}

Duration? _projectedBenchmarkTimeForGoal({
  required double goalDistanceKm,
  required BenchmarkType? benchmarkType,
  required Duration? benchmarkTime,
}) {
  if (benchmarkType == null ||
      benchmarkType == BenchmarkType.skip ||
      benchmarkTime == null ||
      benchmarkTime <= Duration.zero) {
    return null;
  }

  final benchmarkDistanceKm = _benchmarkDistanceKmFromType(benchmarkType);
  return _projectDurationToDistance(
    sourceTime: benchmarkTime,
    sourceDistanceKm: benchmarkDistanceKm,
    targetDistanceKm: goalDistanceKm,
  );
}

double _benchmarkDistanceKmFromType(BenchmarkType type) {
  return switch (type) {
    BenchmarkType.oneKmRun => 1.0,
    BenchmarkType.oneKmWalk => 1.0,
    BenchmarkType.oneMiRun => 1.60934,
    BenchmarkType.oneMiWalk => 1.60934,
    BenchmarkType.fiveK => 5.0,
    BenchmarkType.tenK => 10.0,
    BenchmarkType.halfMarathon => 21.0975,
    BenchmarkType.skip => 1.0,
  };
}

Duration? _projectDurationToDistance({
  required Duration sourceTime,
  required double sourceDistanceKm,
  required double targetDistanceKm,
}) {
  if (sourceDistanceKm <= 0 || targetDistanceKm <= 0) {
    return null;
  }
  if (sourceTime <= Duration.zero) {
    return null;
  }

  // Riegel exponent for endurance fade.
  const riegelExponent = 1.06;
  final projectedSeconds =
      sourceTime.inSeconds *
      math.pow(targetDistanceKm / sourceDistanceKm, riegelExponent);
  return Duration(seconds: projectedSeconds.round());
}

double? _goalDistanceKm(RunnerGoalRace? race) {
  return switch (race) {
    RunnerGoalRace.fiveK => 5,
    RunnerGoalRace.tenK => 10,
    RunnerGoalRace.halfMarathon => 21.097,
    RunnerGoalRace.marathon => 42.195,
    RunnerGoalRace.other || null => null,
  };
}

bool _raceTargetMatchesGoal(AcceptedRaceTarget target, RunnerGoalRace race) {
  final goalDistance = _goalDistanceKm(race);
  if (goalDistance == null) return false;
  return (target.distanceKm - goalDistance).abs() <= _raceDistanceToleranceKm;
}

const _raceDistanceToleranceKm = 0.05;

ManualFitnessInput? _manualFitnessFromDraft(FitnessProfileDraft draft) {
  if (draft.experience == null) return null;

  return ManualFitnessInput(
    experience: draft.experience!,
    weeklyVolume: draft.weeklyVolume,
    longestRun: draft.longestRun,
    canCompleteGoalDistance: draft.canCompleteGoalDistance,
    raceDistanceBefore: draft.raceDistanceBefore,
    benchmark: draft.benchmark,
    benchmarkTime: draft.benchmarkTime,
  );
}

RaceCourseTerrain? _raceCourseTerrainFrom(StravaCoachingProfile? profile) {
  return switch (profile?.terrain) {
    StravaTerrainProfile.flat => RaceCourseTerrain.flat,
    StravaTerrainProfile.rolling => RaceCourseTerrain.rolling,
    StravaTerrainProfile.hilly => RaceCourseTerrain.hilly,
    StravaTerrainProfile.notSure => RaceCourseTerrain.notSure,
    _ => null,
  };
}

String _unitPreferenceFrom(UnitSystem unitSystem) {
  return switch (unitSystem) {
    UnitSystem.miles => 'imperial',
    _ => 'metric',
  };
}

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
    return removeNullValues({
          'experience': experience.key,
          'weeklyVolume': weeklyVolume?.key,
          'longestRun': longestRun?.key,
          'canCompleteGoalDistance': canCompleteGoalDistance?.key,
          'raceDistanceBefore': raceDistanceBefore?.key,
          'benchmark': benchmark?.key,
          'benchmarkTimeMs': benchmarkTime?.inMilliseconds,
        })
        as Map<String, dynamic>;
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
    return removeNullValues({
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
        })
        as Map<String, dynamic>;
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

ScheduleProfile? _scheduleForProfessionalInput(
  ScheduleProfileDraft draftSchedule, {
  required bool includePlanStartDate,
}) {
  final schedule = draftSchedule.toProfileOrNull();
  if (schedule == null) {
    return null;
  }

  if (includePlanStartDate) {
    return schedule;
  }

  return ScheduleProfile(
    trainingDays: schedule.trainingDays,
    longRunDay: schedule.longRunDay,
    weekdayTime: schedule.weekdayTime,
    weekendTime: schedule.weekendTime,
    hardDays: schedule.hardDays,
    preferredTimeOfDay: schedule.preferredTimeOfDay,
    planStartDate: null,
  );
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

  return GoalProfile(
    race: race,
    hasRaceDate: hasRaceDate,
    raceDate: hasRaceDate ? raceDate : null,
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
  final parsedPlanStartDate = _parseDateOnly(
    value,
    'planStartDate',
    context: nestedContext,
  );

  return ScheduleProfile(
    trainingDays: trainingDays,
    longRunDay: longRunDay,
    weekdayTime: weekdayTime,
    weekendTime: weekendTime,
    hardDays: hardDays,
    preferredTimeOfDay: preferredTimeOfDay,
    planStartDate: parsedPlanStartDate,
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
  return removeNullValues({
        'race': value.race.key,
        'hasRaceDate': value.hasRaceDate,
        'raceDate': value.raceDate?.toIso8601String(),
      })
      as Map<String, dynamic>;
}

Map<String, dynamic> _scheduleProfileToJson(ScheduleProfile value) {
  return removeNullValues({
        'trainingDays': value.trainingDays,
        'longRunDay': value.longRunDay.key,
        'weekdayTime': value.weekdayTime.key,
        'weekendTime': value.weekendTime.key,
        'hardDays': sortedCanonicalKeys(value.hardDays),
        'preferredTimeOfDay': value.preferredTimeOfDay?.key,
        'planStartDate': _dateToDateOnlyString(value.planStartDate),
      })
      as Map<String, dynamic>;
}

String? _dateToDateOnlyString(DateTime? value) {
  if (value == null) return null;
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? _parseDateOnly(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  if (!json.containsKey(key)) return null;

  final raw = json[key];
  if (raw == null) return null;
  if (raw is! String || raw.isEmpty) {
    throw FormatException('Invalid $context: $key must be an ISO date string.');
  }

  final dateOnlyMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (dateOnlyMatch == null) {
    throw FormatException(
      'Invalid $context: $key must be in YYYY-MM-DD format.',
    );
  }

  final year = int.parse(dateOnlyMatch.group(1)!);
  final month = int.parse(dateOnlyMatch.group(2)!);
  final day = int.parse(dateOnlyMatch.group(3)!);
  final parsed = DateTime(year, month, day);

  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw FormatException(
      'Invalid $context: $key must be a valid date in YYYY-MM-DD format.',
    );
  }

  return parsed;
}

Map<String, dynamic> _healthProfileToJson(HealthProfile value) {
  return {
    'painLevel': value.painLevel.key,
    'injuryHistory': value.injuryHistory.key,
    'hasHealthConditions': value.hasHealthConditions.key,
  };
}
