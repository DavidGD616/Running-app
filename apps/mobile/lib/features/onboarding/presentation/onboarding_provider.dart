import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../integrations/presentation/device_connection_provider.dart';
import '../../strava/domain/athlete_summary.dart';
import '../../profile/data/runner_profile_repository.dart';
import '../../profile/domain/models/runner_profile.dart';
import '../../profile/presentation/runner_profile_provider.dart';
import '../../user_preferences/presentation/user_preferences_provider.dart';
import 'onboarding_values.dart';

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
          fitnessSource: OnboardingValues.fitnessSourceManual,
          stravaWeeklyVolumeKm: null,
          stravaLongestRecentRunKm: null,
          stravaRunsPerWeek: null,
          stravaDataWeeks: null,
          stravaInsufficientData: null,
          athleteSummary: null,
          stravaCoachingProfile: null,
        ),
      ),
    );
  }

  void setFitnessSource(String source) {
    switch (source) {
      case OnboardingValues.fitnessSourceManual:
        useManualFitnessInput();
      case OnboardingValues.fitnessSourceStrava:
        final draft = state.value ?? const RunnerProfileDraft();
        final fitness = draft.fitness;
        _setState(
          draft.copyWith(
            fitness: FitnessProfileDraft(
              experience: fitness.experience,
              canRun10Min: fitness.canRun10Min,
              runningDays: fitness.runningDays,
              weeklyVolume: fitness.weeklyVolume,
              longestRun: fitness.longestRun,
              canCompleteGoalDistance: fitness.canCompleteGoalDistance,
              raceDistanceBefore: fitness.raceDistanceBefore,
              benchmark: fitness.benchmark,
              benchmarkTime: fitness.benchmarkTime,
              fitnessSource: OnboardingValues.fitnessSourceStrava,
              stravaWeeklyVolumeKm: fitness.stravaWeeklyVolumeKm,
              stravaLongestRecentRunKm: fitness.stravaLongestRecentRunKm,
              stravaRunsPerWeek: fitness.stravaRunsPerWeek,
              stravaDataWeeks: fitness.stravaDataWeeks,
              stravaInsufficientData: fitness.stravaInsufficientData,
              athleteSummary: fitness.athleteSummary,
              stravaCoachingProfile: fitness.stravaCoachingProfile,
            ),
          ),
        );
    }
  }

  void useManualFitnessInput() {
    final draft = state.value ?? const RunnerProfileDraft();
    final fitness = draft.fitness;
    final wasStrava =
        fitness.fitnessSource == OnboardingValues.fitnessSourceStrava;

    // When the prior source was Strava, the canonical fitness fields hold
    // values that were *derived* from Strava data. Opting into manual input
    // should start the Fitness screen blank rather than presenting those
    // inferred answers as if the user had typed them. For genuinely manual
    // input (no prior Strava connect), preserve whatever the user entered.
    _setState(
      draft.copyWith(
        fitness: wasStrava
            ? const FitnessProfileDraft(
                fitnessSource: OnboardingValues.fitnessSourceManual,
              )
            : FitnessProfileDraft(
                experience: fitness.experience,
                canRun10Min: fitness.canRun10Min,
                runningDays: fitness.runningDays,
                weeklyVolume: fitness.weeklyVolume,
                longestRun: fitness.longestRun,
                canCompleteGoalDistance: fitness.canCompleteGoalDistance,
                raceDistanceBefore: fitness.raceDistanceBefore,
                benchmark: fitness.benchmark,
                benchmarkTime: fitness.benchmarkTime,
                fitnessSource: OnboardingValues.fitnessSourceManual,
              ),
      ),
    );
  }

  /// Clears Strava-derived fitness state after the user disconnects the
  /// Strava integration. Switches the onboarding draft back to manual input
  /// (dropping derived answers + snapshot fields) and, when a RunnerProfile
  /// has already been persisted, rewrites its fitness section so the backend
  /// no longer receives `fitnessSource: 'strava'` + athleteSummary and the
  /// Summary screen stops showing the "From Strava" tag.
  Future<void> clearStravaFitness({DateTime? clock}) async {
    final draft = state.value ?? const RunnerProfileDraft();
    final wasStravaDraft =
        draft.fitness.fitnessSource == OnboardingValues.fitnessSourceStrava;
    if (wasStravaDraft) {
      useManualFitnessInput();
    }

    final profile = ref.read(runnerProfileProvider).value;
    if (profile == null) return;
    if (profile.fitness.fitnessSource != FitnessSource.strava) {
      return;
    }

    final clearedFitness = FitnessProfile(
      experience: profile.fitness.experience,
      canRun10Min: profile.fitness.canRun10Min,
      runningDays: profile.fitness.runningDays,
      weeklyVolume: profile.fitness.weeklyVolume,
      longestRun: profile.fitness.longestRun,
      canCompleteGoalDistance: profile.fitness.canCompleteGoalDistance,
      raceDistanceBefore: profile.fitness.raceDistanceBefore,
      benchmark: profile.fitness.benchmark,
      benchmarkTime: profile.fitness.benchmarkTime,
      fitnessSource: FitnessSource.manual,
      athleteSummary: null,
    );
    final updatedProfile = profile.copyWith(
      fitness: clearedFitness,
      updatedAt: clock ?? DateTime.now(),
    );

    await ref.read(runnerProfileProvider.notifier).setProfile(updatedProfile);
    if (ref.mounted && !wasStravaDraft) {
      state = AsyncData(RunnerProfileDraft.fromRunnerProfile(updatedProfile));
    }
  }

  void setStravaCoachingProfile({
    required AthleteSummary summary,
    required StravaCoachingProfile coachingProfile,
  }) {
    final mapping = mapSummaryToOnboarding(summary);
    final canRun10Min = mapping.experience == RunnerExperience.brandNew
        ? true
        : null;
    _setState(
      (state.value ?? const RunnerProfileDraft()).copyWith(
        fitness: RunnerProfileDraft.fitnessFromInput(
          experience: mapping.experience.key,
          canRun10Min: canRun10Min,
          runningDays: summary.runsPerWeek.round().clamp(1, 7).toString(),
          weeklyVolume: mapping.weeklyVolume.key,
          longestRun: mapping.longestRun.key,
          canCompleteGoalDist: OnboardingValues.notSure,
          raceDistanceBefore: OnboardingValues.raceDistanceNever,
          benchmark: mapping.benchmark.type.key,
          benchmarkTime: mapping.benchmark.time,
          fitnessSource: OnboardingValues.fitnessSourceStrava,
          stravaWeeklyVolumeKm: summary.weeklyVolumeKm,
          stravaLongestRecentRunKm: summary.longestRecentRunKm,
          stravaRunsPerWeek: summary.runsPerWeek,
          stravaDataWeeks: summary.dataWeeks,
          stravaInsufficientData: summary.insufficientData,
          athleteSummary: AthleteSummarySnapshot(
            weeklyVolumeKm: summary.weeklyVolumeKm,
            volumeTrend: summary.volumeTrend,
            acuteChronicRatio: summary.acuteChronicRatio,
            longestRecentRunKm: summary.longestRecentRunKm,
            typicalEasyPaceSecPerKm: summary.typicalEasyPaceSecPerKm,
            typicalHardPaceSecPerKm: summary.typicalHardPaceSecPerKm,
            estimatedThresholdPaceSecPerKm:
                summary.estimatedThresholdPaceSecPerKm,
            runsPerWeek: summary.runsPerWeek,
            longestLayoffDays: summary.longestLayoffDays,
            weeksActiveInLast8: summary.weeksActiveInLast8,
            dataWeeks: summary.dataWeeks,
            insufficientData: summary.insufficientData,
            hasHeartRateZones: summary.hasHeartRateZones,
          ),
          stravaCoachingProfile: coachingProfile,
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
    DateTime? planStartDate,
  }) {
    final currentDraft = state.value ?? const RunnerProfileDraft();

    _setState(
      currentDraft.copyWith(
        schedule: RunnerProfileDraft.scheduleFromInput(
          trainingDays: trainingDays,
          longRunDay: longRunDay,
          weekdayTime: weekdayTime,
          weekendTime: weekendTime,
          hardDays: hardDays,
          preferredTimeOfDay: preferredTimeOfDay,
          planStartDate: planStartDate ?? currentDraft.schedule.planStartDate,
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

  void setStrength({
    required bool lifts,
    String? weeklyFrequency,
    List<String>? categories,
    List<String>? preferredDays,
    String? sameDayOrder,
  }) {
    _setState(
      (state.value ?? const RunnerProfileDraft()).copyWith(
        strength: RunnerProfileDraft.strengthFromInput(
          lifts: lifts,
          weeklyFrequency: weeklyFrequency,
          categories: categories,
          preferredDays: preferredDays,
          sameDayOrder: sameDayOrder,
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
