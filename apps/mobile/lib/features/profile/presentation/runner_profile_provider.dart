import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/runner_profile_repository.dart';
import '../domain/models/runner_profile.dart';

const _runnerProfileLoadTimeout = Duration(seconds: 2);

class RunnerProfileNotifier extends AsyncNotifier<RunnerProfile?> {
  int _loadGeneration = 0;

  RunnerProfileRepository get _repository =>
      ref.read(runnerProfileRepositoryProvider);

  @override
  Future<RunnerProfile?> build() async {
    final generation = ++_loadGeneration;
    final repository = ref.watch(runnerProfileRepositoryProvider);
    final cachedProfile = repository.loadProfile();
    if (cachedProfile != null) {
      Future.microtask(
        () =>
            _reloadProfileFromRepository(repository, cachedProfile, generation),
      );
      return cachedProfile;
    }

    return _loadProfileWithTimeout(repository, generation);
  }

  Future<void> setProfile(RunnerProfile profile) async {
    final generation = ++_loadGeneration;
    state = const AsyncLoading();
    try {
      await _repository.saveProfile(profile);
      if (!_isCurrentGeneration(generation)) return;
      state = AsyncData(profile);
    } catch (error, stackTrace) {
      if (!_isCurrentGeneration(generation)) return;
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> clearProfile() async {
    ++_loadGeneration;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.clearProfile();
      return null;
    });
  }

  Future<void> reloadFromStorage() async {
    final generation = ++_loadGeneration;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _loadProfileWithTimeout(_repository, generation),
    );
  }

  Future<void> _reloadProfileFromRepository(
    RunnerProfileRepository repository,
    RunnerProfile cachedProfile,
    int generation,
  ) async {
    try {
      final refreshed = await repository.loadProfileAsync();
      if (!_isCurrentGeneration(generation)) return;
      state = AsyncData(refreshed);
    } catch (_) {
      if (!_isCurrentGeneration(generation)) return;
      state = AsyncData(cachedProfile);
    }
  }

  Future<RunnerProfile?> _loadProfileWithTimeout(
    RunnerProfileRepository repository,
    int generation,
  ) {
    final loadFuture = repository.loadProfileAsync();
    return loadFuture.timeout(
      _runnerProfileLoadTimeout,
      onTimeout: () {
        unawaited(_applyProfileWhenReady(loadFuture, generation));
        return repository.loadProfile();
      },
    );
  }

  Future<void> _applyProfileWhenReady(
    Future<RunnerProfile?> loadFuture,
    int generation,
  ) async {
    try {
      final profile = await loadFuture;
      if (!_isCurrentGeneration(generation)) return;
      state = AsyncData(profile);
    } catch (error, stackTrace) {
      if (!_isCurrentGeneration(generation)) return;
      state = AsyncError(error, stackTrace);
    }
  }

  bool _isCurrentGeneration(int generation) {
    return ref.mounted && generation == _loadGeneration;
  }
}

final runnerProfileProvider =
    AsyncNotifierProvider<RunnerProfileNotifier, RunnerProfile?>(
      RunnerProfileNotifier.new,
    );
