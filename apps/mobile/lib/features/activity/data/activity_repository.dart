import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../domain/models/activity_record.dart';

abstract interface class ActivityRepository {
  List<ActivityRecord> loadAllActivities();
  List<ActivityRecord> loadRecentActivities({int limit = 3});
  List<ActivityRecord> loadActivitiesByLinkedSessionId(String sessionId);
  ActivityRecord? loadActivityById(String id);
  Future<void> saveActivity(ActivityRecord activity);
  Future<void> saveActivities(List<ActivityRecord> activities);
  Future<void> deleteActivity(String id);
  Future<void> clearActivities();
}

class SharedPreferencesActivityRepository implements ActivityRepository {
  SharedPreferencesActivityRepository(this._prefs);

  static const storageKey = 'activity_records_v1';

  final SharedPreferences _prefs;

  @override
  List<ActivityRecord> loadAllActivities() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = _decodeList(raw);
    if (decoded == null) return const [];

    final activities = <ActivityRecord>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final activity = ActivityRecord.fromJson(item);
        if (activity != null) activities.add(activity);
      } else if (item is Map) {
        final activity = ActivityRecord.fromJson(
          item.map((key, value) => MapEntry('$key', value)),
        );
        if (activity != null) activities.add(activity);
      }
    }
    return _sortActivities(activities);
  }

  @override
  List<ActivityRecord> loadRecentActivities({int limit = 3}) {
    if (limit <= 0) return const [];
    return loadAllActivities().take(limit).toList(growable: false);
  }

  @override
  List<ActivityRecord> loadActivitiesByLinkedSessionId(String sessionId) {
    if (sessionId.isEmpty) return const [];
    return loadAllActivities()
        .where((activity) => activity.linkedSessionId == sessionId)
        .toList(growable: false);
  }

  @override
  ActivityRecord? loadActivityById(String id) {
    if (id.isEmpty) return null;
    for (final activity in loadAllActivities()) {
      if (activity.id == id) return activity;
    }
    return null;
  }

  @override
  Future<void> saveActivity(ActivityRecord activity) async {
    final activities = loadAllActivities();
    final updated = [
      activity,
      ...activities.where((existing) => existing.id != activity.id),
    ];
    await _writeActivities(updated);
  }

  @override
  Future<void> saveActivities(List<ActivityRecord> activities) async {
    await _writeActivities(activities);
  }

  @override
  Future<void> deleteActivity(String id) async {
    if (id.isEmpty) return;
    final updated = loadAllActivities()
        .where((activity) => activity.id != id)
        .toList();
    await _writeActivities(updated);
  }

  @override
  Future<void> clearActivities() async {
    await _prefs.remove(storageKey);
  }

  Future<void> _writeActivities(List<ActivityRecord> activities) async {
    final sorted = _sortActivities(activities);
    await _prefs.setString(
      storageKey,
      jsonEncode(sorted.map((activity) => activity.toJson()).toList()),
    );
  }

  List<dynamic>? _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {
      return null;
    }
    return null;
  }
}

List<ActivityRecord> _sortActivities(Iterable<ActivityRecord> activities) {
  final sorted = activities.toList(growable: false);
  sorted.sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
  return sorted;
}

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPreferencesActivityRepository(prefs);
});
