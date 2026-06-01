import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/features/integrations/data/device_connection_repository.dart';
import 'package:running_app/features/integrations/domain/models/device_connection.dart';
import 'package:running_app/features/integrations/presentation/device_connection_provider.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/profile/data/runner_profile_repository.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_values.dart';
import 'package:running_app/features/strava/domain/athlete_summary.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/profile/presentation/runner_profile_provider.dart';
import 'package:running_app/features/user_preferences/data/supabase_user_preferences_repository.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/features/user_preferences/presentation/user_preferences_provider.dart';

import '../../../helpers/runner_profile_fixtures.dart';

ProviderContainer _testContainer(SharedPreferences prefs) {
  return ProviderContainer.test(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userPreferencesRepositoryProvider.overrideWithValue(
        SharedPreferencesUserPreferencesRepository(prefs),
      ),
    ],
  );
}

class _FailingRunnerProfileNotifier extends RunnerProfileNotifier {
  _FailingRunnerProfileNotifier(this.error);

  final Object error;

  @override
  Future<RunnerProfile?> build() async => null;

  @override
  Future<void> setProfile(RunnerProfile profile) async {
    throw error;
  }
}

AthleteSummary _buildAthleteSummary() {
  return const AthleteSummary(
    weeklyVolumeKm: 32.5,
    volumeTrend: VolumeTrend.steady,
    acuteChronicRatio: 1.05,
    longestRecentRunKm: 14.2,
    typicalEasyPaceSecPerKm: 330,
    typicalHardPaceSecPerKm: 270,
    estimatedThresholdPaceSecPerKm: 290,
    runsPerWeek: 4,
    longestLayoffDays: 3,
    weeksActiveInLast8: 8,
    dataWeeks: 8,
    insufficientData: false,
    hasHeartRateZones: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'useManualFitnessInput clears Strava-derived canonical fields after a prior connect',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _testContainer(prefs);
      addTearDown(container.dispose);
      await container.read(onboardingProvider.future);

      final notifier = container.read(onboardingProvider.notifier);
      notifier.setStrava(summary: _buildAthleteSummary());
      await Future<void>.delayed(Duration.zero);

      // Sanity: Strava connect populated canonical + snapshot fields.
      final stravaFitness = container.read(onboardingProvider).value!.fitness;
      expect(stravaFitness.fitnessSource, OnboardingValues.fitnessSourceStrava);
      expect(stravaFitness.experience, isNotNull);
      expect(stravaFitness.athleteSummary, isNotNull);

      notifier.useManualFitnessInput();
      await Future<void>.delayed(Duration.zero);

      final manualFitness = container.read(onboardingProvider).value!.fitness;
      expect(manualFitness.fitnessSource, OnboardingValues.fitnessSourceManual);
      expect(manualFitness.experience, isNull);
      expect(manualFitness.runningDays, isNull);
      expect(manualFitness.weeklyVolume, isNull);
      expect(manualFitness.longestRun, isNull);
      expect(manualFitness.benchmark, isNull);
      expect(manualFitness.athleteSummary, isNull);
      expect(manualFitness.stravaWeeklyVolumeKm, isNull);
    },
  );

  test(
    'useManualFitnessInput preserves genuinely manual answers when no prior Strava connect',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _testContainer(prefs);
      addTearDown(container.dispose);
      await container.read(onboardingProvider.future);

      final notifier = container.read(onboardingProvider.notifier);
      notifier.setFitness(
        experience: RunnerExperience.intermediate.key,
        runningDays: '4',
        weeklyVolume: WeeklyVolumeRange.volume3.key,
        longestRun: LongestRunRange.run3.key,
        canCompleteGoalDist: TernaryChoice.yes.key,
        raceDistanceBefore: RaceDistanceExperience.once.key,
        benchmark: BenchmarkType.fiveK.key,
        benchmarkTime: const Duration(minutes: 26, seconds: 12),
      );
      await Future<void>.delayed(Duration.zero);

      notifier.useManualFitnessInput();
      await Future<void>.delayed(Duration.zero);

      final fitness = container.read(onboardingProvider).value!.fitness;
      expect(fitness.fitnessSource, OnboardingValues.fitnessSourceManual);
      expect(fitness.experience, RunnerExperience.intermediate);
      expect(fitness.runningDays, 4);
      expect(fitness.weeklyVolume, WeeklyVolumeRange.volume3);
      expect(fitness.benchmark, BenchmarkType.fiveK);
    },
  );

  test(
    'clearStravaFitness resets the persisted profile fitness source and drops the athlete summary',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _testContainer(prefs);
      addTearDown(container.dispose);
      await container.read(onboardingProvider.future);
      await container.read(runnerProfileProvider.future);

      // Build a persisted profile whose fitness section came from Strava.
      final baseDraft = buildRunnerProfileDraft();
      final stravaFitness = RunnerProfileDraft.fitnessFromInput(
        experience: RunnerExperience.intermediate.key,
        runningDays: '4',
        weeklyVolume: WeeklyVolumeRange.volume3.key,
        longestRun: LongestRunRange.run3.key,
        canCompleteGoalDist: TernaryChoice.notSure.key,
        raceDistanceBefore: RaceDistanceExperience.never.key,
        benchmark: BenchmarkType.fiveK.key,
        benchmarkTime: const Duration(minutes: 26),
        fitnessSource: OnboardingValues.fitnessSourceStrava,
        athleteSummary: const AthleteSummarySnapshot(
          weeklyVolumeKm: 32.5,
          runsPerWeek: 4,
          dataWeeks: 8,
          insufficientData: false,
          hasHeartRateZones: true,
        ),
      );
      final profile = baseDraft
          .copyWith(fitness: stravaFitness)
          .toRunnerProfile(
            gender: ProfileGender.female,
            dateOfBirth: DateTime(1994, 6, 20),
            completedOnboardingAt: DateTime(2026, 4, 7),
            clock: DateTime(2026, 4, 7),
          )!;
      await container.read(runnerProfileProvider.notifier).setProfile(profile);

      expect(
        container.read(runnerProfileProvider).value!.fitness.fitnessSource,
        OnboardingValues.fitnessSourceStrava,
      );
      expect(
        container.read(runnerProfileProvider).value!.fitness.athleteSummary,
        isNotNull,
      );

      await container
          .read(onboardingProvider.notifier)
          .clearStravaFitness(clock: DateTime(2026, 5, 1));

      final clearedFitness =
          container.read(runnerProfileProvider).value!.fitness;
      expect(clearedFitness.fitnessSource, OnboardingValues.fitnessSourceManual);
      expect(clearedFitness.athleteSummary, isNull);
      // Canonical answers remain so plan generation still has data to work with.
      expect(clearedFitness.experience, RunnerExperience.intermediate);
    },
  );

  test(
    'setGoal persists the onboarding draft while progress is in flight',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _testContainer(prefs);
      addTearDown(container.dispose);
      await container.read(onboardingProvider.future);

      container
          .read(onboardingProvider.notifier)
          .setGoal(
            race: RunnerGoalRace.halfMarathon.key,
            hasRaceDate: true,
            raceDate: DateTime(2026, 10, 18),
            priority: GoalPriority.improveTime.key,
            currentTime: const Duration(hours: 2, minutes: 1, seconds: 30),
            targetTime: const Duration(hours: 1, minutes: 55),
          );

      await Future<void>.delayed(Duration.zero);

      final rawDraft = prefs.getString(
        SharedPreferencesRunnerProfileRepository.draftStorageKey,
      );
      expect(rawDraft, isNotNull);
      expect(
        container.read(onboardingProvider).value?.goal.race,
        RunnerGoalRace.halfMarathon,
      );
    },
  );

  test(
    'markCompleted returns false and leaves onboarding incomplete when profile save fails',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer.test(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
          runnerProfileProvider.overrideWith(
            () => _FailingRunnerProfileNotifier(StateError('save failed')),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(onboardingProvider.future);
      await container.read(runnerProfileProvider.future);

      await container.read(userPreferencesProvider.future);
      await container
          .read(userPreferencesProvider.notifier)
          .setGender(ProfileGender.female);
      await container
          .read(userPreferencesProvider.notifier)
          .setDateOfBirth(DateTime(1994, 6, 20));

      final notifier = container.read(onboardingProvider.notifier);
      notifier.setGoal(
        race: RunnerGoalRace.halfMarathon.key,
        hasRaceDate: true,
        raceDate: DateTime(2026, 10, 18),
        priority: GoalPriority.improveTime.key,
        currentTime: const Duration(hours: 2, minutes: 1, seconds: 30),
        targetTime: const Duration(hours: 1, minutes: 55),
      );
      notifier.setFitness(
        experience: RunnerExperience.intermediate.key,
        runningDays: '4',
        weeklyVolume: WeeklyVolumeRange.volume3.key,
        longestRun: LongestRunRange.run3.key,
        canCompleteGoalDist: TernaryChoice.yes.key,
        raceDistanceBefore: RaceDistanceExperience.once.key,
        benchmark: BenchmarkType.fiveK.key,
        benchmarkTime: const Duration(minutes: 26, seconds: 12),
      );
      notifier.setSchedule(
        trainingDays: '4',
        longRunDay: WeekdayChoice.sunday.key,
        weekdayTime: TimeSlot.min45.key,
        weekendTime: TimeSlot.min90.key,
        hardDays: [WeekdayChoice.tuesday.key, WeekdayChoice.thursday.key],
        preferredTimeOfDay: PreferredTimeOfDay.morning.key,
      );
      notifier.setHealth(
        painLevel: PainLevelChoice.none.key,
        injuryHistory: InjuryHistoryChoice.once.key,
        healthConditions: BinaryChoice.no.key,
      );
      notifier.setTraining(planPreference: PlanPreferenceChoice.balanced.key);
      notifier.setDevice(
        hasWatch: BinaryChoice.yes.key,
        device: WatchDeviceType.garmin.key,
        dataUsage: DataUsagePreference.all.key,
        watchMetrics: WatchMetricsPreference.ifSupported.key,
        metrics: [WatchMetric.heartRate.key, WatchMetric.pace.key],
        hrZones: BinaryChoice.yes.key,
        paceRecs: BinaryChoice.yes.key,
        autoAdjust: AutoAdjustPreference.askFirst.key,
      );

      final saved = await notifier.markCompleted(
        clock: DateTime(2026, 4, 7, 10, 15),
      );

      expect(saved, isFalse);
      expect(prefs.getBool('onboarding_completed'), isNull);
      expect(
        container.read(onboardingProvider).value?.goal.race,
        RunnerGoalRace.halfMarathon,
      );
    },
  );

  test(
    'recreates persisted draft and final profile across provider containers',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _testContainer(prefs);
      addTearDown(container.dispose);
      await container.read(onboardingProvider.future);
      await container.read(runnerProfileProvider.future);

      await container.read(userPreferencesProvider.future);
      await container
          .read(userPreferencesProvider.notifier)
          .setGender(ProfileGender.female);
      await container
          .read(userPreferencesProvider.notifier)
          .setDateOfBirth(DateTime(1994, 6, 20));

      final notifier = container.read(onboardingProvider.notifier);
      notifier.setGoal(
        race: RunnerGoalRace.halfMarathon.key,
        hasRaceDate: true,
        raceDate: DateTime(2026, 10, 18),
        priority: GoalPriority.improveTime.key,
        currentTime: const Duration(hours: 2, minutes: 1, seconds: 30),
        targetTime: const Duration(hours: 1, minutes: 55),
      );
      notifier.setFitness(
        experience: RunnerExperience.intermediate.key,
        runningDays: '4',
        weeklyVolume: WeeklyVolumeRange.volume3.key,
        longestRun: LongestRunRange.run3.key,
        canCompleteGoalDist: TernaryChoice.yes.key,
        raceDistanceBefore: RaceDistanceExperience.once.key,
        benchmark: BenchmarkType.fiveK.key,
        benchmarkTime: const Duration(minutes: 26, seconds: 12),
      );
      notifier.setSchedule(
        trainingDays: '4',
        longRunDay: WeekdayChoice.sunday.key,
        weekdayTime: TimeSlot.min45.key,
        weekendTime: TimeSlot.min90.key,
        hardDays: [WeekdayChoice.tuesday.key, WeekdayChoice.thursday.key],
        preferredTimeOfDay: PreferredTimeOfDay.morning.key,
      );
      notifier.setHealth(
        painLevel: PainLevelChoice.none.key,
        injuryHistory: InjuryHistoryChoice.once.key,
        healthConditions: BinaryChoice.no.key,
      );
      notifier.setTraining(planPreference: PlanPreferenceChoice.balanced.key);
      notifier.setDevice(
        hasWatch: BinaryChoice.yes.key,
        device: WatchDeviceType.garmin.key,
        dataUsage: DataUsagePreference.all.key,
        watchMetrics: WatchMetricsPreference.ifSupported.key,
        metrics: [WatchMetric.heartRate.key, WatchMetric.pace.key],
        hrZones: BinaryChoice.yes.key,
        paceRecs: BinaryChoice.yes.key,
        autoAdjust: AutoAdjustPreference.askFirst.key,
      );
      final saved = await notifier.markCompleted(
        clock: DateTime(2026, 4, 7, 10, 15),
      );
      expect(saved, isTrue);
      await container.read(runnerProfileProvider.future);
      expect(container.read(runnerProfileProvider).value, isNotNull);

      final recreatedContainer = _testContainer(prefs);
      addTearDown(recreatedContainer.dispose);
      await recreatedContainer.read(onboardingProvider.future);
      await recreatedContainer.read(runnerProfileProvider.future);

      final restoredDraft =
          recreatedContainer.read(onboardingProvider).value ??
          const RunnerProfileDraft();
      final restoredProfile = recreatedContainer
          .read(runnerProfileProvider)
          .value;

      expect(restoredDraft.goal.race, RunnerGoalRace.halfMarathon);
      expect(restoredDraft.schedule.trainingDays, 4);
      expect(restoredDraft.device.device, WatchDeviceType.garmin);
      expect(restoredProfile, isNotNull);
      expect(
        restoredProfile!.goal.targetTime,
        const Duration(hours: 1, minutes: 55),
      );
      expect(restoredProfile.gender, ProfileGender.female);
      expect(restoredProfile.dateOfBirth, DateTime(1994, 6, 20));
      expect(
        restoredProfile.completedOnboardingAt,
        DateTime(2026, 4, 7, 10, 15),
      );
      expect(restoredProfile.isOnboardingComplete, isTrue);
      expect(restoredProfile.updatedAt, DateTime(2026, 4, 7, 10, 15));
    },
  );

  test(
    'prefers the persisted final profile over unsaved settings draft edits after recreation',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final profile = buildRunnerProfile(
        gender: ProfileGender.female,
        dateOfBirth: DateTime(1994, 6, 20),
        clock: DateTime(2026, 4, 7, 10, 15),
      );
      final staleDraft = buildRunnerProfileDraft().copyWith(
        trainingPreferences: const TrainingPreferencesProfileDraft(
          planPreference: PlanPreferenceChoice.performance,
        ),
      );

      await prefs.setString(
        SharedPreferencesRunnerProfileRepository.profileStorageKey,
        jsonEncode(profile.toJson()),
      );
      await prefs.setString(
        SharedPreferencesRunnerProfileRepository.draftStorageKey,
        jsonEncode(staleDraft.toJson()),
      );

      final recreatedContainer = _testContainer(prefs);
      addTearDown(recreatedContainer.dispose);
      await recreatedContainer.read(onboardingProvider.future);
      await recreatedContainer.read(runnerProfileProvider.future);

      final restoredDraft =
          recreatedContainer.read(onboardingProvider).value ??
          const RunnerProfileDraft();

      expect(
        restoredDraft.trainingPreferences.planPreference,
        PlanPreferenceChoice.balanced,
      );
      expect(recreatedContainer.read(runnerProfileProvider).value, isNotNull);
      expect(
        recreatedContainer
            .read(runnerProfileProvider)
            .value!
            .trainingPreferences
            .planPreference,
        PlanPreferenceChoice.balanced,
      );
    },
  );

  test(
    'markCompleted seeds a watch connection once and does not clobber an existing wearable',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _testContainer(prefs);
      addTearDown(container.dispose);
      await container.read(onboardingProvider.future);
      await container.read(runnerProfileProvider.future);

      await container.read(userPreferencesProvider.future);
      await container
          .read(userPreferencesProvider.notifier)
          .setGender(ProfileGender.female);
      await container
          .read(userPreferencesProvider.notifier)
          .setDateOfBirth(DateTime(1994, 6, 20));

      final notifier = container.read(onboardingProvider.notifier);
      notifier.setGoal(
        race: RunnerGoalRace.halfMarathon.key,
        hasRaceDate: true,
        raceDate: DateTime(2026, 10, 18),
        priority: GoalPriority.improveTime.key,
        currentTime: const Duration(hours: 2, minutes: 1),
        targetTime: const Duration(hours: 1, minutes: 55),
      );
      notifier.setFitness(
        experience: RunnerExperience.intermediate.key,
        runningDays: '4',
        weeklyVolume: WeeklyVolumeRange.volume3.key,
        longestRun: LongestRunRange.run3.key,
        canCompleteGoalDist: TernaryChoice.yes.key,
        raceDistanceBefore: RaceDistanceExperience.once.key,
        benchmark: BenchmarkType.skip.key,
      );
      notifier.setSchedule(
        trainingDays: '4',
        longRunDay: WeekdayChoice.sunday.key,
        weekdayTime: TimeSlot.min45.key,
        weekendTime: TimeSlot.min90.key,
        hardDays: [WeekdayChoice.tuesday.key],
      );
      notifier.setHealth(
        painLevel: PainLevelChoice.none.key,
        injuryHistory: InjuryHistoryChoice.none.key,
        healthConditions: BinaryChoice.no.key,
      );
      notifier.setTraining(planPreference: PlanPreferenceChoice.balanced.key);
      notifier.setDevice(
        hasWatch: BinaryChoice.yes.key,
        device: WatchDeviceType.garmin.key,
        dataUsage: DataUsagePreference.all.key,
        metrics: [WatchMetric.heartRate.key, WatchMetric.distance.key],
        hrZones: BinaryChoice.yes.key,
        paceRecs: BinaryChoice.yes.key,
      );
      final seeded = await notifier.markCompleted(
        clock: DateTime(2026, 4, 7, 10, 15),
      );
      expect(seeded, isTrue);
      expect(
        container.read(connectedWearableConnectionsProvider).single.vendor,
        IntegrationVendor.garmin,
      );

      notifier.setDevice(
        hasWatch: BinaryChoice.yes.key,
        device: WatchDeviceType.coros.key,
      );
      final reseeded = await notifier.markCompleted(
        clock: DateTime(2026, 4, 8, 8, 0),
      );
      expect(reseeded, isTrue);
      expect(
        container.read(connectedWearableConnectionsProvider).single.vendor,
        IntegrationVendor.garmin,
      );

      await container
          .read(deviceConnectionsProvider.notifier)
          .setPlatformConnection(
            vendor: IntegrationVendor.appleHealth,
            enabled: true,
          );
      await container
          .read(deviceConnectionsProvider.notifier)
          .seedWatchFromDeviceProfileIfAbsent(
            const DeviceProfile(
              hasWatch: BinaryChoice.yes,
              device: WatchDeviceType.coros,
            ),
          );

      final persistedConnections = await container.read(
        deviceConnectionsProvider.future,
      );
      expect(
        persistedConnections
            .where(
              (connection) => connection.kind == DeviceConnectionKind.wearable,
            )
            .single
            .vendor,
        IntegrationVendor.garmin,
      );
      expect(
        prefs.getString(SharedPreferencesDeviceConnectionRepository.storageKey),
        isNotNull,
      );
    },
  );
}
