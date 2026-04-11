import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/activity_repository.dart';
import '../domain/models/activity_record.dart';

final activitiesProvider =
    AsyncNotifierProvider<ActivitiesNotifier, List<ActivityRecord>>(
      ActivitiesNotifier.new,
    );

class ActivitiesNotifier extends AsyncNotifier<List<ActivityRecord>> {
  AsyncActivityRepository get _asyncRepository =>
      ref.read(asyncActivityRepositoryProvider);

  int _mutationEpoch = 0;

  @override
  Future<List<ActivityRecord>> build() async {
    final buildEpoch = _mutationEpoch;
    final activities = await _asyncRepository.loadAllActivities();

    if (!ref.mounted) return activities;
    if (_mutationEpoch != buildEpoch) {
      return state.value ?? activities;
    }

    return activities;
  }

  Future<void> reload() async {
    final buildEpoch = _mutationEpoch;
    final activities = await _asyncRepository.loadAllActivities();

    if (ref.mounted && _mutationEpoch == buildEpoch) {
      state = AsyncData(activities);
    }
  }

  Future<void> saveActivity(ActivityRecord activity) async {
    _mutationEpoch++;
    final current = state.value ?? const <ActivityRecord>[];
    state = AsyncData(_upsertActivity(current, activity));
    await _asyncRepository.saveActivity(activity);
  }

  Future<void> saveActivities(List<ActivityRecord> activities) async {
    _mutationEpoch++;
    final sorted = _sortActivities(activities);
    state = AsyncData(sorted);
    await _asyncRepository.saveActivities(sorted);
  }

  Future<void> deleteActivity(String id) async {
    _mutationEpoch++;
    final current = state.value ?? const <ActivityRecord>[];
    state = AsyncData(
      current.where((activity) => activity.id != id).toList(growable: false),
    );
    await _asyncRepository.deleteActivity(id);
  }

  Future<void> clearActivities() async {
    _mutationEpoch++;
    state = const AsyncData(<ActivityRecord>[]);
    await _asyncRepository.clearActivities();
  }

  ActivityRecord? activityById(String id) {
    for (final activity in state.value ?? const <ActivityRecord>[]) {
      if (activity.id == id) return activity;
    }
    return null;
  }
}

final recentActivitiesProvider = Provider<List<ActivityRecord>>((ref) {
  final activities =
      ref.watch(activitiesProvider).value ?? const <ActivityRecord>[];
  return activities.take(3).toList(growable: false);
});

final completedActivitiesProvider = Provider<List<ActivityRecord>>((ref) {
  final activities =
      ref.watch(activitiesProvider).value ?? const <ActivityRecord>[];
  return activities
      .where((activity) => activity.isCompleted)
      .toList(growable: false);
});

final activitiesByLinkedSessionIdProvider =
    Provider.family<List<ActivityRecord>, String>((ref, sessionId) {
      if (sessionId.isEmpty) return const [];
      final activities =
          ref.watch(activitiesProvider).value ?? const <ActivityRecord>[];
      return activities
          .where((activity) => activity.linkedSessionId == sessionId)
          .toList(growable: false);
    });

List<ActivityRecord> _upsertActivity(
  List<ActivityRecord> activities,
  ActivityRecord activity,
) {
  final updated = [
    activity,
    ...activities.where((existing) => existing.id != activity.id),
  ];
  return _sortActivities(updated);
}

List<ActivityRecord> _sortActivities(Iterable<ActivityRecord> activities) {
  final sorted = activities.toList(growable: false);
  sorted.sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
  return sorted;
}
