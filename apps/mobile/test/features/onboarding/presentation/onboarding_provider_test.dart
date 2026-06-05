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

StravaCoachingProfile _buildStravaCoachingProfile() {
  final evidence = StravaEvidencePoint(
    metric: 'training_base_weekly_km',
    date: DateTime.utc(2026, 6, 1),
    value: 32.5,
    unit: 'km_per_week',
  );

  return StravaCoachingProfile(
    provenance: StravaAnalysisProvenance(
      source: 'strava_sync',
      syncedAt: DateTime.utc(2026, 6, 2, 8),
      dataWindow: 'last12Weeks',
      dataFromDate: DateTime.utc(2026, 3, 10),
      dataThroughDate: DateTime.utc(2026, 6, 2),
      activityCount: 34,
      runActivityCount: 32,
      confidence: StravaDataConfidence.high,
    ),
    dataConfidence: StravaDataConfidence.high,
    trainingBase: [evidence],
    endurance: [
      StravaEvidencePoint(
        metric: 'endurance_long_run_km',
        date: DateTime.utc(2026, 5, 31),
        value: 14.2,
        unit: 'km',
      ),
    ],
    speedMarkers: [
      StravaEvidencePoint(
        metric: 'speed_marker_threshold_pace',
        date: DateTime.utc(2026, 5, 30),
        value: 290,
        unit: 'sec_per_km',
      ),
    ],
    paceZones: const StravaPaceZones(
      recovery: StravaPaceZone(paceMinSecPerKm: 395, paceMaxSecPerKm: 445),
      easy: StravaPaceZone(paceMinSecPerKm: 350, paceMaxSecPerKm: 395),
      longRun: StravaPaceZone(paceMinSecPerKm: 345, paceMaxSecPerKm: 380),
      steady: StravaPaceZone(paceMinSecPerKm: 325, paceMaxSecPerKm: 345),
      tempo: StravaPaceZone(paceMinSecPerKm: 300, paceMaxSecPerKm: 325),
      threshold: StravaPaceZone(paceMinSecPerKm: 285, paceMaxSecPerKm: 300),
      racePace: StravaPaceZone(paceMinSecPerKm: 280, paceMaxSecPerKm: 295),
      intervals: StravaPaceZone(paceMinSecPerKm: 255, paceMaxSecPerKm: 280),
      strides: StravaPaceZone(paceMinSecPerKm: 220, paceMaxSecPerKm: 255),
    ),
    terrain: StravaTerrainProfile.rolling,
    recoveryGuardrails: const [
      StravaGuardrail(
        priority: 1,
        category: 'recovery_spacing',
        message: 'Keep at least one easy day between hard sessions.',
      ),
    ],
    raceTargets: [
      StravaRaceTargetEstimate(
        distanceKm: 21.097,
        primaryTime: const Duration(hours: 1, minutes: 55),
        confidence: StravaDataConfidence.high,
        evidence: [evidence],
      ),
    ],
    planFocus: const StravaPlanFocus(
      category: 'focus_threshold_durability',
      summary: 'Build consistency and threshold durability.',
    ),
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
      notifier.setStravaCoachingProfile(
        summary: _buildAthleteSummary(),
        coachingProfile: _buildStravaCoachingProfile(),
      );
      await Future<void>.delayed(Duration.zero);

      // Sanity: Strava connect populated canonical + snapshot fields.
      final stravaFitness = container.read(onboardingProvider).value!.fitness;
      expect(stravaFitness.fitnessSource, OnboardingValues.fitnessSourceStrava);
      expect(stravaFitness.experience, isNotNull);
      expect(stravaFitness.athleteSummary, isNotNull);
      expect(stravaFitness.stravaCoachingProfile, isNotNull);

      notifier.setFitnessSource(OnboardingValues.fitnessSourceManual);
      await Future<void>.delayed(Duration.zero);

      final manualFitness = container.read(onboardingProvider).value!.fitness;
      expect(manualFitness.fitnessSource, OnboardingValues.fitnessSourceManual);
      expect(manualFitness.experience, isNull);
      expect(manualFitness.runningDays, isNull);
      expect(manualFitness.weeklyVolume, isNull);
      expect(manualFitness.longestRun, isNull);
      expect(manualFitness.benchmark, isNull);
      expect(manualFitness.athleteSummary, isNull);
      expect(manualFitness.stravaCoachingProfile, isNull);
      expect(manualFitness.stravaWeeklyVolumeKm, isNull);
    },
  );

  test(
    'setStrength stores no-lifting canonical value without lift fields',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _testContainer(prefs);
      addTearDown(container.dispose);
      await container.read(onboardingProvider.future);

      container.read(onboardingProvider.notifier).setStrength(lifts: false);
      await Future<void>.delayed(Duration.zero);

      final strength = container.read(onboardingProvider).value!.strength;
      expect(strength.lifts, isFalse);
      expect(strength.weeklyFrequency, isNull);
      expect(strength.categories, isEmpty);
      expect(strength.preferredDays, isEmpty);
      expect(strength.sameDayOrder, isNull);
    },
  );

  test('setStrength stores lifting canonical values', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = _testContainer(prefs);
    addTearDown(container.dispose);
    await container.read(onboardingProvider.future);

    container
        .read(onboardingProvider.notifier)
        .setStrength(
          lifts: true,
          weeklyFrequency: '2',
          categories: [
            StrengthCategory.lowerBody.key,
            StrengthCategory.coreMobility.key,
          ],
          preferredDays: [WeekdayChoice.monday.key, WeekdayChoice.thursday.key],
          sameDayOrder: SameDayOrderPreference.runFirst.key,
        );
    await Future<void>.delayed(Duration.zero);

    final strength = container.read(onboardingProvider).value!.strength;
    expect(strength.lifts, isTrue);
    expect(strength.weeklyFrequency, 2);
    expect(strength.categories, {
      StrengthCategory.lowerBody,
      StrengthCategory.coreMobility,
    });
    expect(strength.preferredDays, {
      WeekdayChoice.monday,
      WeekdayChoice.thursday,
    });
    expect(strength.sameDayOrder, SameDayOrderPreference.runFirst);
  });

  test(
    'setSchedule stores an explicit date for plan start when provided',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _testContainer(prefs);
      addTearDown(container.dispose);
      await container.read(onboardingProvider.future);

      final notifier = container.read(onboardingProvider.notifier);
      notifier.setSchedule(
        trainingDays: '4',
        longRunDay: WeekdayChoice.sunday.key,
        weekdayTime: TimeSlot.min45.key,
        weekendTime: TimeSlot.min90.key,
        hardDays: [WeekdayChoice.tuesday.key],
        planStartDate: DateTime(2026, 6, 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(onboardingProvider).value?.schedule.planStartDate,
        DateTime(2026, 6, 1),
      );
    },
  );

  test(
    'setSchedule retains a previously saved plan start date when no new date is passed',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _testContainer(prefs);
      addTearDown(container.dispose);
      await container.read(onboardingProvider.future);

      final notifier = container.read(onboardingProvider.notifier);
      notifier.setSchedule(
        trainingDays: '4',
        longRunDay: WeekdayChoice.sunday.key,
        weekdayTime: TimeSlot.min45.key,
        weekendTime: TimeSlot.min90.key,
        hardDays: [WeekdayChoice.tuesday.key],
        planStartDate: DateTime(2026, 5, 31),
      );
      notifier.setSchedule(
        trainingDays: '5',
        longRunDay: WeekdayChoice.wednesday.key,
        weekdayTime: TimeSlot.min60.key,
        weekendTime: TimeSlot.min90.key,
        hardDays: [WeekdayChoice.thursday.key],
      );
      await Future<void>.delayed(Duration.zero);

      final restored = container.read(onboardingProvider).value!;
      expect(restored.schedule.trainingDays, 5);
      expect(restored.schedule.planStartDate, DateTime(2026, 5, 31));
    },
  );

  test(
    'setting Strava coaching profile stores canonical source and curated profile only',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _testContainer(prefs);
      addTearDown(container.dispose);
      await container.read(onboardingProvider.future);

      final notifier = container.read(onboardingProvider.notifier);
      notifier.setStravaCoachingProfile(
        summary: _buildAthleteSummary(),
        coachingProfile: _buildStravaCoachingProfile(),
      );
      await Future<void>.delayed(Duration.zero);

      final fitness = container.read(onboardingProvider).value!.fitness;
      expect(fitness.fitnessSource, OnboardingValues.fitnessSourceStrava);
      expect(fitness.stravaCoachingProfile, isNotNull);
      expect(fitness.stravaCoachingProfile!.provenance.source, 'strava_sync');
      expect(fitness.athleteSummary, isNotNull);

      final rawDraft = prefs.getString(
        SharedPreferencesRunnerProfileRepository.draftStorageKey,
      );
      expect(rawDraft, isNotNull);
      final draftJson = jsonDecode(rawDraft!) as Map<String, dynamic>;
      final fitnessJson = draftJson['fitness'] as Map<String, dynamic>;
      expect(
        fitnessJson['fitnessSource'],
        OnboardingValues.fitnessSourceStrava,
      );
      expect(fitnessJson['stravaCoachingProfile'], isA<Map>());
      final coachingJson = Map<String, dynamic>.from(
        fitnessJson['stravaCoachingProfile'] as Map,
      );
      final provenanceJson = Map<String, dynamic>.from(
        coachingJson['provenance'] as Map,
      );
      expect(provenanceJson['source'], 'strava_sync');
      expect(coachingJson['dataConfidence'], 'high');
      expect(
        (coachingJson['trainingBase'] as List).cast<Map>().single['metric'],
        'training_base_weekly_km',
      );
      final guardrailJson = Map<String, dynamic>.from(
        (coachingJson['recoveryGuardrails'] as List).single as Map,
      );
      expect(guardrailJson['priority'], 1);
      expect(guardrailJson['category'], 'recovery_spacing');
      expect(guardrailJson.containsKey('message'), isFalse);
      final planFocusJson = Map<String, dynamic>.from(
        coachingJson['planFocus'] as Map,
      );
      expect(planFocusJson['category'], 'focus_threshold_durability');
      expect(planFocusJson.containsKey('summary'), isFalse);
      expect(fitnessJson.containsKey('activities'), isFalse);
      expect(rawDraft.contains('Morning Run'), isFalse);
      expect(
        rawDraft.contains('Keep at least one easy day between hard sessions.'),
        isFalse,
      );
      expect(
        rawDraft.contains('Build consistency and threshold durability.'),
        isFalse,
      );

      final restoredDraft = RunnerProfileDraft.fromJson(draftJson);
      expect(restoredDraft.fitness.stravaCoachingProfile, isNotNull);
      expect(
        restoredDraft.fitness.stravaCoachingProfile!.provenance.source,
        'strava_sync',
      );
      expect(
        restoredDraft.fitness.stravaCoachingProfile!.trainingBase.single.metric,
        'training_base_weekly_km',
      );
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
        FitnessSource.strava,
      );
      expect(
        container.read(runnerProfileProvider).value!.fitness.athleteSummary,
        isNotNull,
      );

      await container
          .read(onboardingProvider.notifier)
          .clearStravaFitness(clock: DateTime(2026, 5, 1));

      final clearedFitness = container
          .read(runnerProfileProvider)
          .value!
          .fitness;
      expect(clearedFitness.fitnessSource, FitnessSource.manual);
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
      notifier.setStrength(lifts: false);
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
      notifier.setStrength(lifts: false);
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
      notifier.setStrength(lifts: false);
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
