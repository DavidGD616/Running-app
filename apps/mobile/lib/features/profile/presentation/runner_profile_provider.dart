import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/runner_profile_repository.dart';
import '../domain/models/runner_profile.dart';

class RunnerProfileNotifier extends Notifier<RunnerProfile?> {
  RunnerProfileRepository get _repository =>
      ref.read(runnerProfileRepositoryProvider);

  @override
  RunnerProfile? build() {
    final repository = ref.watch(runnerProfileRepositoryProvider);
    unawaited(_hydrateFromRepository());
    return repository.loadProfile();
  }

  Future<void> setProfile(RunnerProfile profile) async {
    state = profile;
    await _repository.saveProfile(profile);
  }

  Future<void> clearProfile() async {
    state = null;
    await _repository.clearProfile();
  }

  Future<void> reloadFromStorage() async {
    await _hydrateFromRepository();
  }

  Future<void> _hydrateFromRepository() async {
    final profile = await _repository.loadProfileAsync();
    if (ref.mounted) {
      state = profile;
    }
  }
}

final runnerProfileProvider =
    NotifierProvider<RunnerProfileNotifier, RunnerProfile?>(
      RunnerProfileNotifier.new,
    );
