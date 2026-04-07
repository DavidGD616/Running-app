import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../profile/domain/models/runner_profile.dart';

class OnboardingNotifier extends Notifier<RunnerProfileDraft> {
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
  RunnerProfileDraft build() => const RunnerProfileDraft();

  void setGoal({
    required String race,
    required bool hasRaceDate,
    DateTime? raceDate,
    required String priority,
    Duration? currentTime,
    Duration? targetTime,
  }) {
    state = state.copyWith(
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
    state = state.copyWith(
      fitness: RunnerProfileDraft.fitnessFromInput(
        experience: experience,
        canRun10Min: canRun10Min,
        runningDays: runningDays,
        weeklyVolume: weeklyVolume,
        longestRun: longestRun,
        canCompleteGoalDist: canCompleteGoalDist,
        raceDistanceBefore: raceDistanceBefore,
        benchmark: benchmark,
        benchmarkTime: benchmarkTime,
      ),
    );
  }

  void setSchedule({
    required String trainingDays,
    required String longRunDay,
    required String weekdayTime,
    required String weekendTime,
    required List<String> hardDays,
    String? preferredTimeOfDay,
  }) {
    state = state.copyWith(
      schedule: RunnerProfileDraft.scheduleFromInput(
        trainingDays: trainingDays,
        longRunDay: longRunDay,
        weekdayTime: weekdayTime,
        weekendTime: weekendTime,
        hardDays: hardDays,
        preferredTimeOfDay: preferredTimeOfDay,
      ),
    );
  }

  void setHealth({
    required String painLevel,
    required String injuryHistory,
    required String healthConditions,
  }) {
    state = state.copyWith(
      health: RunnerProfileDraft.healthFromInput(
        painLevel: painLevel,
        injuryHistory: injuryHistory,
        healthConditions: healthConditions,
      ),
    );
  }

  void setTraining({required String planPreference}) {
    state = state.copyWith(
      trainingPreferences: RunnerProfileDraft.trainingFromInput(
        planPreference: planPreference,
      ),
    );
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
    state = state.copyWith(
      device: RunnerProfileDraft.deviceFromInput(
        hasWatch: hasWatch,
        device: device,
        dataUsage: dataUsage,
        watchMetrics: watchMetrics,
        metrics: metrics,
        hrZones: hrZones,
        paceRecs: paceRecs,
        autoAdjust: autoAdjust,
        noWatchGuidance: noWatchGuidance,
      ),
    );
  }

  void setRecovery({
    required String sleep,
    required String workLevel,
    required String stressLevel,
    required String dayFeeling,
  }) {
    state = state.copyWith(
      recovery: RunnerProfileDraft.recoveryFromInput(
        sleep: sleep,
        workLevel: workLevel,
        stressLevel: stressLevel,
        dayFeeling: dayFeeling,
      ),
    );
  }

  void setMotivation({
    required List<String> motivations,
    required List<String> barriers,
    required int confidence,
    required String coachingTone,
  }) {
    state = state.copyWith(
      motivation: RunnerProfileDraft.motivationFromInput(
        motivations: motivations,
        barriers: barriers,
        confidence: confidence,
        coachingTone: coachingTone,
      ),
    );
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, RunnerProfileDraft>(
      OnboardingNotifier.new,
    );
