import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/runner_profile_repository.dart';
import '../domain/models/runner_profile.dart';

class RunnerProfileNotifier extends AsyncNotifier<RunnerProfile?> {
  RunnerProfileRepository get _repository =>
      ref.read(runnerProfileRepositoryProvider);

  @override
  Future<RunnerProfile?> build() async {
    return ref.watch(runnerProfileRepositoryProvider).loadProfileAsync();
  }

  Future<void> setProfile(RunnerProfile profile) async {
    state = const AsyncLoading();
    try {
      await _repository.saveProfile(profile);
      state = AsyncData(profile);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> clearProfile() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.clearProfile();
      return null;
    });
  }

  Future<void> reloadFromStorage() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.loadProfileAsync);
  }
}

final runnerProfileProvider =
    AsyncNotifierProvider<RunnerProfileNotifier, RunnerProfile?>(
      RunnerProfileNotifier.new,
    );
