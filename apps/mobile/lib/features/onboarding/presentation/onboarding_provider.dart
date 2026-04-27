import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../integrations/presentation/device_connection_provider.dart';
import '../../profile/data/runner_profile_repository.dart';
import '../../profile/domain/models/runner_profile.dart';
import '../../profile/presentation/runner_profile_provider.dart';
import '../../user_preferences/presentation/user_preferences_provider.dart';

class OnboardingNotifier extends AsyncNotifier<RunnerProfileDraft> {
  static const _keyCompleted = 'onboarding_completed';

  RunnerProfileRepository get _repository =>
      ref.read(runnerProfileRepositoryProvider);

  @override
  Future<RunnerProfileDraft> build() async {
    final persistedProfile = await _repository.loadProfileAsync();
    if (persistedProfile != null) {
      return RunnerProfileDraft.fromRunnerProfile(persistedProfile);
    }

    return await _repository.loadDraftAsync() ?? const RunnerProfileDraft();
  }

  void _setState(RunnerProfileDraft nextState) {
    state = AsyncData(nextState);
    unawaited(_saveDraft(nextState));
  }

  Future<bool> saveProfile({
    bool markOnboardingComplete = false,
    DateTime? clock,
  }) async {
    final preferences = await ref.read(userPreferencesProvider.future);
    final draft = state.value ?? const RunnerProfileDraft();
    final timestamp = clock ?? DateTime.now();
    final existingCompletedOnboardingAt =
        ref.read(runnerProfileProvider).value?.completedOnboardingAt ??
        _repository.loadProfile()?.completedOnboardingAt;
    final completedOnboardingAt = markOnboardingComplete
        ? timestamp
        : existingCompletedOnboardingAt;
    final profile = draft.toRunnerProfile(
      gender: preferences.gender,
      dateOfBirth: preferences.dateOfBirth,
      completedOnboardingAt: completedOnboardingAt,
      clock: timestamp,
    );
    if (profile == null) {
      return false;
    }

    try {
      await ref.read(runnerProfileProvider.notifier).setProfile(profile);
      await ref
          .read(deviceConnectionsProvider.notifier)
          .seedWatchFromDeviceProfileIfAbsent(profile.device);
      if (markOnboardingComplete) {
        await ref.read(sharedPreferencesProvider).setBool(_keyCompleted, true);
      }
      if (ref.mounted) {
        state = AsyncData(RunnerProfileDraft.fromRunnerProfile(profile));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markCompleted({DateTime? clock}) {
    return saveProfile(markOnboardingComplete: true, clock: clock);
  }

  void setGoal({
    required String race,
    required bool hasRaceDate,
    DateTime? raceDate,
    required String priority,
    Duration? currentTime,
    Duration? targetTime,
  }) {
    _setState(
      (state.value ?? const RunnerProfileDraft()).copyWith(
        goal: GoalProfileDraft(
          race: RunnerGoalRace.fromKey(race),
          hasRaceDate: hasRaceDate,
          raceDate: raceDate,
          priority: GoalPriority.fromKey(priority),
          currentTime: currentTime,
          targetTime: targetTime,
        ),
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
    _setState(
      (state.value ?? const RunnerProfileDraft()).copyWith(
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
    _setState(
      (state.value ?? const RunnerProfileDraft()).copyWith(
        schedule: RunnerProfileDraft.scheduleFromInput(
          trainingDays: trainingDays,
          longRunDay: longRunDay,
          weekdayTime: weekdayTime,
          weekendTime: weekendTime,
          hardDays: hardDays,
          preferredTimeOfDay: preferredTimeOfDay,
        ),
      ),
    );
  }

  void setHealth({
    required String painLevel,
    required String injuryHistory,
    required String healthConditions,
  }) {
    _setState(
      (state.value ?? const RunnerProfileDraft()).copyWith(
        health: RunnerProfileDraft.healthFromInput(
          painLevel: painLevel,
          injuryHistory: injuryHistory,
          healthConditions: healthConditions,
        ),
      ),
    );
  }

  void setTraining({required String planPreference}) {
    _setState(
      (state.value ?? const RunnerProfileDraft()).copyWith(
        trainingPreferences: RunnerProfileDraft.trainingFromInput(
          planPreference: planPreference,
        ),
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
    _setState(
      (state.value ?? const RunnerProfileDraft()).copyWith(
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
      ),
    );
  }

  void setRecovery({
    required String sleep,
    required String workLevel,
    required String stressLevel,
    required String dayFeeling,
  }) {
    _setState(
      (state.value ?? const RunnerProfileDraft()).copyWith(
        recovery: RunnerProfileDraft.recoveryFromInput(
          sleep: sleep,
          workLevel: workLevel,
          stressLevel: stressLevel,
          dayFeeling: dayFeeling,
        ),
      ),
    );
  }

  void setMotivation({
    required List<String> motivations,
    required List<String> barriers,
    required int confidence,
    required String coachingTone,
  }) {
    _setState(
      (state.value ?? const RunnerProfileDraft()).copyWith(
        motivation: RunnerProfileDraft.motivationFromInput(
          motivations: motivations,
          barriers: barriers,
          confidence: confidence,
          coachingTone: coachingTone,
        ),
      ),
    );
  }

  Future<void> _saveDraft(RunnerProfileDraft nextState) async {
    try {
      if (await _repository.hasPersistedProfileAsync()) return;
      await _repository.saveDraft(nextState);
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncError(error, stackTrace);
      }
    }
  }
}

final onboardingProvider =
    AsyncNotifierProvider<OnboardingNotifier, RunnerProfileDraft>(
      OnboardingNotifier.new,
    );
