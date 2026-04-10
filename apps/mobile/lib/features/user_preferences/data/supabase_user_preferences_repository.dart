import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/user_preferences.dart';

abstract interface class UserPreferencesRepository {
  Future<UserPreferences> load();
  Future<void> save(UserPreferences preferences);
}

class SharedPreferencesUserPreferencesRepository
    implements UserPreferencesRepository {
  SharedPreferencesUserPreferencesRepository(this._prefs);

  static const _keyUnit = 'pref_unit_system';
  static const _keyShortDistanceUnit = 'pref_short_distance_unit';
  static const _keyDisplayName = 'pref_display_name';
  static const _keyGender = 'pref_gender';
  static const _keyDob = 'pref_dob_ms';

  final SharedPreferences _prefs;

  @override
  Future<UserPreferences> load() async {
    final unitSystem = _parseUnitSystem(_prefs.getString(_keyUnit));
    return UserPreferences(
      unitSystem: unitSystem,
      shortDistanceUnit: _parseShortDistanceUnit(
        raw: _prefs.getString(_keyShortDistanceUnit),
        unitSystem: unitSystem,
      ),
      displayName: _prefs.getString(_keyDisplayName),
      gender: _parseGender(_prefs.getString(_keyGender)),
      dateOfBirth: _dateOfBirthFromMillis(_prefs.getInt(_keyDob)),
    );
  }

  @override
  Future<void> save(UserPreferences preferences) async {
    await _prefs.setString(_keyUnit, preferences.unitSystem.name);
    await _prefs.setString(
      _keyShortDistanceUnit,
      preferences.shortDistanceUnit.name,
    );
    await _setNullableString(_keyDisplayName, preferences.displayName);
    await _setNullableString(_keyGender, preferences.gender?.name);

    final dateOfBirthMs = preferences.dateOfBirth?.millisecondsSinceEpoch;
    if (dateOfBirthMs == null) {
      await _prefs.remove(_keyDob);
    } else {
      await _prefs.setInt(_keyDob, dateOfBirthMs);
    }
  }

  Future<void> _setNullableString(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    await _prefs.setString(key, value);
  }
}

class SupabaseUserPreferencesRepository implements UserPreferencesRepository {
  SupabaseUserPreferencesRepository(
    this._client, {
    UserPreferencesRepository? localCache,
  }) : _localCache = localCache;

  final SupabaseClient _client;
  final UserPreferencesRepository? _localCache;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Future<UserPreferences> load() async {
    final uid = _uid;
    if (uid == null) return _loadCachedPreferences();

    try {
      final response = await _client
          .from('user_preferences')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (response == null) {
        return const UserPreferences();
      }

      final row = _rowFromDynamic(response);
      final unitSystem = _parseUnitSystem(row['unit_system'] as String?);
      final preferences = UserPreferences(
        unitSystem: unitSystem,
        shortDistanceUnit: _parseShortDistanceUnit(
          raw: row['short_distance_unit'] as String?,
          unitSystem: unitSystem,
        ),
        displayName: row['display_name'] as String?,
        gender: _parseGender(row['gender'] as String?),
        dateOfBirth: _dateOfBirthFromMillis(row['date_of_birth_ms']),
      );
      await _localCache?.save(preferences);
      return preferences;
    } catch (_) {
      return _loadCachedPreferences(rethrowIfUnavailable: true);
    }
  }

  @override
  Future<void> save(UserPreferences preferences) async {
    await _localCache?.save(preferences);

    final uid = _uid;
    if (uid == null) {
      if (_localCache != null) return;
      throw const PostgrestException(message: 'No authenticated user');
    }

    await _client.from('user_preferences').upsert({
      'user_id': uid,
      'unit_system': preferences.unitSystem.name,
      'short_distance_unit': preferences.shortDistanceUnit.name,
      'display_name': preferences.displayName,
      'gender': preferences.gender?.name,
      'date_of_birth_ms': preferences.dateOfBirth?.millisecondsSinceEpoch,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<UserPreferences> _loadCachedPreferences({
    bool rethrowIfUnavailable = false,
  }) async {
    if (_localCache != null) return _localCache.load();
    if (rethrowIfUnavailable) {
      throw StateError('No local user preferences cache available.');
    }
    return const UserPreferences();
  }
}

UnitSystem _parseUnitSystem(String? raw) {
  return raw == UnitSystem.miles.name ? UnitSystem.miles : UnitSystem.km;
}

ShortDistanceUnit _parseShortDistanceUnit({
  required String? raw,
  required UnitSystem unitSystem,
}) {
  return switch (raw) {
    'feet' => ShortDistanceUnit.feet,
    'meters' => ShortDistanceUnit.meters,
    _ =>
      unitSystem == UnitSystem.miles
          ? ShortDistanceUnit.feet
          : ShortDistanceUnit.meters,
  };
}

ProfileGender? _parseGender(String? raw) {
  return switch (raw?.toLowerCase()) {
    'male' || 'hombre' => ProfileGender.male,
    'female' || 'mujer' => ProfileGender.female,
    'other' || 'otro' => ProfileGender.other,
    _ => null,
  };
}

DateTime? _dateOfBirthFromMillis(Object? value) {
  final millis = switch (value) {
    int number => number,
    num number => number.toInt(),
    _ => null,
  };
  if (millis == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

Map<String, dynamic> _rowFromDynamic(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map((key, entry) => MapEntry('$key', entry));
  }
  return const {};
}

final userPreferencesRepositoryProvider = Provider<UserPreferencesRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return SupabaseUserPreferencesRepository(
    client,
    localCache: SharedPreferencesUserPreferencesRepository(prefs),
  );
});
