import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/presentation/onboarding_provider.dart';
import '../../user_preferences/presentation/user_preferences_provider.dart';
import '../domain/models/runner_profile.dart';

final runnerProfileProvider = Provider<RunnerProfile?>((ref) {
  final draft = ref.watch(onboardingProvider);
  final preferences = ref.watch(userPreferencesProvider).value;

  return draft.toRunnerProfile(
    gender: preferences?.gender,
    dateOfBirth: preferences?.dateOfBirth,
  );
});
