import '../../../user_preferences/domain/user_preferences.dart';
import '../../../strava/domain/athlete_summary.dart';
import '../../../training_plan/domain/models/model_json_utils.dart';

T? _enumByKey<T extends Enum>(
  String? key,
  List<T> values,
  String Function(T value) keyOf,
) {
  if (key == null) return null;
  for (final value in values) {
    if (keyOf(value) == key) return value;
  }
  return null;
}

Set<T> _enumSetByKeys<T extends Enum>(
  Iterable<String>? keys,
  List<T> values,
  String Function(T value) keyOf,
) {
  if (keys == null) return const {};
  return {for (final key in keys) ?_enumByKey(key, values, keyOf)};
}

int? _intFromString(String? value) {
  if (value == null) return null;
  final normalized = value.trim();
  final parseable = normalized.endsWith('+')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
  return int.tryParse(parseable);
}

String? _stringOrNull(Object? value) => value is String ? value : null;

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _doubleFromJson(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool? _boolOrNull(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    return switch (value.toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }
  return null;
}

DateTime? _dateTimeFromJson(Object? value) {
  final raw = _stringOrNull(value);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

String? _dateOnlyToJson(DateTime? value) {
  if (value == null) return null;
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? _dateOnlyFromJson(Object? value) {
  final raw = _stringOrNull(value);
  if (raw == null || raw.isEmpty) return null;
  final dateOnlyMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (dateOnlyMatch == null) return null;

  final year = int.parse(dateOnlyMatch.group(1)!);
  final month = int.parse(dateOnlyMatch.group(2)!);
  final day = int.parse(dateOnlyMatch.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

int? _durationToJson(Duration? value) => value?.inMilliseconds;

Duration? _durationFromJson(Object? value) {
  final milliseconds = _intOrNull(value);
  return milliseconds == null ? null : Duration(milliseconds: milliseconds);
}

List<String> _stringListOrEmpty(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false)..sort();
}

Map<String, dynamic> _mapOrEmpty(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, nestedValue) => MapEntry('$key', nestedValue));
}

List<String> _sortedCanonicalKeys<T extends CanonicalKeyed>(
  Iterable<T> values,
) {
  final keys = values.map((value) => value.key).toList(growable: false);
  keys.sort();
  return keys;
}

ProfileGender? _profileGenderFromName(String? value) {
  return switch (value) {
    'male' => ProfileGender.male,
    'female' => ProfileGender.female,
    'other' => ProfileGender.other,
    _ => null,
  };
}

VolumeTrend? _volumeTrendFromKey(String? key) {
  return switch (key) {
    'building' => VolumeTrend.building,
    'steady' => VolumeTrend.steady,
    'detraining' => VolumeTrend.detraining,
    _ => null,
  };
}

enum BinaryChoice implements CanonicalKeyed {
  yes('yes'),
  no('no');

  const BinaryChoice(this.key);

  @override
  final String key;

  static BinaryChoice? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum TernaryChoice implements CanonicalKeyed {
  yes('yes'),
  no('no'),
  notSure('not_sure');

  const TernaryChoice(this.key);

  @override
  final String key;

  static TernaryChoice? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum RunnerGoalRace implements CanonicalKeyed {
  fiveK('race_5k'),
  tenK('race_10k'),
  halfMarathon('race_half_marathon'),
  marathon('race_marathon'),
  other('race_other');

  const RunnerGoalRace(this.key);

  @override
  final String key;

  static RunnerGoalRace? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum RunnerExperience implements CanonicalKeyed {
  brandNew('experience_brand_new'),
  beginner('experience_beginner'),
  intermediate('experience_intermediate'),
  experienced('experience_experienced');

  const RunnerExperience(this.key);

  @override
  final String key;

  static RunnerExperience? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum BenchmarkType implements CanonicalKeyed {
  oneKmRun('benchmark_1km_run'),
  oneKmWalk('benchmark_1km_walk'),
  oneMiRun('benchmark_1mi_run'),
  oneMiWalk('benchmark_1mi_walk'),
  fiveK('benchmark_5k'),
  tenK('benchmark_10k'),
  halfMarathon('benchmark_half_marathon'),
  skip('benchmark_skip');

  const BenchmarkType(this.key);

  @override
  final String key;

  static BenchmarkType? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum RaceDistanceExperience implements CanonicalKeyed {
  never('race_distance_never'),
  once('race_distance_once'),
  twoToThree('race_distance_2_to_3'),
  fourPlus('race_distance_4_plus');

  const RaceDistanceExperience(this.key);

  @override
  final String key;

  static RaceDistanceExperience? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum WeeklyVolumeRange implements CanonicalKeyed {
  volume0('weekly_volume_0'),
  volume1('weekly_volume_1'),
  volume2('weekly_volume_2'),
  volume3('weekly_volume_3'),
  volume4('weekly_volume_4'),
  volume5('weekly_volume_5'),
  volume6('weekly_volume_6');

  const WeeklyVolumeRange(this.key);

  @override
  final String key;

  static WeeklyVolumeRange? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum LongestRunRange implements CanonicalKeyed {
  run0('longest_run_0'),
  run1('longest_run_1'),
  run2('longest_run_2'),
  run3('longest_run_3'),
  run4('longest_run_4'),
  run5('longest_run_5'),
  run6('longest_run_6');

  const LongestRunRange(this.key);

  @override
  final String key;

  static LongestRunRange? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum WeekdayChoice implements CanonicalKeyed {
  monday('day_mon'),
  tuesday('day_tue'),
  wednesday('day_wed'),
  thursday('day_thu'),
  friday('day_fri'),
  saturday('day_sat'),
  sunday('day_sun');

  const WeekdayChoice(this.key);

  @override
  final String key;

  static WeekdayChoice? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum TimeSlot implements CanonicalKeyed {
  min20('time_20_min'),
  min30('time_30_min'),
  min45('time_45_min'),
  min60('time_60_min'),
  min75Plus('time_75_plus_min'),
  min90('time_90_min'),
  hours2Plus('time_2_plus_hours');

  const TimeSlot(this.key);

  @override
  final String key;

  static TimeSlot? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum PreferredTimeOfDay implements CanonicalKeyed {
  earlyMorning('time_of_day_early_morning'),
  morning('time_of_day_morning'),
  afternoon('time_of_day_afternoon'),
  evening('time_of_day_evening'),
  noPreference('time_of_day_no_preference');

  const PreferredTimeOfDay(this.key);

  @override
  final String key;

  static PreferredTimeOfDay? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum PainLevelChoice implements CanonicalKeyed {
  none('pain_no'),
  mild('pain_mild'),
  moderate('pain_moderate'),
  severe('pain_severe');

  const PainLevelChoice(this.key);

  @override
  final String key;

  static PainLevelChoice? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum InjuryHistoryChoice implements CanonicalKeyed {
  none('injury_no'),
  once('injury_once'),
  multiple('injury_multiple');

  const InjuryHistoryChoice(this.key);

  @override
  final String key;

  static InjuryHistoryChoice? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum PlanPreferenceChoice implements CanonicalKeyed {
  safest('plan_safest'),
  balanced('plan_balanced'),
  performance('plan_performance');

  const PlanPreferenceChoice(this.key);

  @override
  final String key;

  static PlanPreferenceChoice? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum FitnessSource implements CanonicalKeyed {
  strava('strava'),
  manual('manual');

  const FitnessSource(this.key);

  @override
  final String key;

  static FitnessSource? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum PlanIntensity implements CanonicalKeyed {
  conservative('conservative'),
  balanced('balanced'),
  ambitious('ambitious');

  const PlanIntensity(this.key);

  @override
  final String key;

  static PlanIntensity? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum StrengthCategory implements CanonicalKeyed {
  lowerBody('lower_body'),
  upperBody('upper_body'),
  coreMobility('core_mobility'),
  fullBody('full_body');

  const StrengthCategory(this.key);

  @override
  final String key;

  static StrengthCategory? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum SameDayOrderPreference implements CanonicalKeyed {
  runFirst('run_first'),
  liftFirst('lift_first'),
  separateSessions('separate_sessions'),
  itDepends('it_depends');

  const SameDayOrderPreference(this.key);

  @override
  final String key;

  static SameDayOrderPreference? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum RaceCourseTerrain implements CanonicalKeyed {
  flat('flat'),
  rolling('rolling'),
  hilly('hilly'),
  notSure('not_sure');

  const RaceCourseTerrain(this.key);

  @override
  final String key;

  static RaceCourseTerrain? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

class StrengthPreferences {
  const StrengthPreferences({
    required this.lifts,
    this.weeklyFrequency,
    this.categories = const {},
    this.preferredDays = const {},
    this.sameDayOrder,
  });

  final bool lifts;
  final int? weeklyFrequency;
  final Set<StrengthCategory> categories;
  final Set<WeekdayChoice> preferredDays;
  final SameDayOrderPreference? sameDayOrder;

  Map<String, dynamic> toJson() {
    return {
      'lifts': lifts,
      'weeklyFrequency': weeklyFrequency,
      'categories': _sortedCanonicalKeys(categories),
      'preferredDays': _sortedCanonicalKeys(preferredDays),
      'sameDayOrder': sameDayOrder?.key,
    };
  }

  factory StrengthPreferences.fromJson(Map<String, dynamic> json) {
    final lifts = _boolOrNull(json['lifts']);
    if (lifts == null) {
      if (!json.containsKey('lifts')) {
        return const StrengthPreferences(
          lifts: false,
          weeklyFrequency: null,
          categories: {},
          preferredDays: {},
          sameDayOrder: null,
        );
      }
      throw const FormatException(
        'Invalid strength preferences: lifts must be a bool.',
      );
    }

    final weeklyFrequency = _intOrNull(json['weeklyFrequency']);
    final hasInvalidWeeklyFrequency =
        json.containsKey('weeklyFrequency') &&
        json['weeklyFrequency'] != null &&
        weeklyFrequency == null;
    if (hasInvalidWeeklyFrequency) {
      throw const FormatException(
        'Invalid strength preferences: weeklyFrequency must be an int.',
      );
    }
    if (weeklyFrequency != null && weeklyFrequency <= 0) {
      throw const FormatException(
        'Invalid strength preferences: weeklyFrequency must be > 0.',
      );
    }

    final categories = <StrengthCategory>{};
    final rawCategories = json['categories'];
    if (rawCategories != null && rawCategories is! List) {
      throw const FormatException(
        'Invalid strength preferences: categories must be a list.',
      );
    }
    if (rawCategories is List) {
      for (final value in rawCategories) {
        if (value is! String) {
          throw const FormatException(
            'Invalid strength preferences: category must be a string key.',
          );
        }
        final parsed = StrengthCategory.fromKey(value);
        if (parsed == null) {
          throw FormatException(
            'Invalid strength preferences: unsupported category "$value".',
          );
        }
        categories.add(parsed);
      }
    }

    final preferredDays = <WeekdayChoice>{};
    final rawPreferredDays = json['preferredDays'];
    if (rawPreferredDays != null && rawPreferredDays is! List) {
      throw const FormatException(
        'Invalid strength preferences: preferredDays must be a list.',
      );
    }
    if (rawPreferredDays is List) {
      for (final value in rawPreferredDays) {
        if (value is! String) {
          throw const FormatException(
            'Invalid strength preferences: preferred day must be a string key.',
          );
        }
        final parsed = WeekdayChoice.fromKey(value);
        if (parsed == null) {
          throw FormatException(
            'Invalid strength preferences: unsupported preferred day "$value".',
          );
        }
        preferredDays.add(parsed);
      }
    }

    SameDayOrderPreference? sameDayOrder;
    final rawSameDayOrder = json['sameDayOrder'];
    if (rawSameDayOrder != null) {
      if (rawSameDayOrder is! String) {
        throw const FormatException(
          'Invalid strength preferences: sameDayOrder must be a string key.',
        );
      }
      sameDayOrder = SameDayOrderPreference.fromKey(rawSameDayOrder);
      if (sameDayOrder == null) {
        throw FormatException(
          'Invalid strength preferences: unsupported sameDayOrder "$rawSameDayOrder".',
        );
      }
    }

    return StrengthPreferences(
      lifts: lifts,
      weeklyFrequency: weeklyFrequency,
      categories: categories,
      preferredDays: preferredDays,
      sameDayOrder: sameDayOrder,
    );
  }
}

class StrengthProfileDraft {
  const StrengthProfileDraft({
    this.lifts,
    this.weeklyFrequency,
    this.categories = const {},
    this.preferredDays = const {},
    this.sameDayOrder,
  });

  final bool? lifts;
  final int? weeklyFrequency;
  final Set<StrengthCategory> categories;
  final Set<WeekdayChoice> preferredDays;
  final SameDayOrderPreference? sameDayOrder;

  StrengthPreferences? toProfileOrNull() {
    if (lifts == null) {
      return null;
    }
    if (lifts == false) {
      return const StrengthPreferences(lifts: false);
    }

    if (weeklyFrequency == null ||
        weeklyFrequency! <= 0 ||
        categories.isEmpty ||
        preferredDays.isEmpty ||
        sameDayOrder == null) {
      return null;
    }

    return StrengthPreferences(
      lifts: true,
      weeklyFrequency: weeklyFrequency,
      categories: categories,
      preferredDays: preferredDays,
      sameDayOrder: sameDayOrder,
    );
  }
}

class AcceptedRaceTarget {
  const AcceptedRaceTarget({
    required this.distanceKm,
    required this.primaryTime,
    this.stretchTime,
    this.confidence,
    this.evidence = const [],
  });

  final double distanceKm;
  final Duration primaryTime;
  final Duration? stretchTime;
  final StravaDataConfidence? confidence;
  final List<StravaEvidencePoint> evidence;

  Map<String, dynamic> toJson() {
    return removeNullValues({
          'distanceKm': distanceKm,
          'primaryTimeMs': primaryTime.inMilliseconds,
          'stretchTimeMs': _durationToJson(stretchTime),
          'confidence': confidence?.key,
          'evidence': evidence
              .map((point) => point.toJson())
              .toList(growable: false),
        })
        as Map<String, dynamic>;
  }

  factory AcceptedRaceTarget.fromJson(Map<String, dynamic> json) {
    final distanceKm = _doubleFromJson(json['distanceKm']);
    if (distanceKm == null || !distanceKm.isFinite || distanceKm <= 0) {
      throw const FormatException(
        'Invalid accepted race target: distanceKm must be a finite number > 0.',
      );
    }

    final primaryTime = _durationFromJson(json['primaryTimeMs']);
    if (primaryTime == null || primaryTime <= Duration.zero) {
      throw const FormatException(
        'Invalid accepted race target: primaryTimeMs must be > 0.',
      );
    }

    final stretchTime = _durationFromJson(json['stretchTimeMs']);
    final hasInvalidStretchTime =
        json.containsKey('stretchTimeMs') &&
        json['stretchTimeMs'] != null &&
        stretchTime == null;
    if (hasInvalidStretchTime) {
      throw const FormatException(
        'Invalid accepted race target: stretchTimeMs must be an int duration.',
      );
    }
    if (stretchTime != null && stretchTime <= Duration.zero) {
      throw const FormatException(
        'Invalid accepted race target: stretchTimeMs must be > 0 when present.',
      );
    }

    StravaDataConfidence? confidence;
    final rawConfidence = json['confidence'];
    if (rawConfidence != null) {
      if (rawConfidence is! String) {
        throw const FormatException(
          'Invalid accepted race target: confidence must be a string key.',
        );
      }
      confidence = StravaDataConfidence.fromKey(rawConfidence);
      if (confidence == null) {
        throw FormatException(
          'Invalid accepted race target: unsupported confidence "$rawConfidence".',
        );
      }
    }

    final rawEvidence = json['evidence'];
    final evidence = switch (rawEvidence) {
      null => const <StravaEvidencePoint>[],
      List entries =>
        entries
            .map((entry) {
              if (entry is! Map) {
                throw const FormatException(
                  'Invalid accepted race target: evidence entries must be objects.',
                );
              }
              return StravaEvidencePoint.fromJson(
                entry.cast<String, dynamic>(),
              );
            })
            .toList(growable: false),
      _ => throw const FormatException(
        'Invalid accepted race target: evidence must be a list.',
      ),
    };

    return AcceptedRaceTarget(
      distanceKm: distanceKm,
      primaryTime: primaryTime,
      stretchTime: stretchTime,
      confidence: confidence,
      evidence: evidence,
    );
  }
}

enum WatchDeviceType implements CanonicalKeyed {
  garmin('device_garmin'),
  appleWatch('device_apple_watch'),
  coros('device_coros'),
  polar('device_polar'),
  suunto('device_suunto'),
  fitbit('device_fitbit'),
  other('device_other');

  const WatchDeviceType(this.key);

  @override
  final String key;

  static WatchDeviceType? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum DataUsagePreference implements CanonicalKeyed {
  importAuto('data_usage_import_auto'),
  hrOnly('data_usage_hr_only'),
  paceDistance('data_usage_pace_distance'),
  all('data_usage_all'),
  notSure('data_usage_not_sure');

  const DataUsagePreference(this.key);

  @override
  final String key;

  static DataUsagePreference? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum WatchMetricsPreference implements CanonicalKeyed {
  onlyIfNeeded('only_if_needed'),
  ifSupported('if_supported'),
  hrOnly('hr_only'),
  none('none');

  const WatchMetricsPreference(this.key);

  @override
  final String key;

  static WatchMetricsPreference? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum WatchMetric implements CanonicalKeyed {
  heartRate('metric_heart_rate'),
  heartRateZones('metric_heart_rate_zones'),
  pace('metric_pace'),
  distance('metric_distance'),
  cadence('metric_cadence'),
  elevation('metric_elevation'),
  trainingLoad('metric_training_load'),
  recoveryTime('metric_recovery_time');

  const WatchMetric(this.key);

  @override
  final String key;

  static WatchMetric? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum AutoAdjustPreference implements CanonicalKeyed {
  auto('auto_adjust_auto'),
  askFirst('auto_adjust_ask_first'),
  no('auto_adjust_no');

  const AutoAdjustPreference(this.key);

  @override
  final String key;

  static AutoAdjustPreference? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum NoWatchGuidanceChoice implements CanonicalKeyed {
  effortOnly('no_watch_effort_only'),
  timeBased('no_watch_time_based'),
  beginner('no_watch_beginner'),
  decideForMe('no_watch_decide_for_me');

  const NoWatchGuidanceChoice(this.key);

  @override
  final String key;

  static NoWatchGuidanceChoice? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

class GoalProfile {
  const GoalProfile({
    required this.race,
    required this.hasRaceDate,
    this.raceDate,
  });

  final RunnerGoalRace race;
  final bool hasRaceDate;
  final DateTime? raceDate;
}

class GoalProfileDraft {
  const GoalProfileDraft({this.race, this.hasRaceDate, this.raceDate});

  final RunnerGoalRace? race;
  final bool? hasRaceDate;
  final DateTime? raceDate;

  String? get raceKey => race?.key;

  GoalProfile? toProfileOrNull() {
    if (race == null || hasRaceDate == null) return null;
    if (hasRaceDate == true && raceDate == null) return null;

    return GoalProfile(
      race: race!,
      hasRaceDate: hasRaceDate!,
      raceDate: hasRaceDate == true ? raceDate : null,
    );
  }
}

class AthleteSummarySnapshot {
  const AthleteSummarySnapshot({
    this.weeklyVolumeKm,
    this.volumeTrend,
    this.acuteChronicRatio,
    this.longestRecentRunKm,
    this.typicalEasyPaceSecPerKm,
    this.typicalHardPaceSecPerKm,
    this.estimatedThresholdPaceSecPerKm,
    this.runsPerWeek,
    this.longestLayoffDays,
    this.weeksActiveInLast8,
    this.dataWeeks,
    this.insufficientData,
    this.hasHeartRateZones,
  });

  final double? weeklyVolumeKm;
  final VolumeTrend? volumeTrend;
  final double? acuteChronicRatio;
  final double? longestRecentRunKm;
  final int? typicalEasyPaceSecPerKm;
  final int? typicalHardPaceSecPerKm;
  final int? estimatedThresholdPaceSecPerKm;
  final double? runsPerWeek;
  final int? longestLayoffDays;
  final int? weeksActiveInLast8;
  final int? dataWeeks;
  final bool? insufficientData;
  final bool? hasHeartRateZones;

  bool get hasData =>
      weeklyVolumeKm != null ||
      volumeTrend != null ||
      acuteChronicRatio != null ||
      longestRecentRunKm != null ||
      typicalEasyPaceSecPerKm != null ||
      typicalHardPaceSecPerKm != null ||
      estimatedThresholdPaceSecPerKm != null ||
      runsPerWeek != null ||
      longestLayoffDays != null ||
      weeksActiveInLast8 != null ||
      dataWeeks != null ||
      insufficientData != null ||
      hasHeartRateZones != null;
}

class FitnessProfile {
  const FitnessProfile({
    required this.experience,
    this.canRun10Min,
    this.runningDays,
    this.weeklyVolume,
    this.longestRun,
    this.canCompleteGoalDistance,
    this.raceDistanceBefore,
    this.benchmark,
    this.benchmarkTime,
    this.fitnessSource,
    this.athleteSummary,
    this.stravaCoachingProfile,
  });

  final RunnerExperience experience;
  final bool? canRun10Min;
  final int? runningDays;
  final WeeklyVolumeRange? weeklyVolume;
  final LongestRunRange? longestRun;
  final TernaryChoice? canCompleteGoalDistance;
  final RaceDistanceExperience? raceDistanceBefore;
  final BenchmarkType? benchmark;
  final Duration? benchmarkTime;
  final FitnessSource? fitnessSource;
  final AthleteSummarySnapshot? athleteSummary;
  final StravaCoachingProfile? stravaCoachingProfile;
}

class FitnessProfileDraft {
  const FitnessProfileDraft({
    this.experience,
    this.canRun10Min,
    this.runningDays,
    this.weeklyVolume,
    this.longestRun,
    this.canCompleteGoalDistance,
    this.raceDistanceBefore,
    this.benchmark,
    this.benchmarkTime,
    this.fitnessSource,
    this.stravaWeeklyVolumeKm,
    this.stravaLongestRecentRunKm,
    this.stravaRunsPerWeek,
    this.stravaDataWeeks,
    this.stravaInsufficientData,
    this.athleteSummary,
    this.stravaCoachingProfile,
  });

  final RunnerExperience? experience;
  final bool? canRun10Min;
  final int? runningDays;
  final WeeklyVolumeRange? weeklyVolume;
  final LongestRunRange? longestRun;
  final TernaryChoice? canCompleteGoalDistance;
  final RaceDistanceExperience? raceDistanceBefore;
  final BenchmarkType? benchmark;
  final Duration? benchmarkTime;
  final String? fitnessSource;
  final double? stravaWeeklyVolumeKm;
  final double? stravaLongestRecentRunKm;
  final double? stravaRunsPerWeek;
  final int? stravaDataWeeks;
  final bool? stravaInsufficientData;
  final AthleteSummarySnapshot? athleteSummary;
  final StravaCoachingProfile? stravaCoachingProfile;

  String? get experienceKey => experience?.key;
  String? get runningDaysKey => runningDays?.toString();
  String? get weeklyVolumeKey => weeklyVolume?.key;
  String? get longestRunKey => longestRun?.key;
  String? get canCompleteGoalDistanceKey => canCompleteGoalDistance?.key;
  String? get raceDistanceBeforeKey => raceDistanceBefore?.key;
  String? get benchmarkKey => benchmark?.key;

  FitnessProfile? toProfileOrNull() {
    if (experience == null) return null;

    if (experience == RunnerExperience.brandNew) {
      if (canRun10Min == null) return null;
    } else if (runningDays == null ||
        weeklyVolume == null ||
        longestRun == null ||
        canCompleteGoalDistance == null ||
        raceDistanceBefore == null) {
      return null;
    }

    if (benchmark != null &&
        benchmark != BenchmarkType.skip &&
        benchmarkTime == null) {
      return null;
    }

    return FitnessProfile(
      experience: experience!,
      canRun10Min: experience == RunnerExperience.brandNew ? canRun10Min : null,
      runningDays: experience == RunnerExperience.brandNew ? null : runningDays,
      weeklyVolume: experience == RunnerExperience.brandNew
          ? null
          : weeklyVolume,
      longestRun: experience == RunnerExperience.brandNew ? null : longestRun,
      canCompleteGoalDistance: experience == RunnerExperience.brandNew
          ? null
          : canCompleteGoalDistance,
      raceDistanceBefore: experience == RunnerExperience.brandNew
          ? null
          : raceDistanceBefore,
      benchmark: benchmark,
      benchmarkTime: benchmark == null || benchmark == BenchmarkType.skip
          ? null
          : benchmarkTime,
      fitnessSource: FitnessSource.fromKey(fitnessSource),
      athleteSummary:
          athleteSummary ??
          _athleteSummaryFromLegacyStravaFields(
            weeklyVolumeKm: stravaWeeklyVolumeKm,
            longestRecentRunKm: stravaLongestRecentRunKm,
            runsPerWeek: stravaRunsPerWeek,
            dataWeeks: stravaDataWeeks,
            insufficientData: stravaInsufficientData,
          ),
      stravaCoachingProfile: stravaCoachingProfile,
    );
  }
}

class ScheduleProfile {
  const ScheduleProfile({
    required this.trainingDays,
    required this.longRunDay,
    required this.weekdayTime,
    required this.weekendTime,
    this.hardDays = const {},
    this.preferredTimeOfDay,
    this.planStartDate,
  });

  final int trainingDays;
  final WeekdayChoice longRunDay;
  final TimeSlot weekdayTime;
  final TimeSlot weekendTime;
  final Set<WeekdayChoice> hardDays;
  final PreferredTimeOfDay? preferredTimeOfDay;
  final DateTime? planStartDate;
}

class ScheduleProfileDraft {
  const ScheduleProfileDraft({
    this.trainingDays,
    this.longRunDay,
    this.weekdayTime,
    this.weekendTime,
    this.hardDays = const {},
    this.preferredTimeOfDay,
    this.planStartDate,
  });

  final int? trainingDays;
  final WeekdayChoice? longRunDay;
  final TimeSlot? weekdayTime;
  final TimeSlot? weekendTime;
  final Set<WeekdayChoice> hardDays;
  final PreferredTimeOfDay? preferredTimeOfDay;
  final DateTime? planStartDate;

  String? get trainingDaysKey => trainingDays?.toString();
  String? get longRunDayKey => longRunDay?.key;
  String? get weekdayTimeKey => weekdayTime?.key;
  String? get weekendTimeKey => weekendTime?.key;
  List<String> get hardDayKeys =>
      hardDays.map((day) => day.key).toList(growable: false);
  String? get preferredTimeOfDayKey => preferredTimeOfDay?.key;

  ScheduleProfile? toProfileOrNull() {
    if (trainingDays == null ||
        longRunDay == null ||
        weekdayTime == null ||
        weekendTime == null) {
      return null;
    }

    return ScheduleProfile(
      trainingDays: trainingDays!,
      longRunDay: longRunDay!,
      weekdayTime: weekdayTime!,
      weekendTime: weekendTime!,
      hardDays: hardDays,
      preferredTimeOfDay: preferredTimeOfDay,
      planStartDate: planStartDate == null
          ? null
          : DateTime(
              planStartDate!.year,
              planStartDate!.month,
              planStartDate!.day,
            ),
    );
  }
}

class HealthProfile {
  const HealthProfile({
    required this.painLevel,
    required this.injuryHistory,
    required this.hasHealthConditions,
  });

  final PainLevelChoice painLevel;
  final InjuryHistoryChoice injuryHistory;
  final BinaryChoice hasHealthConditions;
}

class HealthProfileDraft {
  const HealthProfileDraft({
    this.painLevel,
    this.injuryHistory,
    this.hasHealthConditions,
  });

  final PainLevelChoice? painLevel;
  final InjuryHistoryChoice? injuryHistory;
  final BinaryChoice? hasHealthConditions;

  String? get painLevelKey => painLevel?.key;
  String? get injuryHistoryKey => injuryHistory?.key;
  String? get healthConditionsKey => hasHealthConditions?.key;

  HealthProfile? toProfileOrNull() {
    if (painLevel == null ||
        injuryHistory == null ||
        hasHealthConditions == null) {
      return null;
    }

    return HealthProfile(
      painLevel: painLevel!,
      injuryHistory: injuryHistory!,
      hasHealthConditions: hasHealthConditions!,
    );
  }
}

class TrainingPreferencesProfile {
  const TrainingPreferencesProfile({required this.planPreference});

  final PlanPreferenceChoice planPreference;
}

class TrainingPreferencesProfileDraft {
  const TrainingPreferencesProfileDraft({this.planPreference});

  final PlanPreferenceChoice? planPreference;

  String? get planPreferenceKey => planPreference?.key;

  TrainingPreferencesProfile? toProfileOrNull() {
    if (planPreference == null) return null;
    return TrainingPreferencesProfile(planPreference: planPreference!);
  }
}

class DeviceProfile {
  const DeviceProfile({
    required this.hasWatch,
    this.device,
    this.dataUsage,
    this.watchMetrics,
    this.metrics = const {},
    this.hrZones,
    this.paceRecommendations,
    this.autoAdjust,
    this.noWatchGuidance,
  });

  final BinaryChoice hasWatch;
  final WatchDeviceType? device;
  final DataUsagePreference? dataUsage;
  final WatchMetricsPreference? watchMetrics;
  final Set<WatchMetric> metrics;
  final BinaryChoice? hrZones;
  final BinaryChoice? paceRecommendations;
  final AutoAdjustPreference? autoAdjust;
  final NoWatchGuidanceChoice? noWatchGuidance;
}

class DeviceProfileDraft {
  const DeviceProfileDraft({
    this.hasWatch,
    this.device,
    this.dataUsage,
    this.watchMetrics,
    this.metrics = const {},
    this.hrZones,
    this.paceRecommendations,
    this.autoAdjust,
    this.noWatchGuidance,
  });

  final BinaryChoice? hasWatch;
  final WatchDeviceType? device;
  final DataUsagePreference? dataUsage;
  final WatchMetricsPreference? watchMetrics;
  final Set<WatchMetric> metrics;
  final BinaryChoice? hrZones;
  final BinaryChoice? paceRecommendations;
  final AutoAdjustPreference? autoAdjust;
  final NoWatchGuidanceChoice? noWatchGuidance;

  String? get hasWatchKey => hasWatch?.key;
  String? get deviceKey => device?.key;
  String? get dataUsageKey => dataUsage?.key;
  String? get watchMetricsKey => watchMetrics?.key;
  List<String> get metricKeys =>
      metrics.map((metric) => metric.key).toList(growable: false);
  String? get hrZonesKey => hrZones?.key;
  String? get paceRecommendationsKey => paceRecommendations?.key;
  String? get autoAdjustKey => autoAdjust?.key;
  String? get noWatchGuidanceKey => noWatchGuidance?.key;

  DeviceProfile? toProfileOrNull() {
    if (hasWatch == null) return null;
    if (hasWatch == BinaryChoice.yes && device == null) return null;

    return DeviceProfile(
      hasWatch: hasWatch!,
      device: hasWatch == BinaryChoice.yes ? device : null,
      dataUsage: dataUsage,
      watchMetrics: watchMetrics,
      metrics: metrics,
      hrZones: hrZones,
      paceRecommendations: paceRecommendations,
      autoAdjust: autoAdjust,
      noWatchGuidance: noWatchGuidance,
    );
  }
}

class RunnerProfile {
  const RunnerProfile({
    required this.goal,
    required this.fitness,
    required this.schedule,
    required this.health,
    required this.strength,
    required this.trainingPreferences,
    required this.device,
    required this.schemaVersion,
    required this.updatedAt,
    this.gender,
    this.dateOfBirth,
    this.completedOnboardingAt,
  });

  final GoalProfile goal;
  final FitnessProfile fitness;
  final ScheduleProfile schedule;
  final HealthProfile health;
  final StrengthPreferences strength;
  final TrainingPreferencesProfile trainingPreferences;
  final DeviceProfile device;
  final ProfileGender? gender;
  final DateTime? dateOfBirth;
  final DateTime? completedOnboardingAt;
  final int schemaVersion;
  final DateTime updatedAt;

  bool get isOnboardingComplete => completedOnboardingAt != null;

  RunnerProfile copyWith({
    GoalProfile? goal,
    FitnessProfile? fitness,
    ScheduleProfile? schedule,
    HealthProfile? health,
    StrengthPreferences? strength,
    TrainingPreferencesProfile? trainingPreferences,
    DeviceProfile? device,
    ProfileGender? gender,
    DateTime? dateOfBirth,
    DateTime? completedOnboardingAt,
    int? schemaVersion,
    DateTime? updatedAt,
  }) {
    return RunnerProfile(
      goal: goal ?? this.goal,
      fitness: fitness ?? this.fitness,
      schedule: schedule ?? this.schedule,
      health: health ?? this.health,
      strength: strength ?? this.strength,
      trainingPreferences: trainingPreferences ?? this.trainingPreferences,
      device: device ?? this.device,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      completedOnboardingAt:
          completedOnboardingAt ?? this.completedOnboardingAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goal': _goalProfileToJson(goal),
      'fitness': _fitnessProfileToJson(fitness),
      'schedule': _scheduleProfileToJson(schedule),
      'health': _healthProfileToJson(health),
      'strength': _strengthProfileToJson(strength),
      'trainingPreferences': _trainingPreferencesProfileToJson(
        trainingPreferences,
      ),
      'device': _deviceProfileToJson(device),
      'gender': gender?.name,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'completedOnboardingAt': completedOnboardingAt?.toIso8601String(),
      'schemaVersion': schemaVersion,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static RunnerProfile? fromJson(Map<String, dynamic> json) {
    final goal = _goalProfileFromJson(_mapOrEmpty(json['goal']));
    final fitness = _fitnessProfileFromJson(_mapOrEmpty(json['fitness']));
    final schedule = _scheduleProfileFromJson(_mapOrEmpty(json['schedule']));
    final health = _healthProfileFromJson(_mapOrEmpty(json['health']));
    final strength = _strengthProfileFromJson(_mapOrEmpty(json['strength']));
    final trainingPreferences = _trainingPreferencesProfileFromJson(
      _mapOrEmpty(json['trainingPreferences']),
    );
    final device = _deviceProfileFromJson(_mapOrEmpty(json['device']));
    final updatedAt = _dateTimeFromJson(json['updatedAt']);
    final schemaVersion = _intOrNull(json['schemaVersion']);

    if (goal == null ||
        fitness == null ||
        schedule == null ||
        health == null ||
        strength == null ||
        trainingPreferences == null ||
        device == null ||
        updatedAt == null ||
        schemaVersion == null) {
      return null;
    }

    return RunnerProfile(
      goal: goal,
      fitness: fitness,
      schedule: schedule,
      health: health,
      strength: strength,
      trainingPreferences: trainingPreferences,
      device: device,
      gender: _profileGenderFromName(_stringOrNull(json['gender'])),
      dateOfBirth: _dateTimeFromJson(json['dateOfBirth']),
      completedOnboardingAt: _dateTimeFromJson(json['completedOnboardingAt']),
      schemaVersion: schemaVersion,
      updatedAt: updatedAt,
    );
  }
}

class RunnerProfileDraft {
  const RunnerProfileDraft({
    this.goal = const GoalProfileDraft(),
    this.fitness = const FitnessProfileDraft(),
    this.schedule = const ScheduleProfileDraft(),
    this.health = const HealthProfileDraft(),
    this.strength = const StrengthProfileDraft(),
    this.trainingPreferences = const TrainingPreferencesProfileDraft(),
    this.device = const DeviceProfileDraft(),
    this.acceptedRaceTarget,
  });

  final GoalProfileDraft goal;
  final FitnessProfileDraft fitness;
  final ScheduleProfileDraft schedule;
  final HealthProfileDraft health;
  final StrengthProfileDraft strength;
  final TrainingPreferencesProfileDraft trainingPreferences;
  final DeviceProfileDraft device;
  final AcceptedRaceTarget? acceptedRaceTarget;

  Map<String, dynamic> toJson() {
    return {
      'goal': _goalProfileDraftToJson(goal),
      'fitness': _fitnessProfileDraftToJson(fitness),
      'schedule': _scheduleProfileDraftToJson(schedule),
      'health': _healthProfileDraftToJson(health),
      'strength': _strengthProfileDraftToJson(strength),
      'trainingPreferences': _trainingPreferencesProfileDraftToJson(
        trainingPreferences,
      ),
      'device': _deviceProfileDraftToJson(device),
      'acceptedRaceTarget': acceptedRaceTarget?.toJson(),
    };
  }

  RunnerProfileDraft copyWith({
    GoalProfileDraft? goal,
    FitnessProfileDraft? fitness,
    ScheduleProfileDraft? schedule,
    HealthProfileDraft? health,
    StrengthProfileDraft? strength,
    TrainingPreferencesProfileDraft? trainingPreferences,
    DeviceProfileDraft? device,
    AcceptedRaceTarget? acceptedRaceTarget,
    bool clearAcceptedRaceTarget = false,
  }) {
    return RunnerProfileDraft(
      goal: goal ?? this.goal,
      fitness: fitness ?? this.fitness,
      schedule: schedule ?? this.schedule,
      health: health ?? this.health,
      strength: strength ?? this.strength,
      trainingPreferences: trainingPreferences ?? this.trainingPreferences,
      device: device ?? this.device,
      acceptedRaceTarget: clearAcceptedRaceTarget
          ? null
          : acceptedRaceTarget ?? this.acceptedRaceTarget,
    );
  }

  static RunnerProfileDraft fromJson(Map<String, dynamic> json) {
    AcceptedRaceTarget? acceptedRaceTarget;
    final rawAcceptedTarget = json['acceptedRaceTarget'];
    if (rawAcceptedTarget is Map<String, dynamic>) {
      try {
        acceptedRaceTarget = AcceptedRaceTarget.fromJson(rawAcceptedTarget);
      } on FormatException {
        acceptedRaceTarget = null;
      }
    } else if (rawAcceptedTarget is Map) {
      try {
        acceptedRaceTarget = AcceptedRaceTarget.fromJson(
          rawAcceptedTarget.map((key, value) => MapEntry('$key', value)),
        );
      } on FormatException {
        acceptedRaceTarget = null;
      }
    }

    return RunnerProfileDraft(
      goal: _goalProfileDraftFromJson(_mapOrEmpty(json['goal'])),
      fitness: _fitnessProfileDraftFromJson(_mapOrEmpty(json['fitness'])),
      schedule: _scheduleProfileDraftFromJson(_mapOrEmpty(json['schedule'])),
      health: _healthProfileDraftFromJson(_mapOrEmpty(json['health'])),
      strength: _strengthProfileDraftFromJson(_mapOrEmpty(json['strength'])),
      trainingPreferences: _trainingPreferencesProfileDraftFromJson(
        _mapOrEmpty(json['trainingPreferences']),
      ),
      device: _deviceProfileDraftFromJson(_mapOrEmpty(json['device'])),
      acceptedRaceTarget: acceptedRaceTarget,
    );
  }

  RunnerProfile? toRunnerProfile({
    ProfileGender? gender,
    DateTime? dateOfBirth,
    DateTime? completedOnboardingAt,
    DateTime? clock,
  }) {
    final goalProfile = goal.toProfileOrNull();
    final fitnessProfile = fitness.toProfileOrNull();
    final scheduleProfile = schedule.toProfileOrNull();
    final healthProfile = health.toProfileOrNull();
    final strengthProfile = strength.toProfileOrNull();
    final trainingPreferencesProfile = trainingPreferences.toProfileOrNull();
    final deviceProfile = device.toProfileOrNull();

    if (goalProfile == null ||
        fitnessProfile == null ||
        scheduleProfile == null ||
        healthProfile == null ||
        strengthProfile == null ||
        trainingPreferencesProfile == null ||
        deviceProfile == null) {
      return null;
    }

    return RunnerProfile(
      goal: goalProfile,
      fitness: fitnessProfile,
      schedule: scheduleProfile,
      health: healthProfile,
      strength: strengthProfile,
      trainingPreferences: trainingPreferencesProfile,
      device: deviceProfile,
      gender: gender,
      dateOfBirth: dateOfBirth,
      completedOnboardingAt: completedOnboardingAt,
      schemaVersion: 1,
      updatedAt: clock ?? DateTime.now(),
    );
  }

  static RunnerProfileDraft fromGoal({
    required String race,
    required bool hasRaceDate,
    DateTime? raceDate,
  }) {
    return RunnerProfileDraft(
      goal: GoalProfileDraft(
        race: RunnerGoalRace.fromKey(race),
        hasRaceDate: hasRaceDate,
        raceDate: raceDate,
      ),
    );
  }

  static RunnerProfileDraft fromRunnerProfile(RunnerProfile profile) {
    return RunnerProfileDraft(
      goal: GoalProfileDraft(
        race: profile.goal.race,
        hasRaceDate: profile.goal.hasRaceDate,
        raceDate: profile.goal.raceDate,
      ),
      fitness: FitnessProfileDraft(
        experience: profile.fitness.experience,
        canRun10Min: profile.fitness.canRun10Min,
        runningDays: profile.fitness.runningDays,
        weeklyVolume: profile.fitness.weeklyVolume,
        longestRun: profile.fitness.longestRun,
        canCompleteGoalDistance: profile.fitness.canCompleteGoalDistance,
        raceDistanceBefore: profile.fitness.raceDistanceBefore,
        benchmark: profile.fitness.benchmark,
        benchmarkTime: profile.fitness.benchmarkTime,
        fitnessSource: profile.fitness.fitnessSource?.key,
        stravaWeeklyVolumeKm: profile.fitness.athleteSummary?.weeklyVolumeKm,
        stravaLongestRecentRunKm:
            profile.fitness.athleteSummary?.longestRecentRunKm,
        stravaRunsPerWeek: profile.fitness.athleteSummary?.runsPerWeek,
        stravaDataWeeks: profile.fitness.athleteSummary?.dataWeeks,
        stravaInsufficientData:
            profile.fitness.athleteSummary?.insufficientData,
        athleteSummary: profile.fitness.athleteSummary,
        stravaCoachingProfile: profile.fitness.stravaCoachingProfile,
      ),
      schedule: ScheduleProfileDraft(
        trainingDays: profile.schedule.trainingDays,
        longRunDay: profile.schedule.longRunDay,
        weekdayTime: profile.schedule.weekdayTime,
        weekendTime: profile.schedule.weekendTime,
        hardDays: profile.schedule.hardDays,
        preferredTimeOfDay: profile.schedule.preferredTimeOfDay,
        planStartDate: profile.schedule.planStartDate,
      ),
      health: HealthProfileDraft(
        painLevel: profile.health.painLevel,
        injuryHistory: profile.health.injuryHistory,
        hasHealthConditions: profile.health.hasHealthConditions,
      ),
      strength: StrengthProfileDraft(
        lifts: profile.strength.lifts,
        weeklyFrequency: profile.strength.weeklyFrequency,
        categories: profile.strength.categories,
        preferredDays: profile.strength.preferredDays,
        sameDayOrder: profile.strength.sameDayOrder,
      ),
      trainingPreferences: TrainingPreferencesProfileDraft(
        planPreference: profile.trainingPreferences.planPreference,
      ),
      device: DeviceProfileDraft(
        hasWatch: profile.device.hasWatch,
        device: profile.device.device,
        dataUsage: profile.device.dataUsage,
        watchMetrics: profile.device.watchMetrics,
        metrics: profile.device.metrics,
        hrZones: profile.device.hrZones,
        paceRecommendations: profile.device.paceRecommendations,
        autoAdjust: profile.device.autoAdjust,
        noWatchGuidance: profile.device.noWatchGuidance,
      ),
    );
  }

  static FitnessProfileDraft fitnessFromInput({
    required String experience,
    bool? canRun10Min,
    String? runningDays,
    String? weeklyVolume,
    String? longestRun,
    String? canCompleteGoalDist,
    String? raceDistanceBefore,
    String? benchmark,
    Duration? benchmarkTime,
    String? fitnessSource,
    double? stravaWeeklyVolumeKm,
    double? stravaLongestRecentRunKm,
    double? stravaRunsPerWeek,
    int? stravaDataWeeks,
    bool? stravaInsufficientData,
    AthleteSummarySnapshot? athleteSummary,
    StravaCoachingProfile? stravaCoachingProfile,
  }) {
    return FitnessProfileDraft(
      experience: RunnerExperience.fromKey(experience),
      canRun10Min: canRun10Min,
      runningDays: _intFromString(runningDays),
      weeklyVolume: WeeklyVolumeRange.fromKey(weeklyVolume),
      longestRun: LongestRunRange.fromKey(longestRun),
      canCompleteGoalDistance: TernaryChoice.fromKey(canCompleteGoalDist),
      raceDistanceBefore: RaceDistanceExperience.fromKey(raceDistanceBefore),
      benchmark: BenchmarkType.fromKey(benchmark),
      benchmarkTime: benchmarkTime,
      fitnessSource: fitnessSource,
      stravaWeeklyVolumeKm: stravaWeeklyVolumeKm,
      stravaLongestRecentRunKm: stravaLongestRecentRunKm,
      stravaRunsPerWeek: stravaRunsPerWeek,
      stravaDataWeeks: stravaDataWeeks,
      stravaInsufficientData: stravaInsufficientData,
      athleteSummary: athleteSummary,
      stravaCoachingProfile: stravaCoachingProfile,
    );
  }

  static StrengthProfileDraft strengthFromInput({
    required bool lifts,
    String? weeklyFrequency,
    List<String>? categories,
    List<String>? preferredDays,
    String? sameDayOrder,
  }) {
    return StrengthProfileDraft(
      lifts: lifts,
      weeklyFrequency: _intFromString(weeklyFrequency),
      categories: _enumSetByKeys(
        categories,
        StrengthCategory.values,
        (value) => value.key,
      ),
      preferredDays: _enumSetByKeys(
        preferredDays,
        WeekdayChoice.values,
        (value) => value.key,
      ),
      sameDayOrder: SameDayOrderPreference.fromKey(sameDayOrder),
    );
  }

  static ScheduleProfileDraft scheduleFromInput({
    required String trainingDays,
    required String longRunDay,
    required String weekdayTime,
    required String weekendTime,
    required List<String> hardDays,
    String? preferredTimeOfDay,
    DateTime? planStartDate,
  }) {
    return ScheduleProfileDraft(
      trainingDays: _intFromString(trainingDays),
      longRunDay: WeekdayChoice.fromKey(longRunDay),
      weekdayTime: TimeSlot.fromKey(weekdayTime),
      weekendTime: TimeSlot.fromKey(weekendTime),
      hardDays: _enumSetByKeys(
        hardDays,
        WeekdayChoice.values,
        (value) => value.key,
      ),
      preferredTimeOfDay: PreferredTimeOfDay.fromKey(preferredTimeOfDay),
      planStartDate: planStartDate,
    );
  }

  static HealthProfileDraft healthFromInput({
    required String painLevel,
    required String injuryHistory,
    required String healthConditions,
  }) {
    return HealthProfileDraft(
      painLevel: PainLevelChoice.fromKey(painLevel),
      injuryHistory: InjuryHistoryChoice.fromKey(injuryHistory),
      hasHealthConditions: BinaryChoice.fromKey(healthConditions),
    );
  }

  static TrainingPreferencesProfileDraft trainingFromInput({
    required String planPreference,
  }) {
    return TrainingPreferencesProfileDraft(
      planPreference: PlanPreferenceChoice.fromKey(planPreference),
    );
  }

  static DeviceProfileDraft deviceFromInput({
    required String hasWatch,
    String? device,
    String? dataUsage,
    String? watchMetrics,
    List<String>? metrics,
    String? hrZones,
    String? paceRecs,
    String? autoAdjust,
    String? noWatchGuidance,
  }) {
    return DeviceProfileDraft(
      hasWatch: BinaryChoice.fromKey(hasWatch),
      device: WatchDeviceType.fromKey(device),
      dataUsage: DataUsagePreference.fromKey(dataUsage),
      watchMetrics: WatchMetricsPreference.fromKey(watchMetrics),
      metrics: _enumSetByKeys(
        metrics,
        WatchMetric.values,
        (value) => value.key,
      ),
      hrZones: BinaryChoice.fromKey(hrZones),
      paceRecommendations: BinaryChoice.fromKey(paceRecs),
      autoAdjust: AutoAdjustPreference.fromKey(autoAdjust),
      noWatchGuidance: NoWatchGuidanceChoice.fromKey(noWatchGuidance),
    );
  }
}

Map<String, dynamic> _goalProfileDraftToJson(GoalProfileDraft value) {
  return {
    'race': value.raceKey,
    'hasRaceDate': value.hasRaceDate,
    'raceDate': value.raceDate?.toIso8601String(),
  };
}

GoalProfileDraft _goalProfileDraftFromJson(Map<String, dynamic> json) {
  return GoalProfileDraft(
    race: RunnerGoalRace.fromKey(_stringOrNull(json['race'])),
    hasRaceDate: _boolOrNull(json['hasRaceDate']),
    raceDate: _dateTimeFromJson(json['raceDate']),
  );
}

Map<String, dynamic> _goalProfileToJson(GoalProfile value) {
  return {
    'race': value.race.key,
    'hasRaceDate': value.hasRaceDate,
    'raceDate': value.raceDate?.toIso8601String(),
  };
}

GoalProfile? _goalProfileFromJson(Map<String, dynamic> json) =>
    _goalProfileDraftFromJson(json).toProfileOrNull();

Map<String, dynamic> _fitnessProfileDraftToJson(FitnessProfileDraft value) {
  return {
    'experience': value.experienceKey,
    'canRun10Min': value.canRun10Min,
    'runningDays': value.runningDays,
    'weeklyVolume': value.weeklyVolumeKey,
    'longestRun': value.longestRunKey,
    'canCompleteGoalDistance': value.canCompleteGoalDistanceKey,
    'raceDistanceBefore': value.raceDistanceBeforeKey,
    'benchmark': value.benchmarkKey,
    'benchmarkTimeMs': _durationToJson(value.benchmarkTime),
    'fitnessSource': value.fitnessSource,
    'stravaWeeklyVolumeKm': value.stravaWeeklyVolumeKm,
    'stravaLongestRecentRunKm': value.stravaLongestRecentRunKm,
    'stravaRunsPerWeek': value.stravaRunsPerWeek,
    'stravaDataWeeks': value.stravaDataWeeks,
    'stravaInsufficientData': value.stravaInsufficientData,
    if (value.athleteSummary?.hasData == true)
      'athleteSummary': _athleteSummaryToJson(value.athleteSummary!),
    if (value.stravaCoachingProfile != null)
      'stravaCoachingProfile': _stravaCoachingProfilePersistenceJson(
        value.stravaCoachingProfile!,
      ),
  };
}

FitnessProfileDraft _fitnessProfileDraftFromJson(Map<String, dynamic> json) {
  return FitnessProfileDraft(
    experience: RunnerExperience.fromKey(_stringOrNull(json['experience'])),
    canRun10Min: _boolOrNull(json['canRun10Min']),
    runningDays: _intOrNull(json['runningDays']),
    weeklyVolume: WeeklyVolumeRange.fromKey(
      _stringOrNull(json['weeklyVolume']),
    ),
    longestRun: LongestRunRange.fromKey(_stringOrNull(json['longestRun'])),
    canCompleteGoalDistance: TernaryChoice.fromKey(
      _stringOrNull(json['canCompleteGoalDistance']),
    ),
    raceDistanceBefore: RaceDistanceExperience.fromKey(
      _stringOrNull(json['raceDistanceBefore']),
    ),
    benchmark: BenchmarkType.fromKey(_stringOrNull(json['benchmark'])),
    benchmarkTime: _durationFromJson(json['benchmarkTimeMs']),
    fitnessSource: _stringOrNull(json['fitnessSource']),
    stravaWeeklyVolumeKm: _doubleFromJson(json['stravaWeeklyVolumeKm']),
    stravaLongestRecentRunKm: _doubleFromJson(json['stravaLongestRecentRunKm']),
    stravaRunsPerWeek: _doubleFromJson(json['stravaRunsPerWeek']),
    stravaDataWeeks: _intOrNull(json['stravaDataWeeks']),
    stravaInsufficientData: _boolOrNull(json['stravaInsufficientData']),
    athleteSummary:
        _athleteSummaryFromJson(_mapOrEmpty(json['athleteSummary'])) ??
        _athleteSummaryFromLegacyStravaFields(
          weeklyVolumeKm: _doubleFromJson(json['stravaWeeklyVolumeKm']),
          longestRecentRunKm: _doubleFromJson(json['stravaLongestRecentRunKm']),
          runsPerWeek: _doubleFromJson(json['stravaRunsPerWeek']),
          dataWeeks: _intOrNull(json['stravaDataWeeks']),
          insufficientData: _boolOrNull(json['stravaInsufficientData']),
        ),
    stravaCoachingProfile: _stravaCoachingProfileFromJson(
      _mapOrEmpty(json['stravaCoachingProfile']),
    ),
  );
}

Map<String, dynamic> _fitnessProfileToJson(FitnessProfile value) {
  return {
    'experience': value.experience.key,
    'canRun10Min': value.canRun10Min,
    'runningDays': value.runningDays,
    'weeklyVolume': value.weeklyVolume?.key,
    'longestRun': value.longestRun?.key,
    'canCompleteGoalDistance': value.canCompleteGoalDistance?.key,
    'raceDistanceBefore': value.raceDistanceBefore?.key,
    'benchmark': value.benchmark?.key,
    'benchmarkTimeMs': _durationToJson(value.benchmarkTime),
    'fitnessSource': value.fitnessSource?.key,
    if (value.athleteSummary?.hasData == true)
      'athleteSummary': _athleteSummaryToJson(value.athleteSummary!),
    if (value.stravaCoachingProfile != null)
      'stravaCoachingProfile': _stravaCoachingProfilePersistenceJson(
        value.stravaCoachingProfile!,
      ),
  };
}

Map<String, dynamic> _stravaCoachingProfilePersistenceJson(
  StravaCoachingProfile value,
) {
  final json = value.toJson();
  final recoveryGuardrails = json['recoveryGuardrails'];
  if (recoveryGuardrails is List) {
    json['recoveryGuardrails'] = recoveryGuardrails
        .map((entry) {
          if (entry is! Map) return entry;
          final guardrail = entry.map(
            (key, nestedValue) => MapEntry('$key', nestedValue),
          );
          guardrail.remove('message');
          return guardrail;
        })
        .toList(growable: false);
  }

  final planFocus = json['planFocus'];
  if (planFocus is Map) {
    final focus = planFocus.map(
      (key, nestedValue) => MapEntry('$key', nestedValue),
    );
    focus.remove('summary');
    json['planFocus'] = focus;
  }

  return json;
}

StravaCoachingProfile? _stravaCoachingProfileFromJson(
  Map<String, dynamic> json,
) {
  if (json.isEmpty) return null;
  return StravaCoachingProfile.fromJson(
    _stravaCoachingProfileRuntimeJson(json),
  );
}

Map<String, dynamic> _stravaCoachingProfileRuntimeJson(
  Map<String, dynamic> json,
) {
  final hydrated = Map<String, dynamic>.from(json);
  final recoveryGuardrails = hydrated['recoveryGuardrails'];
  if (recoveryGuardrails is List) {
    hydrated['recoveryGuardrails'] = recoveryGuardrails
        .map((entry) {
          if (entry is! Map) return entry;
          final guardrail = entry.map(
            (key, nestedValue) => MapEntry('$key', nestedValue),
          );
          guardrail.putIfAbsent(
            'message',
            () => _stringOrNull(guardrail['category']) ?? 'strava_guardrail',
          );
          return guardrail;
        })
        .toList(growable: false);
  }

  final planFocus = hydrated['planFocus'];
  if (planFocus is Map) {
    final focus = planFocus.map(
      (key, nestedValue) => MapEntry('$key', nestedValue),
    );
    focus.putIfAbsent(
      'summary',
      () => _stringOrNull(focus['category']) ?? 'strava_plan_focus',
    );
    hydrated['planFocus'] = focus;
  }

  return hydrated;
}

Map<String, dynamic> _athleteSummaryToJson(AthleteSummarySnapshot value) {
  return {
    if (value.weeklyVolumeKm != null) 'weeklyVolumeKm': value.weeklyVolumeKm,
    if (value.volumeTrend != null) 'volumeTrend': value.volumeTrend!.toKey(),
    if (value.acuteChronicRatio != null)
      'acuteChronicRatio': value.acuteChronicRatio,
    if (value.longestRecentRunKm != null)
      'longestRecentRunKm': value.longestRecentRunKm,
    if (value.typicalEasyPaceSecPerKm != null)
      'typicalEasyPaceSecPerKm': value.typicalEasyPaceSecPerKm,
    if (value.typicalHardPaceSecPerKm != null)
      'typicalHardPaceSecPerKm': value.typicalHardPaceSecPerKm,
    if (value.estimatedThresholdPaceSecPerKm != null)
      'estimatedThresholdPaceSecPerKm': value.estimatedThresholdPaceSecPerKm,
    if (value.runsPerWeek != null) 'runsPerWeek': value.runsPerWeek,
    if (value.longestLayoffDays != null)
      'longestLayoffDays': value.longestLayoffDays,
    if (value.weeksActiveInLast8 != null)
      'weeksActiveInLast8': value.weeksActiveInLast8,
    if (value.dataWeeks != null) 'dataWeeks': value.dataWeeks,
    if (value.insufficientData != null)
      'insufficientData': value.insufficientData,
    if (value.hasHeartRateZones != null)
      'hasHeartRateZones': value.hasHeartRateZones,
  };
}

AthleteSummarySnapshot? _athleteSummaryFromJson(Map<String, dynamic> json) {
  if (json.isEmpty) return null;

  final summary = AthleteSummarySnapshot(
    weeklyVolumeKm: _doubleFromJson(json['weeklyVolumeKm']),
    volumeTrend: _volumeTrendFromKey(_stringOrNull(json['volumeTrend'])),
    acuteChronicRatio: _doubleFromJson(json['acuteChronicRatio']),
    longestRecentRunKm: _doubleFromJson(json['longestRecentRunKm']),
    typicalEasyPaceSecPerKm: _intOrNull(json['typicalEasyPaceSecPerKm']),
    typicalHardPaceSecPerKm: _intOrNull(json['typicalHardPaceSecPerKm']),
    estimatedThresholdPaceSecPerKm: _intOrNull(
      json['estimatedThresholdPaceSecPerKm'],
    ),
    runsPerWeek: _doubleFromJson(json['runsPerWeek']),
    longestLayoffDays: _intOrNull(json['longestLayoffDays']),
    weeksActiveInLast8: _intOrNull(json['weeksActiveInLast8']),
    dataWeeks: _intOrNull(json['dataWeeks']),
    insufficientData: _boolOrNull(json['insufficientData']),
    hasHeartRateZones: _boolOrNull(json['hasHeartRateZones']),
  );

  return summary.hasData ? summary : null;
}

AthleteSummarySnapshot? _athleteSummaryFromLegacyStravaFields({
  required double? weeklyVolumeKm,
  required double? longestRecentRunKm,
  required double? runsPerWeek,
  required int? dataWeeks,
  required bool? insufficientData,
}) {
  final summary = AthleteSummarySnapshot(
    weeklyVolumeKm: weeklyVolumeKm,
    longestRecentRunKm: longestRecentRunKm,
    runsPerWeek: runsPerWeek,
    dataWeeks: dataWeeks,
    insufficientData: insufficientData,
  );
  return summary.hasData ? summary : null;
}

FitnessProfile? _fitnessProfileFromJson(Map<String, dynamic> json) =>
    _fitnessProfileDraftFromJson(json).toProfileOrNull();

Map<String, dynamic> _scheduleProfileDraftToJson(ScheduleProfileDraft value) {
  return {
    'trainingDays': value.trainingDays,
    'longRunDay': value.longRunDayKey,
    'weekdayTime': value.weekdayTimeKey,
    'weekendTime': value.weekendTimeKey,
    'hardDays': value.hardDayKeys,
    'preferredTimeOfDay': value.preferredTimeOfDayKey,
    if (value.planStartDate != null)
      'planStartDate': _dateOnlyToJson(value.planStartDate),
  };
}

ScheduleProfileDraft _scheduleProfileDraftFromJson(Map<String, dynamic> json) {
  return ScheduleProfileDraft(
    trainingDays: _intOrNull(json['trainingDays']),
    longRunDay: WeekdayChoice.fromKey(_stringOrNull(json['longRunDay'])),
    weekdayTime: TimeSlot.fromKey(_stringOrNull(json['weekdayTime'])),
    weekendTime: TimeSlot.fromKey(_stringOrNull(json['weekendTime'])),
    hardDays: _enumSetByKeys(
      _stringListOrEmpty(json['hardDays']),
      WeekdayChoice.values,
      (value) => value.key,
    ),
    preferredTimeOfDay: PreferredTimeOfDay.fromKey(
      _stringOrNull(json['preferredTimeOfDay']),
    ),
    planStartDate: _dateOnlyFromJson(json['planStartDate']),
  );
}

Map<String, dynamic> _scheduleProfileToJson(ScheduleProfile value) {
  return {
    'trainingDays': value.trainingDays,
    'longRunDay': value.longRunDay.key,
    'weekdayTime': value.weekdayTime.key,
    'weekendTime': value.weekendTime.key,
    'hardDays': _sortedCanonicalKeys(value.hardDays),
    'preferredTimeOfDay': value.preferredTimeOfDay?.key,
    if (value.planStartDate != null)
      'planStartDate': _dateOnlyToJson(value.planStartDate),
  };
}

ScheduleProfile? _scheduleProfileFromJson(Map<String, dynamic> json) =>
    _scheduleProfileDraftFromJson(json).toProfileOrNull();

Map<String, dynamic> _healthProfileDraftToJson(HealthProfileDraft value) {
  return {
    'painLevel': value.painLevelKey,
    'injuryHistory': value.injuryHistoryKey,
    'hasHealthConditions': value.healthConditionsKey,
  };
}

HealthProfileDraft _healthProfileDraftFromJson(Map<String, dynamic> json) {
  return HealthProfileDraft(
    painLevel: PainLevelChoice.fromKey(_stringOrNull(json['painLevel'])),
    injuryHistory: InjuryHistoryChoice.fromKey(
      _stringOrNull(json['injuryHistory']),
    ),
    hasHealthConditions: BinaryChoice.fromKey(
      _stringOrNull(json['hasHealthConditions']),
    ),
  );
}

Map<String, dynamic> _healthProfileToJson(HealthProfile value) {
  return {
    'painLevel': value.painLevel.key,
    'injuryHistory': value.injuryHistory.key,
    'hasHealthConditions': value.hasHealthConditions.key,
  };
}

HealthProfile? _healthProfileFromJson(Map<String, dynamic> json) =>
    _healthProfileDraftFromJson(json).toProfileOrNull();

Map<String, dynamic> _strengthProfileDraftToJson(StrengthProfileDraft value) {
  return {
    'lifts': value.lifts,
    'weeklyFrequency': value.weeklyFrequency,
    'categories': _sortedCanonicalKeys(value.categories),
    'preferredDays': _sortedCanonicalKeys(value.preferredDays),
    'sameDayOrder': value.sameDayOrder?.key,
  };
}

StrengthProfileDraft _strengthProfileDraftFromJson(Map<String, dynamic> json) {
  return StrengthProfileDraft(
    lifts: _boolOrNull(json['lifts']),
    weeklyFrequency: _intOrNull(json['weeklyFrequency']),
    categories: _enumSetByKeys(
      _stringListOrEmpty(json['categories']),
      StrengthCategory.values,
      (value) => value.key,
    ),
    preferredDays: _enumSetByKeys(
      _stringListOrEmpty(json['preferredDays']),
      WeekdayChoice.values,
      (value) => value.key,
    ),
    sameDayOrder: SameDayOrderPreference.fromKey(
      _stringOrNull(json['sameDayOrder']),
    ),
  );
}

Map<String, dynamic> _strengthProfileToJson(StrengthPreferences value) {
  return value.toJson();
}

StrengthPreferences? _strengthProfileFromJson(Map<String, dynamic> json) {
  try {
    return StrengthPreferences.fromJson(json);
  } on FormatException {
    return null;
  }
}

Map<String, dynamic> _trainingPreferencesProfileDraftToJson(
  TrainingPreferencesProfileDraft value,
) {
  return {'planPreference': value.planPreferenceKey};
}

TrainingPreferencesProfileDraft _trainingPreferencesProfileDraftFromJson(
  Map<String, dynamic> json,
) {
  return TrainingPreferencesProfileDraft(
    planPreference: PlanPreferenceChoice.fromKey(
      _stringOrNull(json['planPreference']),
    ),
  );
}

Map<String, dynamic> _trainingPreferencesProfileToJson(
  TrainingPreferencesProfile value,
) {
  return {'planPreference': value.planPreference.key};
}

TrainingPreferencesProfile? _trainingPreferencesProfileFromJson(
  Map<String, dynamic> json,
) => _trainingPreferencesProfileDraftFromJson(json).toProfileOrNull();

Map<String, dynamic> _deviceProfileDraftToJson(DeviceProfileDraft value) {
  return {
    'hasWatch': value.hasWatchKey,
    'device': value.deviceKey,
    'dataUsage': value.dataUsageKey,
    'watchMetrics': value.watchMetricsKey,
    'metrics': value.metricKeys,
    'hrZones': value.hrZonesKey,
    'paceRecommendations': value.paceRecommendationsKey,
    'autoAdjust': value.autoAdjustKey,
    'noWatchGuidance': value.noWatchGuidanceKey,
  };
}

DeviceProfileDraft _deviceProfileDraftFromJson(Map<String, dynamic> json) {
  return DeviceProfileDraft(
    hasWatch: BinaryChoice.fromKey(_stringOrNull(json['hasWatch'])),
    device: WatchDeviceType.fromKey(_stringOrNull(json['device'])),
    dataUsage: DataUsagePreference.fromKey(_stringOrNull(json['dataUsage'])),
    watchMetrics: WatchMetricsPreference.fromKey(
      _stringOrNull(json['watchMetrics']),
    ),
    metrics: _enumSetByKeys(
      _stringListOrEmpty(json['metrics']),
      WatchMetric.values,
      (value) => value.key,
    ),
    hrZones: BinaryChoice.fromKey(_stringOrNull(json['hrZones'])),
    paceRecommendations: BinaryChoice.fromKey(
      _stringOrNull(json['paceRecommendations']),
    ),
    autoAdjust: AutoAdjustPreference.fromKey(_stringOrNull(json['autoAdjust'])),
    noWatchGuidance: NoWatchGuidanceChoice.fromKey(
      _stringOrNull(json['noWatchGuidance']),
    ),
  );
}

Map<String, dynamic> _deviceProfileToJson(DeviceProfile value) {
  return {
    'hasWatch': value.hasWatch.key,
    'device': value.device?.key,
    'dataUsage': value.dataUsage?.key,
    'watchMetrics': value.watchMetrics?.key,
    'metrics': _sortedCanonicalKeys(value.metrics),
    'hrZones': value.hrZones?.key,
    'paceRecommendations': value.paceRecommendations?.key,
    'autoAdjust': value.autoAdjust?.key,
    'noWatchGuidance': value.noWatchGuidance?.key,
  };
}

DeviceProfile? _deviceProfileFromJson(Map<String, dynamic> json) =>
    _deviceProfileDraftFromJson(json).toProfileOrNull();
