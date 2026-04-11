import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/presentation/auth_state_provider.dart';
import '../domain/models/runner_profile.dart';

part 'supabase_runner_profile_repository.dart';

abstract interface class RunnerProfileRepository {
  RunnerProfileDraft? loadDraft();
  RunnerProfile? loadProfile();
  bool hasPersistedProfile();
  Future<RunnerProfileDraft?> loadDraftAsync({bool refresh = true});
  Future<RunnerProfile?> loadProfileAsync({bool refresh = true});
  Future<bool> hasPersistedProfileAsync({bool refresh = true});
  Future<void> saveDraft(RunnerProfileDraft draft);
  Future<void> saveProfile(RunnerProfile profile);
  Future<void> clearDraft();
  Future<void> clearProfile();
}

/// Local cache implementation backed by [SharedPreferences].
///
/// SharedPreferences is retained as the explicit local cache layer for the
/// Supabase implementations. This provides offline read access and reduces
/// cold-start latency. A future sprint may replace SP with SQLite/Drift for
/// structured cache, but for now SP is the locked cache strategy.
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
  Future<RunnerProfileDraft?> loadDraftAsync({bool refresh = true}) async {
    return loadDraft();
  }

  @override
  Future<RunnerProfile?> loadProfileAsync({bool refresh = true}) async {
    return loadProfile();
  }

  @override
  Future<bool> hasPersistedProfileAsync({bool refresh = true}) async {
    return hasPersistedProfile();
  }

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

  Future<void> clearCachedProfileOnly() async {
    await _prefs.remove(profileStorageKey);
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

/// Switching provider: returns [SupabaseRunnerProfileRepository] when a user
/// is authenticated, otherwise falls back to the local
/// [SharedPreferencesRunnerProfileRepository].
final runnerProfileRepositoryProvider = Provider<RunnerProfileRepository>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final localCache = SharedPreferencesRunnerProfileRepository(prefs);

  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return localCache;
  }

  final client = ref.watch(supabaseClientProvider);
  return SupabaseRunnerProfileRepository(
    client: client,
    userId: user.id,
    localCache: localCache,
  );
});
