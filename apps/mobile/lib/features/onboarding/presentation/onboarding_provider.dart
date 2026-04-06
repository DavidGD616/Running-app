import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingNotifier extends Notifier<Map<String, dynamic>> {
  static const _keyCompleted = 'onboarding_completed';

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCompleted) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompleted, true);
  }

  @override
  Map<String, dynamic> build() => {};

  void setGoal({
    required String race,
    required bool hasRaceDate,
    DateTime? raceDate,
    required String priority,
    Duration? currentTime,
    Duration? targetTime,
  }) {
    final next = <String, dynamic>{
      ...state,
      'race': race,
      'hasRaceDate': hasRaceDate,
      'priority': priority,
    };

    if (raceDate != null) {
      next['raceDate'] = raceDate;
    } else {
      next.remove('raceDate');
    }

    if (currentTime != null) {
      next['currentTime'] = currentTime;
    } else {
      next.remove('currentTime');
    }

    if (targetTime != null) {
      next['targetTime'] = targetTime;
    } else {
      next.remove('targetTime');
    }

    state = next;
  }

  void setFitness({
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
    state = {
      ...state,
      'experience': experience,
      'canRun10Min': ?canRun10Min,
      'runningDays': ?runningDays,
      'weeklyVolume': ?weeklyVolume,
      'longestRun': ?longestRun,
      'canCompleteGoalDist': ?canCompleteGoalDist,
      'raceDistanceBefore': ?raceDistanceBefore,
      'benchmark': ?benchmark,
      'benchmarkTime': ?benchmarkTime,
    };
  }

  void setSchedule({
    required String trainingDays,
    required String longRunDay,
    required String weekdayTime,
    required String weekendTime,
    required List<String> hardDays,
    String? preferredTimeOfDay,
  }) {
    final next = <String, dynamic>{
      ...state,
      'trainingDays': trainingDays,
      'longRunDay': longRunDay,
      'weekdayTime': weekdayTime,
      'weekendTime': weekendTime,
      'hardDays': hardDays,
    };

    if (preferredTimeOfDay != null) {
      next['preferredTimeOfDay'] = preferredTimeOfDay;
    } else {
      next.remove('preferredTimeOfDay');
    }

    state = next;
  }

  void setHealth({
    required String painLevel,
    required String injuryHistory,
    required String healthConditions,
  }) {
    state = {
      ...state,
      'painLevel': painLevel,
      'injuryHistory': injuryHistory,
      'healthConditions': healthConditions,
    };
  }

  void setTraining({required String planPreference}) {
    final next = <String, dynamic>{...state, 'planPreference': planPreference};

    next.remove('walkRunIntervals');
    next.remove('guidanceMode');
    next.remove('speedWorkouts');
    next.remove('strengthTraining');
    next.remove('runSurface');
    next.remove('terrain');

    state = next;
  }

  void setDevice({
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
    final next = <String, dynamic>{...state, 'hasWatch': hasWatch};

    if (device != null) {
      next['device'] = device;
    } else {
      next.remove('device');
    }

    if (dataUsage != null) {
      next['dataUsage'] = dataUsage;
    } else {
      next.remove('dataUsage');
    }

    if (watchMetrics != null) {
      next['watchMetrics'] = watchMetrics;
    } else {
      next.remove('watchMetrics');
    }

    if (metrics != null) {
      next['metrics'] = metrics;
    } else {
      next.remove('metrics');
    }

    if (hrZones != null) {
      next['hrZones'] = hrZones;
    } else {
      next.remove('hrZones');
    }

    if (paceRecs != null) {
      next['paceRecs'] = paceRecs;
    } else {
      next.remove('paceRecs');
    }

    if (autoAdjust != null) {
      next['autoAdjust'] = autoAdjust;
    } else {
      next.remove('autoAdjust');
    }

    if (noWatchGuidance != null) {
      next['noWatchGuidance'] = noWatchGuidance;
    } else {
      next.remove('noWatchGuidance');
    }

    state = next;
  }

  void setRecovery({
    required String sleep,
    required String workLevel,
    required String stressLevel,
    required String dayFeeling,
  }) {
    state = {
      ...state,
      'sleep': sleep,
      'workLevel': workLevel,
      'stressLevel': stressLevel,
      'dayFeeling': dayFeeling,
    };
  }

  void setMotivation({
    required List<String> motivations,
    required List<String> barriers,
    required int confidence,
    required String coachingTone,
  }) {
    state = {
      ...state,
      'motivations': motivations,
      'barriers': barriers,
      'confidence': confidence,
      'coachingTone': coachingTone,
    };
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, Map<String, dynamic>>(
      OnboardingNotifier.new,
    );
