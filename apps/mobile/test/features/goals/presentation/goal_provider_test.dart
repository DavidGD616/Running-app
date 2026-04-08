import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_app/features/goals/domain/models/goal.dart';
import 'package:running_app/features/goals/presentation/goal_provider.dart';
import 'package:running_app/features/onboarding/presentation/onboarding_provider.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/profile/presentation/runner_profile_provider.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';

import '../../../helpers/runner_profile_fixtures.dart';

class _TestOnboardingNotifier extends OnboardingNotifier {
  _TestOnboardingNotifier(this.value);

  final RunnerProfileDraft value;

  @override
  RunnerProfileDraft build() => value;
}

class _TestRunnerProfileNotifier extends RunnerProfileNotifier {
  _TestRunnerProfileNotifier(this.value);

  final RunnerProfile? value;

  @override
  RunnerProfile? build() => value;
}

void main() {
  test('goalFromRunnerProfile maps persisted profile into an active goal', () {
    final profile = buildRunnerProfileDraft()
        .copyWith(
          goal: GoalProfileDraft(
            race: RunnerGoalRace.marathon,
            hasRaceDate: false,
            priority: GoalPriority.justFinish,
          ),
        )
        .toRunnerProfile(
          gender: ProfileGender.female,
          dateOfBirth: DateTime(1994, 6, 20),
          clock: DateTime(2026, 4, 7, 10, 15),
        )!;

    final goal = goalFromRunnerProfile(profile);

    expect(goal, isA<RaceGoal>());
    final raceGoal = goal! as RaceGoal;
    expect(raceGoal.kind, GoalKind.race);
    expect(raceGoal.status, GoalStatus.active);
    expect(raceGoal.priority, GoalPriorityType.justFinish);
    expect(raceGoal.raceEvent, isNotNull);
    expect(raceGoal.raceEvent!.raceType, GoalRaceType.marathon);
    expect(raceGoal.raceEvent!.eventDate, isNull);
  });

  test(
    'goalFromDraft returns null until required draft fields are present',
    () {
      final incompleteDraft = const RunnerProfileDraft(
        goal: GoalProfileDraft(
          race: RunnerGoalRace.halfMarathon,
          hasRaceDate: true,
          priority: GoalPriority.improveTime,
        ),
      );

      expect(goalFromDraft(incompleteDraft), isNull);
    },
  );

  test('goal providers map draft and profile sources independently', () {
    final draft = buildRunnerProfileDraft().copyWith(
      goal: GoalProfileDraft(
        race: RunnerGoalRace.fiveK,
        hasRaceDate: true,
        raceDate: DateTime(2026, 5, 1),
        priority: GoalPriority.justFinish,
      ),
    );
    final profile = buildRunnerProfileDraft()
        .copyWith(
          goal: GoalProfileDraft(
            race: RunnerGoalRace.halfMarathon,
            hasRaceDate: true,
            raceDate: DateTime(2026, 10, 18),
            priority: GoalPriority.improveTime,
            currentTime: const Duration(hours: 2, minutes: 1, seconds: 30),
            targetTime: const Duration(hours: 1, minutes: 55),
          ),
        )
        .toRunnerProfile(
          gender: ProfileGender.female,
          dateOfBirth: DateTime(1994, 6, 20),
          clock: DateTime(2026, 4, 7, 10, 15),
        )!;

    final container = ProviderContainer.test(
      overrides: [
        onboardingProvider.overrideWith(() => _TestOnboardingNotifier(draft)),
        runnerProfileProvider.overrideWith(
          () => _TestRunnerProfileNotifier(profile),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(onboardingGoalProvider), isA<RaceGoal>());
    expect(
      container.read(onboardingGoalProvider)!.priority,
      GoalPriorityType.justFinish,
    );
    expect(container.read(activeGoalProvider), isA<TimeGoal>());
    expect(container.read(activeGoalProvider)!.kind, GoalKind.time);
    expect(
      container.read(activeGoalProvider)!.targetRace,
      GoalRaceType.halfMarathon,
    );
  });
}
