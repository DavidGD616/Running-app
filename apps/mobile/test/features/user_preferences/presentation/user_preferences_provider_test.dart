import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:running_app/core/persistence/shared_preferences_provider.dart';
import 'package:running_app/features/user_preferences/data/supabase_user_preferences_repository.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/features/user_preferences/presentation/user_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'saveAccountSetup persists the full account setup payload once',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer.test(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userPreferencesRepositoryProvider.overrideWithValue(
            SharedPreferencesUserPreferencesRepository(prefs),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(userPreferencesProvider.future);

      await container
          .read(userPreferencesProvider.notifier)
          .saveAccountSetup(
            unitSystem: UnitSystem.miles,
            shortDistanceUnit: ShortDistanceUnit.feet,
            gender: ProfileGender.female,
            dateOfBirth: DateTime(1994, 6, 20),
            displayName: ' Runner Name ',
          );

      final restored = await container
          .read(userPreferencesRepositoryProvider)
          .load();
      expect(restored.unitSystem, UnitSystem.miles);
      expect(restored.shortDistanceUnit, ShortDistanceUnit.feet);
      expect(restored.gender, ProfileGender.female);
      expect(restored.dateOfBirth, DateTime(1994, 6, 20));
      expect(restored.displayName, 'Runner Name');
    },
  );
}
