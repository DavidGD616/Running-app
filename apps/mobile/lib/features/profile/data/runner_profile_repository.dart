import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../domain/models/runner_profile.dart';

abstract interface class RunnerProfileRepository {
  RunnerProfileDraft? loadDraft();
  RunnerProfile? loadProfile();
  bool hasPersistedProfile();
  Future<void> saveDraft(RunnerProfileDraft draft);
  Future<void> saveProfile(RunnerProfile profile);
  Future<void> clearDraft();
  Future<void> clearProfile();
}

class SharedPreferencesRunnerProfileRepository
    implements RunnerProfileRepository {
  SharedPreferencesRunnerProfileRepository(this._prefs);

  static const draftStorageKey = 'runner_profile_draft_v1';
  static const profileStorageKey = 'runner_profile_v1';

  final SharedPreferences _prefs;

  @override
  RunnerProfileDraft? loadDraft() {
    final raw = _prefs.getString(draftStorageKey);
    if (raw == null || raw.isEmpty) return null;
    final json = _decode(raw);
    if (json == null) return null;
    return RunnerProfileDraft.fromJson(json);
  }

  @override
  RunnerProfile? loadProfile() {
    final raw = _prefs.getString(profileStorageKey);
    if (raw == null || raw.isEmpty) return null;
    final json = _decode(raw);
    if (json == null) return null;
    return RunnerProfile.fromJson(json);
  }

  @override
  bool hasPersistedProfile() => loadProfile() != null;

  @override
  Future<void> saveDraft(RunnerProfileDraft draft) async {
    await _prefs.setString(draftStorageKey, jsonEncode(draft.toJson()));
  }

  @override
  Future<void> saveProfile(RunnerProfile profile) async {
    await _prefs.setString(profileStorageKey, jsonEncode(profile.toJson()));
    await _prefs.remove(draftStorageKey);
  }

  @override
  Future<void> clearDraft() async {
    await _prefs.remove(draftStorageKey);
  }

  @override
  Future<void> clearProfile() async {
    await _prefs.remove(profileStorageKey);
    await _prefs.remove(draftStorageKey);
  }

  Map<String, dynamic>? _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

final runnerProfileRepositoryProvider = Provider<RunnerProfileRepository>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPreferencesRunnerProfileRepository(prefs);
});
