import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/features/profile/data/runner_profile_repository.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/strava/domain/athlete_summary.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';

import '../../../helpers/runner_profile_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('runner profile draft JSON round-trips canonical values', () {
    final draft = buildRunnerProfileDraft();

    final restored = RunnerProfileDraft.fromJson(draft.toJson());

    expect(restored.goal.race, RunnerGoalRace.halfMarathon);
    expect(restored.goal.raceDate, DateTime(2026, 10, 18));
    expect(
      restored.acceptedRaceTarget?.primaryTime,
      const Duration(hours: 1, minutes: 55),
    );
    expect(restored.fitness.experience, RunnerExperience.intermediate);
    expect(restored.schedule.hardDays, {
      WeekdayChoice.thursday,
      WeekdayChoice.tuesday,
    });
    expect(restored.device.metrics, {WatchMetric.heartRate, WatchMetric.pace});
  });

  test('runner profile draft schedule planStartDate uses date-only format', () {
    final draft = buildRunnerProfileDraft().copyWith(
      schedule: ScheduleProfileDraft(
        trainingDays: 4,
        longRunDay: WeekdayChoice.sunday,
        weekdayTime: TimeSlot.min45,
        weekendTime: TimeSlot.min90,
        hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
        preferredTimeOfDay: PreferredTimeOfDay.morning,
        planStartDate: DateTime(2026, 6, 7, 8, 30),
      ),
    );

    final json = draft.toJson();
    final scheduleJson = Map<String, dynamic>.from(json['schedule'] as Map);

    expect(scheduleJson['planStartDate'], '2026-06-07');

    final restored = RunnerProfileDraft.fromJson(json);
    expect(restored.schedule.planStartDate, DateTime(2026, 6, 7));
  });

  test('runner profile draft does not parse ISO datetime as planStartDate', () {
    final draft = buildRunnerProfileDraft()
        .copyWith(
          schedule: ScheduleProfileDraft(
            trainingDays: 4,
            longRunDay: WeekdayChoice.sunday,
            weekdayTime: TimeSlot.min45,
            weekendTime: TimeSlot.min90,
            hardDays: {WeekdayChoice.tuesday, WeekdayChoice.thursday},
            preferredTimeOfDay: PreferredTimeOfDay.morning,
            planStartDate: DateTime(2026, 6, 7, 8, 30),
          ),
        )
        .toJson();

    (draft['schedule'] as Map<String, dynamic>)['planStartDate'] =
        '2026-06-07T08:30:00Z';

    final restored = RunnerProfileDraft.fromJson(draft);
    expect(restored.schedule.planStartDate, isNull);
  });

  test('runner profile JSON round-trips persisted metadata', () {
    final profile = buildRunnerProfile(
      gender: ProfileGender.other,
      dateOfBirth: DateTime(1991, 11, 4),
      clock: DateTime(2026, 4, 7, 7, 45),
    ).copyWith(completedOnboardingAt: DateTime(2026, 4, 7, 8));

    final restored = RunnerProfile.fromJson(profile.toJson());

    expect(restored, isNotNull);
    expect(restored!.goal.race, RunnerGoalRace.halfMarathon);
    expect(restored.device.device, WatchDeviceType.garmin);
    expect(restored.strength.lifts, isTrue);
    expect(restored.strength.weeklyFrequency, 2);
    expect(restored.strength.categories, {
      StrengthCategory.lowerBody,
      StrengthCategory.coreMobility,
    });
    expect(restored.gender, ProfileGender.other);
    expect(restored.dateOfBirth, DateTime(1991, 11, 4));
    expect(restored.completedOnboardingAt, DateTime(2026, 4, 7, 8));
    expect(restored.isOnboardingComplete, isTrue);
    expect(restored.schemaVersion, 1);
    expect(restored.updatedAt, DateTime(2026, 4, 7, 7, 45));
  });

  test('runner profile JSON without strength remains backward compatible', () {
    final json = buildRunnerProfile(clock: DateTime(2026, 4, 7, 7, 45)).toJson()
      ..remove('strength');

    final restored = RunnerProfile.fromJson(json);

    expect(restored, isNotNull);
    expect(restored!.strength.lifts, isFalse);
    expect(restored.strength.weeklyFrequency, isNull);
    expect(restored.strength.categories, isEmpty);
    expect(restored.strength.preferredDays, isEmpty);
    expect(restored.strength.sameDayOrder, isNull);
  });

  test(
    'runner profile JSON includes fitnessSource and optional athleteSummary',
    () {
      final stravaDraft = buildRunnerProfileDraft().copyWith(
        fitness: RunnerProfileDraft.fitnessFromInput(
          experience: RunnerExperience.intermediate.key,
          runningDays: '4',
          weeklyVolume: WeeklyVolumeRange.volume4.key,
          longestRun: LongestRunRange.run3.key,
          canCompleteGoalDist: TernaryChoice.yes.key,
          raceDistanceBefore: RaceDistanceExperience.once.key,
          benchmark: BenchmarkType.skip.key,
          fitnessSource: 'strava',
          athleteSummary: const AthleteSummarySnapshot(
            weeklyVolumeKm: 32,
            volumeTrend: VolumeTrend.steady,
            acuteChronicRatio: 1.04,
            longestRecentRunKm: 14,
          ),
          stravaCoachingProfile: _buildStravaCoachingProfile(),
        ),
      );
      final stravaDraftFitness =
          stravaDraft.toJson()['fitness'] as Map<String, dynamic>;
      _expectSanitizedStravaCoachingProfile(
        stravaDraftFitness['stravaCoachingProfile'] as Map,
      );

      final stravaProfile = stravaDraft.toRunnerProfile(
        gender: ProfileGender.female,
        dateOfBirth: DateTime(1993, 5, 12),
        clock: DateTime(2026, 4, 7, 9, 30),
      );

      expect(stravaProfile, isNotNull);
      final stravaFitness =
          stravaProfile!.toJson()['fitness'] as Map<String, dynamic>;
      expect(stravaFitness['fitnessSource'], 'strava');
      expect(stravaFitness.containsKey('athleteSummary'), isTrue);
      final athleteSummary = Map<String, dynamic>.from(
        stravaFitness['athleteSummary'] as Map,
      );
      expect(athleteSummary['weeklyVolumeKm'], 32.0);
      expect(athleteSummary['volumeTrend'], 'steady');
      expect(athleteSummary['acuteChronicRatio'], 1.04);
      expect(athleteSummary['longestRecentRunKm'], 14.0);
      _expectSanitizedStravaCoachingProfile(
        stravaFitness['stravaCoachingProfile'] as Map,
      );
      final restoredProfile = RunnerProfile.fromJson(stravaProfile.toJson());
      expect(restoredProfile?.fitness.stravaCoachingProfile, isNotNull);
      expect(
        restoredProfile!.fitness.stravaCoachingProfile!.provenance.source,
        'strava_sync',
      );
      expect(
        restoredProfile
            .fitness
            .stravaCoachingProfile!
            .trainingBase
            .single
            .metric,
        'training_base_weekly_km',
      );

      final manualFitness =
          buildRunnerProfile(
                clock: DateTime(2026, 4, 7, 8, 0),
              ).toJson()['fitness']
              as Map<String, dynamic>;
      expect(manualFitness.containsKey('fitnessSource'), isTrue);
      expect(manualFitness.containsKey('athleteSummary'), isFalse);
    },
  );

  test('fitness input accepts numeric and legacy 5 plus running days', () {
    FitnessProfile? buildFitness(String runningDays) {
      return RunnerProfileDraft.fitnessFromInput(
        experience: RunnerExperience.intermediate.key,
        runningDays: runningDays,
        weeklyVolume: WeeklyVolumeRange.volume4.key,
        longestRun: LongestRunRange.run4.key,
        canCompleteGoalDist: TernaryChoice.yes.key,
        raceDistanceBefore: RaceDistanceExperience.once.key,
        benchmark: BenchmarkType.skip.key,
      ).toProfileOrNull();
    }

    expect(buildFitness('5')?.runningDays, 5);
    expect(buildFitness('5+')?.runningDays, 5);
  });

  test(
    'repository loads and saves versioned draft/profile storage keys',
    () async {
      final draft = buildRunnerProfileDraft();
      final profile = buildRunnerProfile(clock: DateTime(2026, 4, 7, 8, 0));

      SharedPreferences.setMockInitialValues({
        SharedPreferencesRunnerProfileRepository.draftStorageKey: jsonEncode(
          draft.toJson(),
        ),
        SharedPreferencesRunnerProfileRepository.profileStorageKey: jsonEncode(
          profile.toJson(),
        ),
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesRunnerProfileRepository(prefs);

      final restoredDraft = repository.loadDraft();
      final restoredProfile = repository.loadProfile();

      expect(restoredDraft, isNotNull);
      expect(restoredDraft!.schedule.trainingDays, 4);
      expect(restoredProfile, isNotNull);
      expect(
        restoredProfile!.trainingPreferences.planPreference,
        PlanPreferenceChoice.balanced,
      );
      expect(repository.hasPersistedProfile(), isTrue);

      await repository.saveDraft(
        draft.copyWith(
          trainingPreferences: const TrainingPreferencesProfileDraft(
            planPreference: PlanPreferenceChoice.performance,
          ),
        ),
      );

      final rawDraft = prefs.getString(
        SharedPreferencesRunnerProfileRepository.draftStorageKey,
      );
      final savedDraft = RunnerProfileDraft.fromJson(
        Map<String, dynamic>.from(jsonDecode(rawDraft!) as Map),
      );
      expect(
        savedDraft.trainingPreferences.planPreference,
        PlanPreferenceChoice.performance,
      );
    },
  );

  test('saving a final profile clears any stale draft copy', () async {
    final staleDraft = buildRunnerProfileDraft().copyWith(
      trainingPreferences: const TrainingPreferencesProfileDraft(
        planPreference: PlanPreferenceChoice.performance,
      ),
    );
    final profile = buildRunnerProfile(clock: DateTime(2026, 4, 7, 8, 0));

    SharedPreferences.setMockInitialValues({
      SharedPreferencesRunnerProfileRepository.draftStorageKey: jsonEncode(
        staleDraft.toJson(),
      ),
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = SharedPreferencesRunnerProfileRepository(prefs);

    await repository.saveProfile(profile);

    expect(
      prefs.getString(SharedPreferencesRunnerProfileRepository.draftStorageKey),
      isNull,
    );
    expect(repository.loadDraft(), isNull);
    expect(repository.loadProfile(), isNotNull);
    expect(repository.loadProfile()!.goal.race, RunnerGoalRace.halfMarathon);
  });

  test(
    'clearing the final profile also removes any stale draft copy',
    () async {
      final staleDraft = buildRunnerProfileDraft().copyWith(
        trainingPreferences: const TrainingPreferencesProfileDraft(
          planPreference: PlanPreferenceChoice.performance,
        ),
      );
      final profile = buildRunnerProfile(clock: DateTime(2026, 4, 7, 8, 0));

      SharedPreferences.setMockInitialValues({
        SharedPreferencesRunnerProfileRepository.draftStorageKey: jsonEncode(
          staleDraft.toJson(),
        ),
        SharedPreferencesRunnerProfileRepository.profileStorageKey: jsonEncode(
          profile.toJson(),
        ),
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPreferencesRunnerProfileRepository(prefs);

      await repository.clearProfile();

      expect(
        prefs.getString(
          SharedPreferencesRunnerProfileRepository.draftStorageKey,
        ),
        isNull,
      );
      expect(
        prefs.getString(
          SharedPreferencesRunnerProfileRepository.profileStorageKey,
        ),
        isNull,
      );
      expect(repository.loadDraft(), isNull);
      expect(repository.loadProfile(), isNull);
    },
  );
}

StravaCoachingProfile _buildStravaCoachingProfile() {
  final evidence = StravaEvidencePoint(
    metric: 'training_base_weekly_km',
    date: DateTime.utc(2026, 6, 1),
    value: 32,
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
    endurance: const [],
    speedMarkers: const [],
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

void _expectSanitizedStravaCoachingProfile(Map rawJson) {
  final json = Map<String, dynamic>.from(rawJson);
  final provenance = Map<String, dynamic>.from(json['provenance'] as Map);
  expect(provenance['source'], 'strava_sync');
  expect(json['dataConfidence'], 'high');
  expect(
    (json['trainingBase'] as List).cast<Map>().single['metric'],
    'training_base_weekly_km',
  );
  expect(json['terrain'], 'rolling');

  final guardrail = Map<String, dynamic>.from(
    (json['recoveryGuardrails'] as List).single as Map,
  );
  expect(guardrail['priority'], 1);
  expect(guardrail['category'], 'recovery_spacing');
  expect(guardrail.containsKey('message'), isFalse);

  final focus = Map<String, dynamic>.from(json['planFocus'] as Map);
  expect(focus['category'], 'focus_threshold_durability');
  expect(focus.containsKey('summary'), isFalse);

  final encoded = jsonEncode(json);
  expect(
    encoded.contains('Keep at least one easy day between hard sessions.'),
    isFalse,
  );
  expect(
    encoded.contains('Build consistency and threshold durability.'),
    isFalse,
  );
}
