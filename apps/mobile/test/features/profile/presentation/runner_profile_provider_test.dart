import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/profile/data/runner_profile_repository.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/profile/presentation/runner_profile_provider.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../helpers/runner_profile_fixtures.dart';

class _FailingRunnerProfileRepository implements RunnerProfileRepository {
  @override
  RunnerProfileDraft? loadDraft() => null;

  @override
  RunnerProfile? loadProfile() => null;

  @override
  bool hasPersistedProfile() => false;

  @override
  Future<RunnerProfileDraft?> loadDraftAsync({bool refresh = true}) async {
    return null;
  }

  @override
  Future<RunnerProfile?> loadProfileAsync({bool refresh = true}) async {
    return null;
  }

  @override
  Future<bool> hasPersistedProfileAsync({bool refresh = true}) async {
    return false;
  }

  @override
  Future<void> saveDraft(RunnerProfileDraft draft) async {}

  @override
  Future<void> saveProfile(RunnerProfile profile) async {
    throw StateError('profile save failed');
  }

  @override
  Future<void> clearDraft() async {}

  @override
  Future<void> clearProfile() async {}
}

class _ScriptedRunnerProfileRepository implements RunnerProfileRepository {
  _ScriptedRunnerProfileRepository({
    this.cachedProfile,
    required this.loadProfileAsyncResult,
  });

  final RunnerProfile? cachedProfile;
  final Future<RunnerProfile?> loadProfileAsyncResult;
  int loadProfileAsyncCallCount = 0;

  @override
  RunnerProfileDraft? loadDraft() => null;

  @override
  RunnerProfile? loadProfile() => cachedProfile;

  @override
  bool hasPersistedProfile() => cachedProfile != null;

  @override
  Future<RunnerProfileDraft?> loadDraftAsync({bool refresh = true}) async {
    return null;
  }

  @override
  Future<RunnerProfile?> loadProfileAsync({bool refresh = true}) async {
    loadProfileAsyncCallCount++;
    return loadProfileAsyncResult;
  }

  @override
  Future<bool> hasPersistedProfileAsync({bool refresh = true}) async {
    final refreshedProfile = await loadProfileAsync();
    return refreshedProfile != null;
  }

  @override
  Future<void> saveDraft(RunnerProfileDraft draft) async {}

  @override
  Future<void> saveProfile(RunnerProfile profile) async {}

  @override
  Future<void> clearDraft() async {}

  @override
  Future<void> clearProfile() async {}
}

void main() {
  test('setProfile propagates repository save failures', () async {
    final container = ProviderContainer.test(
      overrides: [
        runnerProfileRepositoryProvider.overrideWithValue(
          _FailingRunnerProfileRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(runnerProfileProvider.future);

    await expectLater(
      container
          .read(runnerProfileProvider.notifier)
          .setProfile(buildRunnerProfile()),
      throwsA(isA<StateError>()),
    );

    expect(container.read(runnerProfileProvider).hasError, isTrue);
  });

  test(
    'returns cached profile immediately and updates after background refresh',
    () async {
      final cachedProfile = buildRunnerProfile(gender: ProfileGender.female);
      final refreshedProfile = buildRunnerProfile(gender: ProfileGender.male);
      final refreshCompleter = Completer<RunnerProfile?>();

      final repository = _ScriptedRunnerProfileRepository(
        cachedProfile: cachedProfile,
        loadProfileAsyncResult: refreshCompleter.future,
      );
      final container = ProviderContainer.test(
        overrides: [
          runnerProfileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final initialProfile = await container.read(runnerProfileProvider.future);

      expect(initialProfile, cachedProfile);
      expect(repository.loadProfileAsyncCallCount, 1);
      expect(container.read(runnerProfileProvider).value, cachedProfile);

      await Future<void>.delayed(Duration.zero);
      expect(container.read(runnerProfileProvider).value, cachedProfile);

      refreshCompleter.complete(refreshedProfile);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(runnerProfileProvider).value, refreshedProfile);
    },
  );

  test(
    'returns null on no-cache timeout and applies the late refresh',
    () async {
      final refreshCompleter = Completer<RunnerProfile?>();
      final refreshedProfile = buildRunnerProfile(gender: ProfileGender.male);
      final repository = _ScriptedRunnerProfileRepository(
        loadProfileAsyncResult: refreshCompleter.future,
      );
      final container = ProviderContainer.test(
        overrides: [
          runnerProfileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final loaded = await container.read(runnerProfileProvider.future);

      expect(loaded, isNull);
      expect(container.read(runnerProfileProvider).value, isNull);

      refreshCompleter.complete(refreshedProfile);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(runnerProfileProvider).value, refreshedProfile);
    },
  );

  test('ignores stale background refresh after repository changes', () async {
    final staleProfile = buildRunnerProfile(gender: ProfileGender.female);
    final staleRefreshCompleter = Completer<RunnerProfile?>();
    final staleRepository = _ScriptedRunnerProfileRepository(
      cachedProfile: staleProfile,
      loadProfileAsyncResult: staleRefreshCompleter.future,
    );
    final currentRepository = _ScriptedRunnerProfileRepository(
      loadProfileAsyncResult: Future<RunnerProfile?>.value(),
    );
    var activeRepository = staleRepository;
    final activeRepositoryProvider = Provider<RunnerProfileRepository>(
      (_) => activeRepository,
    );

    final container = ProviderContainer.test(
      overrides: [
        runnerProfileRepositoryProvider.overrideWith(
          (ref) => ref.watch(activeRepositoryProvider),
        ),
      ],
    );
    addTearDown(container.dispose);

    final initialProfile = await container.read(runnerProfileProvider.future);
    expect(initialProfile, staleProfile);

    activeRepository = currentRepository;
    container.invalidate(activeRepositoryProvider);
    await container.pump();

    final currentProfile = await container.read(runnerProfileProvider.future);
    expect(currentProfile, isNull);

    staleRefreshCompleter.complete(staleProfile);
    await container.pump();

    expect(container.read(runnerProfileProvider).value, isNull);
  });
}
