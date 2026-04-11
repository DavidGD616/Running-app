import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/profile/data/runner_profile_repository.dart';
import 'package:running_app/features/profile/domain/models/runner_profile.dart';
import 'package:running_app/features/profile/presentation/runner_profile_provider.dart';

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
}
