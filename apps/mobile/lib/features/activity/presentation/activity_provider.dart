import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/activity_repository.dart';
import '../domain/models/activity_record.dart';

final activitiesProvider =
    NotifierProvider<ActivitiesNotifier, List<ActivityRecord>>(() {
      return ActivitiesNotifier();
    });

class ActivitiesNotifier extends Notifier<List<ActivityRecord>> {
  AsyncActivityRepository get _asyncRepository =>
      ref.read(asyncActivityRepositoryProvider);

  @override
  List<ActivityRecord> build() {
    final repository = ref.watch(activityRepositoryProvider);
    ref.watch(asyncActivityRepositoryProvider);
    unawaited(_hydrateFromRepository());
    return repository.loadAllActivities();
  }

  Future<void> reload() async {
    await _hydrateFromRepository();
  }

  Future<void> saveActivity(ActivityRecord activity) async {
    state = _upsertActivity(state, activity);
    await _asyncRepository.saveActivity(activity);
  }

  Future<void> saveActivities(List<ActivityRecord> activities) async {
    state = _sortActivities(activities);
    await _asyncRepository.saveActivities(activities);
  }

  Future<void> deleteActivity(String id) async {
    state = state.where((activity) => activity.id != id).toList();
    await _asyncRepository.deleteActivity(id);
  }

  Future<void> clearActivities() async {
    state = const [];
    await _asyncRepository.clearActivities();
  }

  ActivityRecord? activityById(String id) {
    for (final activity in state) {
      if (activity.id == id) return activity;
    }
    return null;
  }

  Future<void> _hydrateFromRepository() async {
    final activities = await _asyncRepository.loadAllActivities();
    if (ref.mounted) {
      state = activities;
    }
  }
}

final recentActivitiesProvider = Provider<List<ActivityRecord>>((ref) {
  return ref.watch(activitiesProvider).take(3).toList(growable: false);
});

final completedActivitiesProvider = Provider<List<ActivityRecord>>((ref) {
  return ref
      .watch(activitiesProvider)
      .where((activity) => activity.isCompleted)
      .toList(growable: false);
});

final activitiesByLinkedSessionIdProvider =
    Provider.family<List<ActivityRecord>, String>((ref, sessionId) {
      if (sessionId.isEmpty) return const [];
      return ref
          .watch(activitiesProvider)
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
