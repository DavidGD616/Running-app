import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingNotifier extends Notifier<Map<String, dynamic>> {
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
    state = {
      ...state,
      'race': race,
      'hasRaceDate': hasRaceDate,
      'raceDate': ?raceDate,
      'priority': priority,
      'currentTime': ?currentTime,
      'targetTime': ?targetTime,
    };
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
    required String preferredTimeOfDay,
  }) {
    state = {
      ...state,
      'trainingDays': trainingDays,
      'longRunDay': longRunDay,
      'weekdayTime': weekdayTime,
      'weekendTime': weekendTime,
      'hardDays': hardDays,
      'preferredTimeOfDay': preferredTimeOfDay,
    };
  }

  void setHealth({
    required String painLevel,
    required String injuryHistory,
    required String healthConditions,
    required String planPreference,
  }) {
    state = {
      ...state,
      'painLevel': painLevel,
      'injuryHistory': injuryHistory,
      'healthConditions': healthConditions,
      'planPreference': planPreference,
    };
  }

  void setTraining({
    required String guidanceMode,
    required String speedWorkouts,
    required String strengthTraining,
    required String runSurface,
    required String terrain,
    required String walkRunIntervals,
  }) {
    state = {
      ...state,
      'guidanceMode': guidanceMode,
      'speedWorkouts': speedWorkouts,
      'strengthTraining': strengthTraining,
      'runSurface': runSurface,
      'terrain': terrain,
      'walkRunIntervals': walkRunIntervals,
    };
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
    state = {
      ...state,
      'hasWatch': hasWatch,
      'device': ?device,
      'dataUsage': ?dataUsage,
      'watchMetrics': ?watchMetrics,
      'metrics': ?metrics,
      'hrZones': ?hrZones,
      'paceRecs': ?paceRecs,
      'autoAdjust': ?autoAdjust,
      'noWatchGuidance': ?noWatchGuidance,
    };
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
