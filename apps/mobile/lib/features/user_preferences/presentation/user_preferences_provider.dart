import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../training_plan/domain/models/training_plan.dart';
import '../data/supabase_user_preferences_repository.dart';
import '../domain/user_preferences.dart';
import '../../training_plan/presentation/training_plan_provider.dart';

class UserPreferencesNotifier extends AsyncNotifier<UserPreferences> {
  @override
  Future<UserPreferences> build() async {
    return ref.watch(userPreferencesRepositoryProvider).load();
  }

  Future<void> setUnitSystem(UnitSystem unit) async {
    final shortDistanceUnit = _defaultShortDistanceUnit(unit);
    await _persist(
      (state.value ?? const UserPreferences()).copyWith(
        unitSystem: unit,
        shortDistanceUnit: shortDistanceUnit,
      ),
    );
  }

  Future<void> setShortDistanceUnit(ShortDistanceUnit unit) async {
    await _persist(
      (state.value ?? const UserPreferences()).copyWith(shortDistanceUnit: unit),
    );
  }

  Future<void> setDisplayName(String name) async {
    await _persist(
      (state.value ?? const UserPreferences()).copyWith(displayName: name),
    );
  }

  Future<void> setGender(ProfileGender gender) async {
    await _persist(
      (state.value ?? const UserPreferences()).copyWith(gender: gender),
    );
  }

  Future<void> setDateOfBirth(DateTime dob) async {
    await _persist(
      (state.value ?? const UserPreferences()).copyWith(dateOfBirth: dob),
    );
  }

  ShortDistanceUnit _defaultShortDistanceUnit(UnitSystem unit) {
    return unit == UnitSystem.miles
        ? ShortDistanceUnit.feet
        : ShortDistanceUnit.meters;
  }

  Future<void> _persist(UserPreferences next) async {
    state = AsyncData(next);
    await ref.read(userPreferencesRepositoryProvider).save(next);
  }
}

final userPreferencesProvider =
    AsyncNotifierProvider<UserPreferencesNotifier, UserPreferences>(
      UserPreferencesNotifier.new,
    );

// ── User profile display ───────────────────────────────────────────────────────

/// Display-ready plan metadata for the profile card and home header.
/// In a future sprint this will derive name from auth state and plan info
/// from [trainingPlanProvider].
class UserProfileDisplay {
  const UserProfileDisplay({
    required this.raceType,
    required this.currentWeekNumber,
    required this.totalWeeks,
  });

  final TrainingPlanRaceType raceType;
  final int currentWeekNumber;
  final int totalWeeks;
}

final userProfileDisplayProvider = Provider<UserProfileDisplay>((ref) {
  final plan = ref.watch(trainingPlanProvider);
  return UserProfileDisplay(
    raceType: plan.raceType,
    currentWeekNumber: plan.currentWeekNumber,
    totalWeeks: plan.totalWeeks,
  );
});
