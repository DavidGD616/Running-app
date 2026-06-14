part of 'runner_profile_repository.dart';

class SupabaseRunnerProfileRepository implements RunnerProfileRepository {
  SupabaseRunnerProfileRepository({
    required SupabaseClient client,
    required String userId,
    required SharedPreferencesRunnerProfileRepository localCache,
  }) : _client = client,
       _userId = userId,
       _localCache = localCache;

  static const _profilesTable = 'runner_profiles';
  static const _draftsTable = 'runner_profile_drafts';

  final SupabaseClient _client;
  final String _userId;
  final SharedPreferencesRunnerProfileRepository _localCache;

  @override
  RunnerProfileDraft? loadDraft() {
    if (!_isCurrentAuthenticatedUser) return null;
    return _localCache.loadDraft();
  }

  @override
  RunnerProfile? loadProfile() {
    if (!_isCurrentAuthenticatedUser) return null;
    return _localCache.loadProfile();
  }

  @override
  bool hasPersistedProfile() {
    if (!_isCurrentAuthenticatedUser) return false;
    return _localCache.hasPersistedProfile();
  }

  @override
  Future<RunnerProfileDraft?> loadDraftAsync({bool refresh = true}) async {
    if (!_isCurrentAuthenticatedUser) return null;

    if (!refresh) {
      return _localCache.loadDraft();
    }

    try {
      final draft = await _fetchDraft();
      if (!_isCurrentAuthenticatedUser) return null;

      if (draft == null) {
        await _localCache.clearDraft();
        return null;
      }

      await _localCache.saveDraft(draft);
      if (!_isCurrentAuthenticatedUser) {
        await _localCache.clearDraft();
        return null;
      }

      return draft;
    } catch (_) {
      return _isCurrentAuthenticatedUser ? _localCache.loadDraft() : null;
    }
  }

  @override
  Future<RunnerProfile?> loadProfileAsync({bool refresh = true}) async {
    if (!_isCurrentAuthenticatedUser) return null;

    if (!refresh) {
      return _localCache.loadProfile();
    }

    try {
      final profile = await _fetchProfile();
      if (!_isCurrentAuthenticatedUser) return null;

      if (profile == null) {
        await _localCache.clearCachedProfileOnly();
        return null;
      }

      await _localCache.saveProfile(profile);
      if (!_isCurrentAuthenticatedUser) {
        await _localCache.clearProfile();
        return null;
      }

      return profile;
    } catch (_) {
      return _isCurrentAuthenticatedUser ? _localCache.loadProfile() : null;
    }
  }

  @override
  Future<bool> hasPersistedProfileAsync({bool refresh = true}) async {
    return (await loadProfileAsync(refresh: refresh)) != null;
  }

  @override
  Future<void> saveDraft(RunnerProfileDraft draft) async {
    if (!_isCurrentAuthenticatedUser) return;
    await _localCache.saveDraft(draft);
    if (!_isCurrentAuthenticatedUser) {
      await _localCache.clearDraft();
      return;
    }

    if (!_isCurrentAuthenticatedUser) return;
    await _client.from(_draftsTable).upsert({
      'user_id': _userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'data': draft.toJson(),
    }, onConflict: 'user_id');
  }

  @override
  Future<void> saveProfile(RunnerProfile profile) async {
    if (!_isCurrentAuthenticatedUser) return;

    final completedOnboardingAt =
        profile.completedOnboardingAt ?? await _loadCompletedOnboardingAt();
    final profileToPersist =
        profile.completedOnboardingAt == completedOnboardingAt
        ? profile
        : profile.copyWith(completedOnboardingAt: completedOnboardingAt);

    if (!_isCurrentAuthenticatedUser) return;
    await _client.from(_profilesTable).upsert({
      'user_id': _userId,
      'schema_version': profileToPersist.schemaVersion,
      'updated_at': profileToPersist.updatedAt.toUtc().toIso8601String(),
      'completed_onboarding_at': completedOnboardingAt
          ?.toUtc()
          .toIso8601String(),
      'data': _profileData(profileToPersist),
    }, onConflict: 'user_id');

    if (!_isCurrentAuthenticatedUser) return;
    await _client.from(_draftsTable).delete().eq('user_id', _userId);

    if (!_isCurrentAuthenticatedUser) return;
    await _localCache.saveProfile(profileToPersist);
    if (!_isCurrentAuthenticatedUser) {
      await _localCache.clearProfile();
    }
  }

  @override
  Future<void> clearDraft() async {
    if (!_isCurrentAuthenticatedUser) return;
    await _localCache.clearDraft();

    try {
      if (!_isCurrentAuthenticatedUser) return;
      await _client.from(_draftsTable).delete().eq('user_id', _userId);
    } catch (_) {
      // Preserve local clear semantics even if the network path is unavailable.
    }
  }

  @override
  Future<void> clearProfile() async {
    if (!_isCurrentAuthenticatedUser) return;
    await _localCache.clearProfile();

    try {
      if (!_isCurrentAuthenticatedUser) return;
      await _client.from(_profilesTable).delete().eq('user_id', _userId);
      await _client.from(_draftsTable).delete().eq('user_id', _userId);
    } catch (_) {
      // Preserve local clear semantics even if the network path is unavailable.
    }
  }

  Future<RunnerProfile?> _fetchProfile() async {
    final row = await _client
        .from(_profilesTable)
        .select('schema_version, updated_at, completed_onboarding_at, data')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) return null;

    final map = _stringKeyedMap(row);
    final data = _stringKeyedMap(map['data']);
    if (data.isEmpty) return null;

    data['schemaVersion'] ??= map['schema_version'];
    data['updatedAt'] ??= _normalizeDateTimeValue(map['updated_at']);
    data['completedOnboardingAt'] ??= _normalizeDateTimeValue(
      map['completed_onboarding_at'],
    );

    return RunnerProfile.fromJson(data);
  }

  Future<RunnerProfileDraft?> _fetchDraft() async {
    final row = await _client
        .from(_draftsTable)
        .select('data')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) return null;

    final map = _stringKeyedMap(row);
    final data = _stringKeyedMap(map['data']);
    if (data.isEmpty) return null;

    return RunnerProfileDraft.fromJson(data);
  }

  Future<DateTime?> _loadCompletedOnboardingAt() async {
    final row = await _client
        .from(_profilesTable)
        .select('completed_onboarding_at')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) return null;

    final map = _stringKeyedMap(row);
    final raw = map['completed_onboarding_at'];
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Map<String, dynamic> _profileData(RunnerProfile profile) {
    final data = profile.toJson();
    data['schemaVersion'] = profile.schemaVersion;
    data['updatedAt'] = profile.updatedAt.toUtc().toIso8601String();
    return data;
  }

  Map<String, dynamic> _stringKeyedMap(Object? value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, nestedValue) => MapEntry('$key', nestedValue));
  }

  Object? _normalizeDateTimeValue(Object? value) {
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value;
  }

  bool get _isCurrentAuthenticatedUser =>
      _client.auth.currentUser?.id == _userId;
}
