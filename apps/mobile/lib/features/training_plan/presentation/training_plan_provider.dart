import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/training_plan_seed_data.dart';
import '../domain/models/training_plan.dart';
import '../domain/models/session_type.dart';
import '../domain/models/week_progress.dart';

/// Provides the active training plan.
/// Swap the body to load from an API or local DB in a future sprint.
final trainingPlanProvider =
    NotifierProvider<TrainingPlanNotifier, TrainingPlan>(() {
      return TrainingPlanNotifier();
    });

class TrainingPlanNotifier extends Notifier<TrainingPlan> {
  @override
  TrainingPlan build() {
    return buildSeedTrainingPlan();
  }

  void skipSession(String sessionId) {
    final updatedSessions = state.sessions.map((s) {
      if (s.id == sessionId) {
        return s.copyWith(status: SessionStatus.skipped);
      }
      return s;
    }).toList();

    state = TrainingPlan(
      id: state.id,
      name: state.name,
      raceType: state.raceType,
      totalWeeks: state.totalWeeks,
      currentWeekNumber: state.currentWeekNumber,
      sessions: updatedSessions,
    );
  }

  void restoreSession(String sessionId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final updatedSessions = state.sessions.map((s) {
      if (s.id == sessionId) {
        final sessionDate = DateTime(s.date.year, s.date.month, s.date.day);
        if (sessionDate.isAtSameMomentAs(today)) {
          return s.copyWith(status: SessionStatus.today);
        }
        return s.copyWith(status: SessionStatus.upcoming);
      }
      return s;
    }).toList();

    state = TrainingPlan(
      id: state.id,
      name: state.name,
      raceType: state.raceType,
      totalWeeks: state.totalWeeks,
      currentWeekNumber: state.currentWeekNumber,
      sessions: updatedSessions,
    );
  }
}

/// Derived provider — computes week progress from the current week's sessions.
final weekProgressProvider = Provider<WeekProgress>((ref) {
  final plan = ref.watch(trainingPlanProvider);
  return WeekProgress.fromSessions(plan.currentWeekSessions);
});
