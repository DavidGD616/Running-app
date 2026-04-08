import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/presentation/onboarding_provider.dart';
import '../../profile/domain/models/runner_profile.dart';
import '../../profile/presentation/runner_profile_provider.dart';
import '../domain/models/goal.dart';
import 'goal_mapper.dart';

Goal? goalFromRunnerProfile(RunnerProfile? profile) =>
    goalFromRunnerProfileOrNull(profile);

Goal? goalFromDraft(RunnerProfileDraft draft) => goalFromDraftOrNull(draft);

final activeGoalProvider = Provider<Goal?>((ref) {
  final profile = ref.watch(runnerProfileProvider);
  return goalFromRunnerProfile(profile);
});

final onboardingGoalProvider = Provider<Goal?>((ref) {
  final draft = ref.watch(onboardingProvider);
  return goalFromDraft(draft);
});
