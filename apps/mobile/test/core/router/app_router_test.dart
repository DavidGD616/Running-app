import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/router/app_router.dart';
import 'package:running_app/core/router/route_names.dart';
import 'package:running_app/features/profile/data/runner_profile_repository.dart';

import '../../helpers/runner_profile_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SharedPreferencesRunnerProfileRepository> createRepository(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesRunnerProfileRepository(prefs);
  }

  test(
    'splash redirect stays on default flow when no persisted profile exists',
    () async {
      final repository = await createRepository({});

      final redirect = resolveSplashRedirect(
        matchedLocation: RouteNames.splash,
        repository: repository,
      );

      expect(redirect, isNull);
    },
  );

  test(
    'splash redirect ignores completion flags and partial draft-only state',
    () async {
      final repository = await createRepository({
        'onboarding_completed': true,
        SharedPreferencesRunnerProfileRepository.draftStorageKey:
            '{"goal":{"race":"race_half_marathon"}}',
      });

      final redirect = resolveSplashRedirect(
        matchedLocation: RouteNames.splash,
        repository: repository,
      );

      expect(redirect, isNull);
    },
  );

  test(
    'splash redirect routes to today when a valid persisted profile exists',
    () async {
      final repository = await createRepository({
        SharedPreferencesRunnerProfileRepository.profileStorageKey:
            '{"invalid":true}',
      });
      await repository.saveProfile(buildRunnerProfile());

      final redirect = resolveSplashRedirect(
        matchedLocation: RouteNames.splash,
        repository: repository,
      );

      expect(redirect, RouteNames.today);
    },
  );
}
