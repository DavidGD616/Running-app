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
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/profile/presentation/runner_profile_provider.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/features/user_preferences/presentation/user_preferences_provider.dart';

import '../../../helpers/runner_profile_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'recreates persisted draft and final profile across provider containers',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

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
      expect(container.read(runnerProfileProvider), isNotNull);

      final recreatedContainer = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(recreatedContainer.dispose);

      final restoredDraft = recreatedContainer.read(onboardingProvider);
      final restoredProfile = recreatedContainer.read(runnerProfileProvider);

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

      final recreatedContainer = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(recreatedContainer.dispose);

      final restoredDraft = recreatedContainer.read(onboardingProvider);

      expect(
        restoredDraft.trainingPreferences.planPreference,
        PlanPreferenceChoice.balanced,
      );
      expect(recreatedContainer.read(runnerProfileProvider), isNotNull);
      expect(
        recreatedContainer
            .read(runnerProfileProvider)!
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
      final container = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

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

      final persistedConnections = container.read(deviceConnectionsProvider);
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
