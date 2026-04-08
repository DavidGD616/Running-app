import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/features/profile/data/runner_profile_repository.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
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
    expect(restored.goal.priority, GoalPriority.improveTime);
    expect(restored.goal.raceDate, DateTime(2026, 10, 18));
    expect(restored.fitness.experience, RunnerExperience.intermediate);
    expect(restored.schedule.hardDays, {
      WeekdayChoice.thursday,
      WeekdayChoice.tuesday,
    });
    expect(restored.device.metrics, {WatchMetric.heartRate, WatchMetric.pace});
    expect(restored.motivation.coachingTone, CoachingToneChoice.encouraging);
  });

  test('runner profile JSON round-trips persisted metadata', () {
    final profile = buildRunnerProfile(
      gender: ProfileGender.other,
      dateOfBirth: DateTime(1991, 11, 4),
      clock: DateTime(2026, 4, 7, 7, 45),
    );

    final restored = RunnerProfile.fromJson(profile.toJson());

    expect(restored, isNotNull);
    expect(restored!.goal.priority, GoalPriority.improveTime);
    expect(restored.device.device, WatchDeviceType.garmin);
    expect(restored.gender, ProfileGender.other);
    expect(restored.dateOfBirth, DateTime(1991, 11, 4));
    expect(restored.schemaVersion, 1);
    expect(restored.updatedAt, DateTime(2026, 4, 7, 7, 45));
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
      expect(restoredProfile!.motivation.confidence, 8);
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
