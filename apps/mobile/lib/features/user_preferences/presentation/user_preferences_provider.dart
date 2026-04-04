import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../training_plan/domain/models/training_plan.dart';
import '../domain/user_preferences.dart';
import '../../training_plan/presentation/training_plan_provider.dart';

class UserPreferencesNotifier extends AsyncNotifier<UserPreferences> {
  static const _keyUnit = 'pref_unit_system';
  static const _keyShortDistanceUnit = 'pref_short_distance_unit';
  static const _keyGender = 'pref_gender';
  static const _keyDob = 'pref_dob_ms';

  @override
  Future<UserPreferences> build() async {
    final prefs = await SharedPreferences.getInstance();
    final unitRaw = prefs.getString(_keyUnit);
    final shortDistanceRaw = prefs.getString(_keyShortDistanceUnit);
    final gender = _parseGender(prefs.getString(_keyGender));
    final dobMs = prefs.getInt(_keyDob);
    final unitSystem = unitRaw == 'miles' ? UnitSystem.miles : UnitSystem.km;
    final shortDistanceUnit = switch (shortDistanceRaw) {
      'feet' => ShortDistanceUnit.feet,
      'meters' => ShortDistanceUnit.meters,
      _ => _defaultShortDistanceUnit(unitSystem),
    };

    return UserPreferences(
      unitSystem: unitSystem,
      shortDistanceUnit: shortDistanceUnit,
      gender: gender,
      dateOfBirth: dobMs != null
          ? DateTime.fromMillisecondsSinceEpoch(dobMs)
          : null,
    );
  }

  Future<void> setUnitSystem(UnitSystem unit) async {
    final prefs = await SharedPreferences.getInstance();
    final shortDistanceUnit = _defaultShortDistanceUnit(unit);
    await prefs.setString(_keyUnit, unit.name);
    await prefs.setString(_keyShortDistanceUnit, shortDistanceUnit.name);
    state = AsyncData(
      (state.value ?? const UserPreferences()).copyWith(
        unitSystem: unit,
        shortDistanceUnit: shortDistanceUnit,
      ),
    );
  }

  Future<void> setShortDistanceUnit(ShortDistanceUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShortDistanceUnit, unit.name);
    state = AsyncData(
      (state.value ?? const UserPreferences()).copyWith(
        shortDistanceUnit: unit,
      ),
    );
  }

  Future<void> setGender(ProfileGender gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGender, gender.name);
    state = AsyncData(
      (state.value ?? const UserPreferences()).copyWith(gender: gender),
    );
  }

  Future<void> setDateOfBirth(DateTime dob) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDob, dob.millisecondsSinceEpoch);
    state = AsyncData(
      (state.value ?? const UserPreferences()).copyWith(dateOfBirth: dob),
    );
  }

  ShortDistanceUnit _defaultShortDistanceUnit(UnitSystem unit) {
    return unit == UnitSystem.miles
        ? ShortDistanceUnit.feet
        : ShortDistanceUnit.meters;
  }

  ProfileGender? _parseGender(String? raw) {
    return switch (raw?.toLowerCase()) {
      'male' || 'hombre' => ProfileGender.male,
      'female' || 'mujer' => ProfileGender.female,
      'other' || 'otro' => ProfileGender.other,
      _ => null,
    };
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
