import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/models/activity_record.dart';
import 'activity_repository.dart';

class SupabaseActivityRepository implements AsyncActivityRepository {
  SupabaseActivityRepository(this._client, {ActivityRepository? localCache})
    : _localCache = localCache;

  final SupabaseClient _client;
  final ActivityRepository? _localCache;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Future<List<ActivityRecord>> loadAllActivities() async {
    final uid = _uid;
    if (uid == null) return _loadCachedActivities();

    try {
      final response = await _client
          .from('activity_records')
          .select('id, recorded_at, linked_session_id, activity_type, data')
          .eq('user_id', uid)
          .order('recorded_at', ascending: false);

      final activities = _sortActivities(
        _rowsFromResponse(
          response,
        ).map(_activityFromRow).whereType<ActivityRecord>(),
      );
      await _localCache?.saveActivities(activities);
      return activities;
    } catch (_) {
      return _loadCachedActivities(rethrowIfUnavailable: true);
    }
  }

  @override
  Future<List<ActivityRecord>> loadRecentActivities({int limit = 3}) async {
    if (limit <= 0) return const [];
    final activities = await loadAllActivities();
    return activities.take(limit).toList(growable: false);
  }

  @override
  Future<List<ActivityRecord>> loadActivitiesByLinkedSessionId(
    String sessionId,
  ) async {
    if (sessionId.isEmpty) return const [];

    final uid = _uid;
    if (uid == null) {
      return _loadCachedLinkedActivities(
        sessionId,
        rethrowIfUnavailable: false,
      );
    }

    try {
      final response = await _client
          .from('activity_records')
          .select('id, recorded_at, linked_session_id, activity_type, data')
          .eq('user_id', uid)
          .eq('linked_session_id', sessionId)
          .order('recorded_at', ascending: false);

      return _sortActivities(
        _rowsFromResponse(
          response,
        ).map(_activityFromRow).whereType<ActivityRecord>(),
      );
    } catch (_) {
      return _loadCachedLinkedActivities(sessionId, rethrowIfUnavailable: true);
    }
  }

  @override
  Future<ActivityRecord?> loadActivityById(String id) async {
    if (id.isEmpty) return null;

    final uid = _uid;
    if (uid == null) {
      return _localCache?.loadActivityById(id);
    }

    try {
      final response = await _client
          .from('activity_records')
          .select('id, recorded_at, linked_session_id, activity_type, data')
          .eq('user_id', uid)
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return _activityFromRow(_rowFromDynamic(response));
    } catch (_) {
      if (_localCache != null) return _localCache.loadActivityById(id);
      rethrow;
    }
  }

  @override
  Future<void> saveActivity(ActivityRecord activity) async {
    final uid = _uid;
    if (uid == null) {
      if (_localCache != null) return _localCache.saveActivity(activity);
      throw const PostgrestException(message: 'No authenticated user');
    }

    await _client
        .from('activity_records')
        .upsert(_activityRow(uid, activity), onConflict: 'id');
    await _localCache?.saveActivity(activity);
  }

  @override
  Future<void> saveActivities(List<ActivityRecord> activities) async {
    final uid = _uid;
    if (uid == null) {
      if (_localCache != null) return _localCache.saveActivities(activities);
      throw const PostgrestException(message: 'No authenticated user');
    }

    if (activities.isEmpty) {
      await _localCache?.clearActivities();
      return;
    }

    await _client
        .from('activity_records')
        .upsert(
          activities.map((activity) => _activityRow(uid, activity)).toList(),
          onConflict: 'id',
        );
    await _localCache?.saveActivities(activities);
  }

  @override
  Future<void> deleteActivity(String id) async {
    if (id.isEmpty) return;

    final uid = _uid;
    if (uid == null) {
      if (_localCache != null) return _localCache.deleteActivity(id);
      throw const PostgrestException(message: 'No authenticated user');
    }

    await _client
        .from('activity_records')
        .delete()
        .eq('user_id', uid)
        .eq('id', id);
    await _localCache?.deleteActivity(id);
  }

  @override
  Future<void> clearActivities() async {
    final uid = _uid;
    if (uid == null) {
      if (_localCache != null) return _localCache.clearActivities();
      throw const PostgrestException(message: 'No authenticated user');
    }

    await _client.from('activity_records').delete().eq('user_id', uid);
    await _localCache?.clearActivities();
  }

  Future<List<ActivityRecord>> _loadCachedActivities({
    bool rethrowIfUnavailable = false,
  }) async {
    if (_localCache != null) return _localCache.loadAllActivities();
    if (rethrowIfUnavailable) {
      throw StateError('No local activity cache available.');
    }
    return const [];
  }

  Future<List<ActivityRecord>> _loadCachedLinkedActivities(
    String sessionId, {
    required bool rethrowIfUnavailable,
  }) async {
    if (_localCache != null) {
      return _localCache.loadActivitiesByLinkedSessionId(sessionId);
    }
    if (rethrowIfUnavailable) {
      throw StateError('No local activity cache available.');
    }
    return const [];
  }

  List<Map<String, dynamic>> _rowsFromResponse(dynamic response) {
    if (response is! List) return const [];
    return response.map(_rowFromDynamic).toList(growable: false);
  }

  Map<String, dynamic> _rowFromDynamic(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry('$key', entry));
    }
    return const {};
  }

  ActivityRecord? _activityFromRow(Map<String, dynamic> row) {
    final rawData = row['data'];
    if (rawData is! Map) return null;

    final data = rawData.map((key, value) => MapEntry('$key', value));
    data.putIfAbsent('id', () => row['id']);
    data.putIfAbsent('recordedAt', () => row['recorded_at']);

    final linkedSessionId = row['linked_session_id'];
    if (linkedSessionId is String && linkedSessionId.isNotEmpty) {
      data.putIfAbsent('linkedSessionId', () => linkedSessionId);
    }

    final activityType = row['activity_type'];
    if (activityType is String && activityType.isNotEmpty) {
      data.putIfAbsent('kind', () => activityType);
    }

    return ActivityRecord.fromJson(data);
  }

  Map<String, dynamic> _activityRow(String uid, ActivityRecord activity) {
    return {
      'id': activity.id,
      'user_id': uid,
      'recorded_at': activity.recordedAt.toUtc().toIso8601String(),
      'linked_session_id': _nullIfEmpty(activity.linkedSessionId),
      'activity_type': activity.kind.key,
      'data': activity.toJson(),
    };
  }

  String? _nullIfEmpty(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }
}

List<ActivityRecord> _sortActivities(Iterable<ActivityRecord> activities) {
  final sorted = activities.toList(growable: false);
  sorted.sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
  return sorted;
}

final supabaseActivityRepositoryProvider = Provider<AsyncActivityRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  final localCache = ref.watch(activityRepositoryProvider);
  return SupabaseActivityRepository(client, localCache: localCache);
});
