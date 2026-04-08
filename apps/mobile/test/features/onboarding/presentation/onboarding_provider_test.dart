import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/profile/presentation/runner_profile_provider.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/features/user_preferences/presentation/user_preferences_provider.dart';

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
      notifier.setRecovery(
        sleep: SleepRange.h7To8.key,
        workLevel: WorkLevelChoice.mixed.key,
        stressLevel: StressLevelChoice.moderate.key,
        dayFeeling: DayFeelingChoice.fresh.key,
      );
      notifier.setMotivation(
        motivations: [
          MotivationReason.health.key,
          MotivationReason.improvePerformance.key,
        ],
        barriers: [BarrierReason.time.key, BarrierReason.fatigue.key],
        confidence: 8,
        coachingTone: CoachingToneChoice.encouraging.key,
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
}
