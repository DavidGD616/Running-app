import '../../user_preferences/domain/user_preferences.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../../l10n/app_localizations.dart';

typedef OnboardingOption = ({String key, String label});
typedef OnboardingOptionWithSubtitle = ({
  String key,
  String label,
  String subtitle,
});

abstract final class OnboardingValues {
  static const yes = 'yes';
  static const no = 'no';
  static const notSure = 'not_sure';
  static const onlyIfNeeded = 'only_if_needed';
  static const ifSupported = 'if_supported';
  static const hrOnly = 'hr_only';
  static const none = 'none';
  static const decideForMe = 'decide_for_me';

  static const race5k = 'race_5k';
  static const race10k = 'race_10k';
  static const raceHalfMarathon = 'race_half_marathon';
  static const raceMarathon = 'race_marathon';
  static const raceOther = 'race_other';

  static const priorityJustFinish = 'priority_just_finish';
  static const priorityFinishStrong = 'priority_finish_strong';
  static const priorityImproveTime = 'priority_improve_time';
  static const priorityConsistency = 'priority_consistency';
  static const priorityGeneralFitness = 'priority_general_fitness';

  static const experienceBrandNew = 'experience_brand_new';
  static const experienceBeginner = 'experience_beginner';
  static const experienceIntermediate = 'experience_intermediate';
  static const experienceExperienced = 'experience_experienced';

  static const benchmark1KmRun = 'benchmark_1km_run';
  static const benchmark1KmWalk = 'benchmark_1km_walk';
  static const benchmark1MiRun = 'benchmark_1mi_run';
  static const benchmark1MiWalk = 'benchmark_1mi_walk';
  static const benchmark5k = 'benchmark_5k';
  static const benchmark10k = 'benchmark_10k';
  static const benchmarkHalfMarathon = 'benchmark_half_marathon';
  static const benchmarkSkip = 'benchmark_skip';

  static const raceDistanceNever = 'race_distance_never';
  static const raceDistanceOnce = 'race_distance_once';
  static const raceDistance2to3 = 'race_distance_2_to_3';
  static const raceDistance4plus = 'race_distance_4_plus';

  static const weeklyVolume0 = 'weekly_volume_0';
  static const weeklyVolume1 = 'weekly_volume_1';
  static const weeklyVolume2 = 'weekly_volume_2';
  static const weeklyVolume3 = 'weekly_volume_3';
  static const weeklyVolume4 = 'weekly_volume_4';
  static const weeklyVolume5 = 'weekly_volume_5';
  static const weeklyVolume6 = 'weekly_volume_6';

  static const longestRun0 = 'longest_run_0';
  static const longestRun1 = 'longest_run_1';
  static const longestRun2 = 'longest_run_2';
  static const longestRun3 = 'longest_run_3';
  static const longestRun4 = 'longest_run_4';
  static const longestRun5 = 'longest_run_5';
  static const longestRun6 = 'longest_run_6';

  static const dayMon = 'day_mon';
  static const dayTue = 'day_tue';
  static const dayWed = 'day_wed';
  static const dayThu = 'day_thu';
  static const dayFri = 'day_fri';
  static const daySat = 'day_sat';
  static const daySun = 'day_sun';

  static const time20min = 'time_20_min';
  static const time30min = 'time_30_min';
  static const time45min = 'time_45_min';
  static const time60min = 'time_60_min';
  static const time75plusMin = 'time_75_plus_min';
  static const time90min = 'time_90_min';
  static const time2plusHours = 'time_2_plus_hours';

  static const timeOfDayEarlyMorning = 'time_of_day_early_morning';
  static const timeOfDayMorning = 'time_of_day_morning';
  static const timeOfDayAfternoon = 'time_of_day_afternoon';
  static const timeOfDayEvening = 'time_of_day_evening';
  static const timeOfDayNoPreference = 'time_of_day_no_preference';

  static const painNo = 'pain_no';
  static const painMild = 'pain_mild';
  static const painModerate = 'pain_moderate';
  static const painSevere = 'pain_severe';

  static const injuryNo = 'injury_no';
  static const injuryOnce = 'injury_once';
  static const injuryMultiple = 'injury_multiple';

  static const planSafest = 'plan_safest';
  static const planBalanced = 'plan_balanced';
  static const planPerformance = 'plan_performance';

  static const guidanceEffort = 'guidance_effort';
  static const guidancePace = 'guidance_pace';
  static const guidanceHeartRate = 'guidance_heart_rate';
  static const guidanceDecideForMe = 'guidance_decide_for_me';

  static const strengthNone = 'strength_none';
  static const strength1Day = 'strength_1_day';
  static const strength2Days = 'strength_2_days';
  static const strength3Days = 'strength_3_days';

  static const surfaceRoad = 'surface_road';
  static const surfaceTreadmill = 'surface_treadmill';
  static const surfaceTrack = 'surface_track';
  static const surfaceTrail = 'surface_trail';
  static const surfaceMixed = 'surface_mixed';

  static const terrainFlat = 'terrain_flat';
  static const terrainSomeHills = 'terrain_some_hills';
  static const terrainHilly = 'terrain_hilly';
  static const terrainMixed = 'terrain_mixed';

  static const deviceGarmin = 'device_garmin';
  static const deviceAppleWatch = 'device_apple_watch';
  static const deviceCoros = 'device_coros';
  static const devicePolar = 'device_polar';
  static const deviceSuunto = 'device_suunto';
  static const deviceFitbit = 'device_fitbit';
  static const deviceOther = 'device_other';

  static const dataUsageImportAuto = 'data_usage_import_auto';
  static const dataUsageHrOnly = 'data_usage_hr_only';
  static const dataUsagePaceDistance = 'data_usage_pace_distance';
  static const dataUsageAll = 'data_usage_all';
  static const dataUsageNotSure = 'data_usage_not_sure';

  static const metricHeartRate = 'metric_heart_rate';
  static const metricHeartRateZones = 'metric_heart_rate_zones';
  static const metricPace = 'metric_pace';
  static const metricDistance = 'metric_distance';
  static const metricCadence = 'metric_cadence';
  static const metricElevation = 'metric_elevation';
  static const metricTrainingLoad = 'metric_training_load';
  static const metricRecoveryTime = 'metric_recovery_time';

  static const autoAdjustAuto = 'auto_adjust_auto';
  static const autoAdjustAskFirst = 'auto_adjust_ask_first';

  static const noWatchEffortOnly = 'no_watch_effort_only';
  static const noWatchTimeBased = 'no_watch_time_based';
  static const noWatchBeginner = 'no_watch_beginner';
  static const noWatchDecideForMe = 'no_watch_decide_for_me';

  static String localizeRace(String key, AppLocalizations l10n) {
    switch (key) {
      case race5k:
        return l10n.race5K;
      case race10k:
        return l10n.race10K;
      case raceHalfMarathon:
        return l10n.raceHalfMarathon;
      case raceMarathon:
        return l10n.raceMarathon;
      case raceOther:
        return l10n.raceOther;
      default:
        return key;
    }
  }

  static String raceSubtitle(
    String key,
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    switch (key) {
      case race5k:
        return UnitFormatter.formatDistanceCompactLabel(5, unitSystem, l10n);
      case race10k:
        return UnitFormatter.formatDistanceCompactLabel(10, unitSystem, l10n);
      case raceHalfMarathon:
        return UnitFormatter.formatDistanceCompactLabel(21.1, unitSystem, l10n);
      case raceMarathon:
        return UnitFormatter.formatDistanceCompactLabel(42.2, unitSystem, l10n);
      case raceOther:
        return l10n.raceCustomDistance;
      default:
        return key;
    }
  }

  static List<OnboardingOption> weeklyVolumeOptions(
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    if (unitSystem == UnitSystem.km) {
      return [
        (key: weeklyVolume0, label: _singleValueLabel(0, unitSystem, l10n)),
        (key: weeklyVolume1, label: _rangeLabel(1, 13, unitSystem, l10n)),
        (key: weeklyVolume2, label: _rangeLabel(10, 16, unitSystem, l10n)),
        (key: weeklyVolume3, label: _rangeLabel(17, 24, unitSystem, l10n)),
        (key: weeklyVolume4, label: _rangeLabel(25, 32, unitSystem, l10n)),
        (key: weeklyVolume5, label: _rangeLabel(33, 48, unitSystem, l10n)),
        (key: weeklyVolume6, label: _plusLabel(49, unitSystem, l10n)),
      ];
    }

    return [
      (key: weeklyVolume0, label: _singleValueLabel(0, unitSystem, l10n)),
      (key: weeklyVolume1, label: _rangeLabel(1, 5, unitSystem, l10n)),
      (key: weeklyVolume2, label: _rangeLabel(6, 10, unitSystem, l10n)),
      (key: weeklyVolume3, label: _rangeLabel(11, 15, unitSystem, l10n)),
      (key: weeklyVolume4, label: _rangeLabel(16, 20, unitSystem, l10n)),
      (key: weeklyVolume5, label: _rangeLabel(21, 30, unitSystem, l10n)),
      (key: weeklyVolume6, label: _plusLabel(31, unitSystem, l10n)),
    ];
  }

  static String localizeWeeklyVolume(
    String key,
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    final labels = Map<String, String>.fromEntries(
      weeklyVolumeOptions(unitSystem, l10n).map((option) {
        return MapEntry(option.key, option.label);
      }),
    );
    return labels[key] ?? key;
  }

  static List<OnboardingOption> longestRunOptions(
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    if (unitSystem == UnitSystem.km) {
      return [
        (key: longestRun0, label: l10n.longestRunNone),
        (key: longestRun1, label: l10n.longestRunLessThan5km),
        (key: longestRun2, label: _rangeLabel(5, 8, unitSystem, l10n)),
        (key: longestRun3, label: _rangeLabel(9, 13, unitSystem, l10n)),
        (key: longestRun4, label: _rangeLabel(14, 16, unitSystem, l10n)),
        (key: longestRun5, label: _rangeLabel(17, 21, unitSystem, l10n)),
        (key: longestRun6, label: _plusLabel(21, unitSystem, l10n)),
      ];
    }

    return [
      (key: longestRun0, label: l10n.longestRunNone),
      (key: longestRun1, label: l10n.longestRunLessThan3mi),
      (key: longestRun2, label: _rangeLabel(3, 5, unitSystem, l10n)),
      (key: longestRun3, label: _rangeLabel(6, 8, unitSystem, l10n)),
      (key: longestRun4, label: _rangeLabel(9, 10, unitSystem, l10n)),
      (key: longestRun5, label: _rangeLabel(11, 13, unitSystem, l10n)),
      (key: longestRun6, label: _plusLabel(13, unitSystem, l10n)),
    ];
  }

  static String localizeLongestRun(
    String key,
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    final labels = Map<String, String>.fromEntries(
      longestRunOptions(unitSystem, l10n).map((option) {
        return MapEntry(option.key, option.label);
      }),
    );
    return labels[key] ?? key;
  }

  static String _singleValueLabel(
    int value,
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    return '$value ${unitSystem == UnitSystem.km ? l10n.unitKm : l10n.unitMi}';
  }

  static String _rangeLabel(
    int start,
    int end,
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    return '$start–$end ${unitSystem == UnitSystem.km ? l10n.unitKm : l10n.unitMi}';
  }

  static String _plusLabel(
    int value,
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    return '$value+ ${unitSystem == UnitSystem.km ? l10n.unitKm : l10n.unitMi}';
  }

  static String localizePriority(String key, AppLocalizations l10n) {
    switch (key) {
      case priorityJustFinish:
        return l10n.priorityJustFinish;
      case priorityFinishStrong:
        return l10n.priorityFinishStrong;
      case priorityImproveTime:
        return l10n.priorityImproveTime;
      case priorityConsistency:
        return l10n.priorityConsistency;
      case priorityGeneralFitness:
        return l10n.priorityGeneralFitness;
      default:
        return key;
    }
  }

  static String localizeExperience(String key, AppLocalizations l10n) {
    switch (key) {
      case experienceBrandNew:
        return l10n.experienceBrandNew;
      case experienceBeginner:
        return l10n.experienceBeginner;
      case experienceIntermediate:
        return l10n.experienceIntermediate;
      case experienceExperienced:
        return l10n.experienceExperienced;
      default:
        return key;
    }
  }

  static String localizeBinary(String key, AppLocalizations l10n) {
    switch (key) {
      case yes:
        return l10n.yes;
      case no:
        return l10n.no;
      case notSure:
        return l10n.notSure;
      case onlyIfNeeded:
        return l10n.onlyIfNeeded;
      case ifSupported:
        return l10n.ifSupported;
      case hrOnly:
        return l10n.hrOnly;
      case decideForMe:
        return l10n.guidanceDecideForMe;
      case none:
        return l10n.metricNone;
      default:
        return key;
    }
  }

  static String localizeBenchmark(String key, AppLocalizations l10n) {
    switch (key) {
      case benchmark1KmRun:
        return l10n.benchmarkKmRun;
      case benchmark1KmWalk:
        return l10n.benchmarkKmWalk;
      case benchmark1MiRun:
        return l10n.benchmarkMiRun;
      case benchmark1MiWalk:
        return l10n.benchmarkMiWalk;
      case benchmark5k:
        return l10n.benchmark5K;
      case benchmark10k:
        return l10n.benchmark10K;
      case benchmarkHalfMarathon:
        return l10n.benchmarkHalfMarathon;
      case benchmarkSkip:
        return l10n.benchmarkSkipForNow;
      default:
        return key;
    }
  }

  static String localizeRaceDistanceBefore(String key, AppLocalizations l10n) {
    switch (key) {
      case raceDistanceNever:
        return l10n.raceDistanceNever;
      case raceDistanceOnce:
        return l10n.raceDistanceOnce;
      case raceDistance2to3:
        return l10n.raceDistance2to3;
      case raceDistance4plus:
        return l10n.raceDistance4plus;
      default:
        return key;
    }
  }

  static String localizeDay(String key, AppLocalizations l10n) {
    switch (key) {
      case dayMon:
        return l10n.dayMon;
      case dayTue:
        return l10n.dayTue;
      case dayWed:
        return l10n.dayWed;
      case dayThu:
        return l10n.dayThu;
      case dayFri:
        return l10n.dayFri;
      case daySat:
        return l10n.daySat;
      case daySun:
        return l10n.daySun;
      default:
        return key;
    }
  }

  static String localizeTimeSlot(String key, AppLocalizations l10n) {
    switch (key) {
      case time20min:
        return l10n.time20min;
      case time30min:
        return l10n.time30min;
      case time45min:
        return l10n.time45min;
      case time60min:
        return l10n.time60min;
      case time75plusMin:
        return l10n.time75plusMin;
      case time90min:
        return l10n.time90min;
      case time2plusHours:
        return l10n.time2plusHours;
      default:
        return key;
    }
  }

  static String localizeTimeOfDay(String key, AppLocalizations l10n) {
    switch (key) {
      case timeOfDayEarlyMorning:
        return l10n.timeOfDayEarlyMorning;
      case timeOfDayMorning:
        return l10n.timeOfDayMorning;
      case timeOfDayAfternoon:
        return l10n.timeOfDayAfternoon;
      case timeOfDayEvening:
        return l10n.timeOfDayEvening;
      case timeOfDayNoPreference:
        return l10n.timeOfDayNoPreference;
      default:
        return key;
    }
  }

  static String localizePainLevel(String key, AppLocalizations l10n) {
    switch (key) {
      case painNo:
        return l10n.painNo;
      case painMild:
        return l10n.painMild;
      case painModerate:
        return l10n.painModerate;
      case painSevere:
        return l10n.painSevere;
      default:
        return key;
    }
  }

  static String localizeInjuryHistory(String key, AppLocalizations l10n) {
    switch (key) {
      case injuryNo:
        return l10n.injuryNo;
      case injuryOnce:
        return l10n.injuryOnce;
      case injuryMultiple:
        return l10n.injuryMultiple;
      default:
        return key;
    }
  }

  static String localizePlanPreference(String key, AppLocalizations l10n) {
    switch (key) {
      case planSafest:
        return l10n.planSafest;
      case planBalanced:
        return l10n.planBalanced;
      case planPerformance:
        return l10n.planPerformance;
      default:
        return key;
    }
  }

  static String localizePlanPreferenceSubtitle(
    String key,
    AppLocalizations l10n,
  ) {
    switch (key) {
      case planSafest:
        return l10n.planSafestSub;
      case planBalanced:
        return l10n.planBalancedSub;
      case planPerformance:
        return l10n.planPerformanceSub;
      default:
        return key;
    }
  }

  static String localizeGuidanceMode(String key, AppLocalizations l10n) {
    switch (key) {
      case guidanceEffort:
        return l10n.guidanceEffort;
      case guidancePace:
        return l10n.guidancePace;
      case guidanceHeartRate:
        return l10n.guidanceHeartRate;
      case guidanceDecideForMe:
        return l10n.guidanceDecideForMe;
      default:
        return key;
    }
  }

  static String localizeStrengthTraining(String key, AppLocalizations l10n) {
    switch (key) {
      case strengthNone:
        return l10n.no;
      case strength1Day:
        return l10n.strength1DayWeek;
      case strength2Days:
        return l10n.strength2DaysWeek;
      case strength3Days:
        return l10n.strength3DaysWeek;
      default:
        return key;
    }
  }

  static String localizeSurface(String key, AppLocalizations l10n) {
    switch (key) {
      case surfaceRoad:
        return l10n.surfaceRoad;
      case surfaceTreadmill:
        return l10n.surfaceTreadmill;
      case surfaceTrack:
        return l10n.surfaceTrack;
      case surfaceTrail:
        return l10n.surfaceTrail;
      case surfaceMixed:
        return l10n.surfaceMixed;
      default:
        return key;
    }
  }

  static String localizeTerrain(String key, AppLocalizations l10n) {
    switch (key) {
      case terrainFlat:
        return l10n.terrainFlat;
      case terrainSomeHills:
        return l10n.terrainSomeHills;
      case terrainHilly:
        return l10n.terrainHilly;
      case terrainMixed:
        return l10n.terrainMixed;
      default:
        return key;
    }
  }

  static String localizeDevice(String key, AppLocalizations l10n) {
    switch (key) {
      case deviceGarmin:
        return l10n.deviceGarmin;
      case deviceAppleWatch:
        return l10n.deviceAppleWatch;
      case deviceCoros:
        return l10n.deviceCOROS;
      case devicePolar:
        return l10n.devicePolar;
      case deviceSuunto:
        return l10n.deviceSuunto;
      case deviceFitbit:
        return l10n.deviceFitbit;
      case deviceOther:
        return l10n.deviceOther;
      default:
        return key;
    }
  }

  static String localizeDataUsage(String key, AppLocalizations l10n) {
    switch (key) {
      case dataUsageImportAuto:
        return l10n.dataUsageImportAuto;
      case dataUsageHrOnly:
        return l10n.dataUsageHROnly;
      case dataUsagePaceDistance:
        return l10n.dataUsagePaceDistance;
      case dataUsageAll:
        return l10n.dataUsageAll;
      case dataUsageNotSure:
        return l10n.dataUsageNotSure;
      default:
        return key;
    }
  }

  static String localizeMetric(String key, AppLocalizations l10n) {
    switch (key) {
      case metricHeartRate:
        return l10n.metricHeartRate;
      case metricHeartRateZones:
        return l10n.metricHRZones;
      case metricPace:
        return l10n.metricPace;
      case metricDistance:
        return l10n.metricDistance;
      case metricCadence:
        return l10n.metricCadence;
      case metricElevation:
        return l10n.metricElevation;
      case metricTrainingLoad:
        return l10n.metricTrainingLoad;
      case metricRecoveryTime:
        return l10n.metricRecoveryTime;
      case none:
        return l10n.metricNone;
      default:
        return key;
    }
  }

  static String localizeAutoAdjust(String key, AppLocalizations l10n) {
    switch (key) {
      case autoAdjustAuto:
        return l10n.autoAdjustAuto;
      case autoAdjustAskFirst:
        return l10n.autoAdjustAskFirst;
      case no:
        return l10n.no;
      default:
        return key;
    }
  }

  static String localizeNoWatchGuidance(String key, AppLocalizations l10n) {
    switch (key) {
      case noWatchEffortOnly:
        return l10n.noWatchEffortOnly;
      case noWatchTimeBased:
        return l10n.noWatchTimeBased;
      case noWatchBeginner:
        return l10n.noWatchBeginner;
      case noWatchDecideForMe:
        return l10n.noWatchDecideForMe;
      default:
        return key;
    }
  }

}
