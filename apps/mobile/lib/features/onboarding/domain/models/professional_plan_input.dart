import '../../../profile/domain/models/runner_profile.dart';
import '../../../strava/domain/models/strava_coaching_profile.dart';

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
    final experienceKey = _requiredString(json, 'experience', context: context);
    final experience = RunnerExperience.fromKey(experienceKey);
    if (experience == null) {
      throw FormatException(
        'Invalid $context: unsupported experience "$experienceKey".',
      );
    }

    final weeklyVolume = _optionalEnumFromKey(
      json,
      'weeklyVolume',
      context: context,
      parse: WeeklyVolumeRange.fromKey,
      fieldLabel: 'weeklyVolume',
    );
    final longestRun = _optionalEnumFromKey(
      json,
      'longestRun',
      context: context,
      parse: LongestRunRange.fromKey,
      fieldLabel: 'longestRun',
    );
    final canCompleteGoalDistance = _optionalEnumFromKey(
      json,
      'canCompleteGoalDistance',
      context: context,
      parse: TernaryChoice.fromKey,
      fieldLabel: 'canCompleteGoalDistance',
    );
    final raceDistanceBefore = _optionalEnumFromKey(
      json,
      'raceDistanceBefore',
      context: context,
      parse: RaceDistanceExperience.fromKey,
      fieldLabel: 'raceDistanceBefore',
    );
    final benchmark = _optionalEnumFromKey(
      json,
      'benchmark',
      context: context,
      parse: BenchmarkType.fromKey,
      fieldLabel: 'benchmark',
    );
    final benchmarkTime = _optionalDurationMs(
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
        'Invalid manual fitness input: benchmarkTimeMs is only allowed for a non-skip benchmark.',
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

    final fitnessSourceKey = _requiredString(
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

    final stravaCoachingProfile = _optionalNested(
      json,
      'stravaCoachingProfile',
      context: context,
      parse: StravaCoachingProfile.fromJson,
    );
    final manualFitness = _optionalNested(
      json,
      'manualFitness',
      context: context,
      parse: ManualFitnessInput.fromJson,
    );

    final acceptedRaceTarget = _requiredNested(
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
    final strengthPreferences = _requiredNested(
      json,
      'strengthPreferences',
      context: context,
      parse: StrengthPreferences.fromJson,
    );

    final planIntensityKey = _requiredString(
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

    final unitPreference = _optionalString(
      json,
      'unitPreference',
      context: context,
    );
    final locale = _requiredString(json, 'locale', context: context);

    final raceCourseTerrain = _optionalEnumFromKey(
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
}

GoalProfile _requiredGoalProfile(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = _requiredMap(json, key, context: context);
  final nestedContext = '$context.goal';

  final raceKey = _requiredString(value, 'race', context: nestedContext);
  final race = RunnerGoalRace.fromKey(raceKey);
  if (race == null) {
    throw FormatException(
      'Invalid $nestedContext: unsupported race "$raceKey".',
    );
  }

  final hasRaceDate = _requiredBool(
    value,
    'hasRaceDate',
    context: nestedContext,
  );
  final raceDate = _optionalDateTime(value, 'raceDate', context: nestedContext);
  if (hasRaceDate && raceDate == null) {
    throw const FormatException(
      'Invalid professional plan input.goal: raceDate is required when hasRaceDate is true.',
    );
  }

  final priorityKey = _requiredString(
    value,
    'priority',
    context: nestedContext,
  );
  final priority = GoalPriority.fromKey(priorityKey);
  if (priority == null) {
    throw FormatException(
      'Invalid $nestedContext: unsupported priority "$priorityKey".',
    );
  }

  final currentTime = _optionalDurationMs(
    value,
    'currentTimeMs',
    context: nestedContext,
  );
  final targetTime = _optionalDurationMs(
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
  final value = _requiredMap(json, key, context: context);
  final nestedContext = '$context.schedule';

  final trainingDays = _requiredInt(
    value,
    'trainingDays',
    context: nestedContext,
  );
  if (trainingDays <= 0) {
    throw const FormatException(
      'Invalid professional plan input.schedule: trainingDays must be > 0.',
    );
  }

  final longRunDay = _requiredEnumFromKey(
    value,
    'longRunDay',
    context: nestedContext,
    parse: WeekdayChoice.fromKey,
  );
  final weekdayTime = _requiredEnumFromKey(
    value,
    'weekdayTime',
    context: nestedContext,
    parse: TimeSlot.fromKey,
  );
  final weekendTime = _requiredEnumFromKey(
    value,
    'weekendTime',
    context: nestedContext,
    parse: TimeSlot.fromKey,
  );

  final hardDays = _optionalCanonicalSet(
    value,
    'hardDays',
    context: nestedContext,
    parse: WeekdayChoice.fromKey,
  );
  final preferredTimeOfDay = _optionalEnumFromKey(
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
  final value = _requiredMap(json, key, context: context);
  final nestedContext = '$context.health';

  final painLevel = _requiredEnumFromKey(
    value,
    'painLevel',
    context: nestedContext,
    parse: PainLevelChoice.fromKey,
  );
  final injuryHistory = _requiredEnumFromKey(
    value,
    'injuryHistory',
    context: nestedContext,
    parse: InjuryHistoryChoice.fromKey,
  );
  final hasHealthConditions = _requiredEnumFromKey(
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
    'hardDays': _sortedCanonicalKeys(value.hardDays),
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

List<String> _sortedCanonicalKeys<T extends CanonicalKeyed>(
  Iterable<T> values,
) {
  final keys = values.map((value) => value.key).toList(growable: false);
  keys.sort();
  return keys;
}

T _requiredNested<T>(
  Map<String, dynamic> json,
  String key, {
  required String context,
  required T Function(Map<String, dynamic> value) parse,
}) {
  return parse(_requiredMap(json, key, context: context));
}

T? _optionalNested<T>(
  Map<String, dynamic> json,
  String key, {
  required String context,
  required T Function(Map<String, dynamic> value) parse,
}) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) {
    throw FormatException('Invalid $context: $key must be an object.');
  }
  return parse(value.cast<String, dynamic>());
}

T _requiredEnumFromKey<T>(
  Map<String, dynamic> json,
  String key, {
  required String context,
  required T? Function(String? key) parse,
}) {
  final value = _requiredString(json, key, context: context);
  final parsed = parse(value);
  if (parsed == null) {
    throw FormatException('Invalid $context: unsupported $key "$value".');
  }
  return parsed;
}

T? _optionalEnumFromKey<T>(
  Map<String, dynamic> json,
  String key, {
  required String context,
  required T? Function(String? key) parse,
  required String fieldLabel,
}) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException(
      'Invalid $context: $fieldLabel must be a string key.',
    );
  }
  final parsed = parse(value);
  if (parsed == null) {
    throw FormatException(
      'Invalid $context: unsupported $fieldLabel "$value".',
    );
  }
  return parsed;
}

Set<T> _optionalCanonicalSet<T>(
  Map<String, dynamic> json,
  String key, {
  required String context,
  required T? Function(String? key) parse,
}) {
  final value = json[key];
  if (value == null) return const {};
  if (value is! List) {
    throw FormatException('Invalid $context: $key must be a list of keys.');
  }

  final parsedValues = <T>{};
  for (final entry in value) {
    if (entry is! String) {
      throw FormatException('Invalid $context: $key entries must be strings.');
    }
    final parsed = parse(entry);
    if (parsed == null) {
      throw FormatException(
        'Invalid $context: unsupported $key entry "$entry".',
      );
    }
    parsedValues.add(parsed);
  }

  return parsedValues;
}

Map<String, dynamic> _requiredMap(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('Invalid $context: $key must be an object.');
  }
  return value.cast<String, dynamic>();
}

String _requiredString(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $context: $key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $context: $key must be a non-empty string.');
  }
  return value;
}

bool _requiredBool(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Invalid $context: $key must be a bool.');
}

int _requiredInt(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final parsed = _intOrNull(json[key]);
  if (parsed == null) {
    throw FormatException('Invalid $context: $key must be an int.');
  }
  return parsed;
}

Duration? _optionalDurationMs(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw == null) return null;

  final milliseconds = _intOrNull(raw);
  if (milliseconds == null) {
    throw FormatException('Invalid $context: $key must be an int duration.');
  }
  return Duration(milliseconds: milliseconds);
}

DateTime? _optionalDateTime(
  Map<String, dynamic> json,
  String key, {
  required String context,
}) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('Invalid $context: $key must be an ISO date string.');
  }

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('Invalid $context: $key must be an ISO date string.');
  }
  return parsed;
}

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is double && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  if (value is String && value.trim().isNotEmpty) {
    return int.tryParse(value);
  }
  return null;
}
