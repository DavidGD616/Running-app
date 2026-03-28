import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/user_preferences.dart';

class UserPreferencesNotifier extends AsyncNotifier<UserPreferences> {
  static const _keyUnit = 'pref_unit_system';
  static const _keyGender = 'pref_gender';
  static const _keyDob = 'pref_dob_ms';

  @override
  Future<UserPreferences> build() async {
    final prefs = await SharedPreferences.getInstance();
    final unitRaw = prefs.getString(_keyUnit);
    final gender = prefs.getString(_keyGender);
    final dobMs = prefs.getInt(_keyDob);

    return UserPreferences(
      unitSystem: unitRaw == 'miles' ? UnitSystem.miles : UnitSystem.km,
      gender: gender,
      dateOfBirth:
          dobMs != null ? DateTime.fromMillisecondsSinceEpoch(dobMs) : null,
    );
  }

  Future<void> setUnitSystem(UnitSystem unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUnit, unit.name);
    state = AsyncData(
      (state.value ?? const UserPreferences()).copyWith(unitSystem: unit),
    );
  }

  Future<void> setGender(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGender, gender);
    state = AsyncData(
      (state.value ?? const UserPreferences()).copyWith(gender: gender),
    );
  }

  Future<void> setDateOfBirth(DateTime dob) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDob, dob.millisecondsSinceEpoch);
    state = AsyncData(
      (state.value ?? const UserPreferences())
          .copyWith(dateOfBirth: dob),
    );
  }
}

final userPreferencesProvider =
    AsyncNotifierProvider<UserPreferencesNotifier, UserPreferences>(
  UserPreferencesNotifier.new,
);
