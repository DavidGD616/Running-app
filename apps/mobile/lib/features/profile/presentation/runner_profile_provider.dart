import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/runner_profile_repository.dart';
import '../domain/models/runner_profile.dart';

class RunnerProfileNotifier extends Notifier<RunnerProfile?> {
  @override
  RunnerProfile? build() {
    return ref.watch(runnerProfileRepositoryProvider).loadProfile();
  }

  Future<void> setProfile(RunnerProfile profile) async {
    state = profile;
    await ref.read(runnerProfileRepositoryProvider).saveProfile(profile);
  }

  Future<void> clearProfile() async {
    state = null;
    await ref.read(runnerProfileRepositoryProvider).clearProfile();
  }

  void reloadFromStorage() {
    state = ref.read(runnerProfileRepositoryProvider).loadProfile();
  }
}

final runnerProfileProvider =
    NotifierProvider<RunnerProfileNotifier, RunnerProfile?>(
      RunnerProfileNotifier.new,
    );
