import '../../../user_preferences/domain/user_preferences.dart';

abstract interface class CanonicalKeyed {
  String get key;
}

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

int? _intFromString(String? value) =>
    value == null ? null : int.tryParse(value);

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

enum GoalPriority implements CanonicalKeyed {
  justFinish('priority_just_finish'),
  finishStrong('priority_finish_strong'),
  improveTime('priority_improve_time'),
  consistency('priority_consistency'),
  generalFitness('priority_general_fitness');

  const GoalPriority(this.key);

  @override
  final String key;

  static GoalPriority? fromKey(String? key) =>
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
  no('no');

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

enum SleepRange implements CanonicalKeyed {
  lessThan5h('sleep_less_than_5h'),
  h5To6('sleep_5_to_6h'),
  h6To7('sleep_6_to_7h'),
  h7To8('sleep_7_to_8h'),
  h8Plus('sleep_8_plus_h');

  const SleepRange(this.key);

  @override
  final String key;

  static SleepRange? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum WorkLevelChoice implements CanonicalKeyed {
  mostlyDesk('work_mostly_desk'),
  mixed('work_mixed'),
  physical('work_physical');

  const WorkLevelChoice(this.key);

  @override
  final String key;

  static WorkLevelChoice? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum StressLevelChoice implements CanonicalKeyed {
  low('stress_low'),
  moderate('stress_moderate'),
  high('stress_high');

  const StressLevelChoice(this.key);

  @override
  final String key;

  static StressLevelChoice? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum DayFeelingChoice implements CanonicalKeyed {
  fresh('feeling_fresh'),
  sometimesTired('feeling_sometimes_tired'),
  oftenTired('feeling_often_tired'),
  alwaysTired('feeling_always_tired');

  const DayFeelingChoice(this.key);

  @override
  final String key;

  static DayFeelingChoice? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum MotivationReason implements CanonicalKeyed {
  personalChallenge('motivation_personal_challenge'),
  health('motivation_health'),
  weightLoss('motivation_weight_loss'),
  improvePerformance('motivation_improve_performance'),
  raceFriends('motivation_race_friends'),
  discipline('motivation_discipline'),
  other('motivation_other');

  const MotivationReason(this.key);

  @override
  final String key;

  static MotivationReason? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum BarrierReason implements CanonicalKeyed {
  time('barrier_time'),
  motivation('barrier_motivation'),
  fatigue('barrier_fatigue'),
  stress('barrier_stress'),
  pain('barrier_pain'),
  boredom('barrier_boredom'),
  dontKnowHow('barrier_dont_know_how'),
  other('barrier_other');

  const BarrierReason(this.key);

  @override
  final String key;

  static BarrierReason? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

enum CoachingToneChoice implements CanonicalKeyed {
  simple('tone_simple'),
  encouraging('tone_encouraging'),
  detailed('tone_detailed'),
  strict('tone_strict');

  const CoachingToneChoice(this.key);

  @override
  final String key;

  static CoachingToneChoice? fromKey(String? key) =>
      _enumByKey(key, values, (value) => value.key);
}

class GoalProfile {
  const GoalProfile({
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

class GoalProfileDraft {
  const GoalProfileDraft({
    this.race,
    this.hasRaceDate,
    this.raceDate,
    this.priority,
    this.currentTime,
    this.targetTime,
  });

  final RunnerGoalRace? race;
  final bool? hasRaceDate;
  final DateTime? raceDate;
  final GoalPriority? priority;
  final Duration? currentTime;
  final Duration? targetTime;

  String? get raceKey => race?.key;
  String? get priorityKey => priority?.key;

  GoalProfile? toProfileOrNull() {
    if (race == null || hasRaceDate == null || priority == null) return null;
    if (hasRaceDate == true && raceDate == null) return null;
    final needsTimes = priority == GoalPriority.improveTime;
    if (needsTimes && (currentTime == null || targetTime == null)) return null;

    return GoalProfile(
      race: race!,
      hasRaceDate: hasRaceDate!,
      raceDate: hasRaceDate == true ? raceDate : null,
      priority: priority!,
      currentTime: needsTimes ? currentTime : null,
      targetTime: needsTimes ? targetTime : null,
    );
  }
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
  });

  final int trainingDays;
  final WeekdayChoice longRunDay;
  final TimeSlot weekdayTime;
  final TimeSlot weekendTime;
  final Set<WeekdayChoice> hardDays;
  final PreferredTimeOfDay? preferredTimeOfDay;
}

class ScheduleProfileDraft {
  const ScheduleProfileDraft({
    this.trainingDays,
    this.longRunDay,
    this.weekdayTime,
    this.weekendTime,
    this.hardDays = const {},
    this.preferredTimeOfDay,
  });

  final int? trainingDays;
  final WeekdayChoice? longRunDay;
  final TimeSlot? weekdayTime;
  final TimeSlot? weekendTime;
  final Set<WeekdayChoice> hardDays;
  final PreferredTimeOfDay? preferredTimeOfDay;

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

class RecoveryProfile {
  const RecoveryProfile({
    required this.sleep,
    required this.workLevel,
    required this.stressLevel,
    required this.dayFeeling,
  });

  final SleepRange sleep;
  final WorkLevelChoice workLevel;
  final StressLevelChoice stressLevel;
  final DayFeelingChoice dayFeeling;
}

class RecoveryProfileDraft {
  const RecoveryProfileDraft({
    this.sleep,
    this.workLevel,
    this.stressLevel,
    this.dayFeeling,
  });

  final SleepRange? sleep;
  final WorkLevelChoice? workLevel;
  final StressLevelChoice? stressLevel;
  final DayFeelingChoice? dayFeeling;

  String? get sleepKey => sleep?.key;
  String? get workLevelKey => workLevel?.key;
  String? get stressLevelKey => stressLevel?.key;
  String? get dayFeelingKey => dayFeeling?.key;

  RecoveryProfile? toProfileOrNull() {
    if (sleep == null ||
        workLevel == null ||
        stressLevel == null ||
        dayFeeling == null) {
      return null;
    }

    return RecoveryProfile(
      sleep: sleep!,
      workLevel: workLevel!,
      stressLevel: stressLevel!,
      dayFeeling: dayFeeling!,
    );
  }
}

class MotivationProfile {
  const MotivationProfile({
    required this.motivations,
    required this.barriers,
    required this.confidence,
    required this.coachingTone,
  });

  final Set<MotivationReason> motivations;
  final Set<BarrierReason> barriers;
  final int confidence;
  final CoachingToneChoice coachingTone;
}

class MotivationProfileDraft {
  const MotivationProfileDraft({
    this.motivations = const {},
    this.barriers = const {},
    this.confidence,
    this.coachingTone,
  });

  final Set<MotivationReason> motivations;
  final Set<BarrierReason> barriers;
  final int? confidence;
  final CoachingToneChoice? coachingTone;

  List<String> get motivationKeys =>
      motivations.map((value) => value.key).toList(growable: false);
  List<String> get barrierKeys =>
      barriers.map((value) => value.key).toList(growable: false);
  String? get coachingToneKey => coachingTone?.key;

  MotivationProfile? toProfileOrNull() {
    if (motivations.isEmpty ||
        barriers.isEmpty ||
        confidence == null ||
        coachingTone == null) {
      return null;
    }

    return MotivationProfile(
      motivations: motivations,
      barriers: barriers,
      confidence: confidence!,
      coachingTone: coachingTone!,
    );
  }
}

class RunnerProfile {
  const RunnerProfile({
    required this.goal,
    required this.fitness,
    required this.schedule,
    required this.health,
    required this.trainingPreferences,
    required this.device,
    required this.recovery,
    required this.motivation,
    required this.schemaVersion,
    required this.updatedAt,
    this.gender,
    this.dateOfBirth,
  });

  final GoalProfile goal;
  final FitnessProfile fitness;
  final ScheduleProfile schedule;
  final HealthProfile health;
  final TrainingPreferencesProfile trainingPreferences;
  final DeviceProfile device;
  final RecoveryProfile recovery;
  final MotivationProfile motivation;
  final ProfileGender? gender;
  final DateTime? dateOfBirth;
  final int schemaVersion;
  final DateTime updatedAt;
}

class RunnerProfileDraft {
  const RunnerProfileDraft({
    this.goal = const GoalProfileDraft(),
    this.fitness = const FitnessProfileDraft(),
    this.schedule = const ScheduleProfileDraft(),
    this.health = const HealthProfileDraft(),
    this.trainingPreferences = const TrainingPreferencesProfileDraft(),
    this.device = const DeviceProfileDraft(),
    this.recovery = const RecoveryProfileDraft(),
    this.motivation = const MotivationProfileDraft(),
  });

  final GoalProfileDraft goal;
  final FitnessProfileDraft fitness;
  final ScheduleProfileDraft schedule;
  final HealthProfileDraft health;
  final TrainingPreferencesProfileDraft trainingPreferences;
  final DeviceProfileDraft device;
  final RecoveryProfileDraft recovery;
  final MotivationProfileDraft motivation;

  RunnerProfileDraft copyWith({
    GoalProfileDraft? goal,
    FitnessProfileDraft? fitness,
    ScheduleProfileDraft? schedule,
    HealthProfileDraft? health,
    TrainingPreferencesProfileDraft? trainingPreferences,
    DeviceProfileDraft? device,
    RecoveryProfileDraft? recovery,
    MotivationProfileDraft? motivation,
  }) {
    return RunnerProfileDraft(
      goal: goal ?? this.goal,
      fitness: fitness ?? this.fitness,
      schedule: schedule ?? this.schedule,
      health: health ?? this.health,
      trainingPreferences: trainingPreferences ?? this.trainingPreferences,
      device: device ?? this.device,
      recovery: recovery ?? this.recovery,
      motivation: motivation ?? this.motivation,
    );
  }

  RunnerProfile? toRunnerProfile({
    ProfileGender? gender,
    DateTime? dateOfBirth,
    DateTime? clock,
  }) {
    final goalProfile = goal.toProfileOrNull();
    final fitnessProfile = fitness.toProfileOrNull();
    final scheduleProfile = schedule.toProfileOrNull();
    final healthProfile = health.toProfileOrNull();
    final trainingPreferencesProfile = trainingPreferences.toProfileOrNull();
    final deviceProfile = device.toProfileOrNull();
    final recoveryProfile = recovery.toProfileOrNull();
    final motivationProfile = motivation.toProfileOrNull();

    if (goalProfile == null ||
        fitnessProfile == null ||
        scheduleProfile == null ||
        healthProfile == null ||
        trainingPreferencesProfile == null ||
        deviceProfile == null ||
        recoveryProfile == null ||
        motivationProfile == null) {
      return null;
    }

    return RunnerProfile(
      goal: goalProfile,
      fitness: fitnessProfile,
      schedule: scheduleProfile,
      health: healthProfile,
      trainingPreferences: trainingPreferencesProfile,
      device: deviceProfile,
      recovery: recoveryProfile,
      motivation: motivationProfile,
      gender: gender,
      dateOfBirth: dateOfBirth,
      schemaVersion: 1,
      updatedAt: clock ?? DateTime.now(),
    );
  }

  static RunnerProfileDraft fromGoal({
    required String race,
    required bool hasRaceDate,
    DateTime? raceDate,
    required String priority,
    Duration? currentTime,
    Duration? targetTime,
  }) {
    return RunnerProfileDraft(
      goal: GoalProfileDraft(
        race: RunnerGoalRace.fromKey(race),
        hasRaceDate: hasRaceDate,
        raceDate: raceDate,
        priority: GoalPriority.fromKey(priority),
        currentTime: currentTime,
        targetTime: targetTime,
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
    );
  }

  static ScheduleProfileDraft scheduleFromInput({
    required String trainingDays,
    required String longRunDay,
    required String weekdayTime,
    required String weekendTime,
    required List<String> hardDays,
    String? preferredTimeOfDay,
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

  static RecoveryProfileDraft recoveryFromInput({
    required String sleep,
    required String workLevel,
    required String stressLevel,
    required String dayFeeling,
  }) {
    return RecoveryProfileDraft(
      sleep: SleepRange.fromKey(sleep),
      workLevel: WorkLevelChoice.fromKey(workLevel),
      stressLevel: StressLevelChoice.fromKey(stressLevel),
      dayFeeling: DayFeelingChoice.fromKey(dayFeeling),
    );
  }

  static MotivationProfileDraft motivationFromInput({
    required List<String> motivations,
    required List<String> barriers,
    required int confidence,
    required String coachingTone,
  }) {
    return MotivationProfileDraft(
      motivations: _enumSetByKeys(
        motivations,
        MotivationReason.values,
        (value) => value.key,
      ),
      barriers: _enumSetByKeys(
        barriers,
        BarrierReason.values,
        (value) => value.key,
      ),
      confidence: confidence,
      coachingTone: CoachingToneChoice.fromKey(coachingTone),
    );
  }
}
