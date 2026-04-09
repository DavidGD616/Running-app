import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/activity_repository.dart';
import '../domain/models/activity_record.dart';

final activitiesProvider =
    NotifierProvider<ActivitiesNotifier, List<ActivityRecord>>(() {
      return ActivitiesNotifier();
    });

class ActivitiesNotifier extends Notifier<List<ActivityRecord>> {
  late final ActivityRepository _repository;

  @override
  List<ActivityRecord> build() {
    _repository = ref.watch(activityRepositoryProvider);
    return _repository.loadAllActivities();
  }

  void reload() {
    state = _repository.loadAllActivities();
  }

  Future<void> saveActivity(ActivityRecord activity) async {
    state = _upsertActivity(state, activity);
    await _repository.saveActivity(activity);
  }

  Future<void> saveActivities(List<ActivityRecord> activities) async {
    state = _sortActivities(activities);
    await _repository.saveActivities(activities);
  }

  Future<void> deleteActivity(String id) async {
    state = state.where((activity) => activity.id != id).toList();
    await _repository.deleteActivity(id);
  }

  Future<void> clearActivities() async {
    state = const [];
    await _repository.clearActivities();
  }

  ActivityRecord? activityById(String id) {
    for (final activity in state) {
      if (activity.id == id) return activity;
    }
    return null;
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
