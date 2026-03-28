import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/training_plan_seed_data.dart';
import '../domain/models/training_plan.dart';
import '../domain/models/week_progress.dart';

/// Provides the active training plan.
/// Swap the body to load from an API or local DB in a future sprint.
final trainingPlanProvider = Provider<TrainingPlan>((ref) {
  return buildSeedTrainingPlan();
});

/// Derived provider — computes week progress from the current week's sessions.
final weekProgressProvider = Provider<WeekProgress>((ref) {
  final plan = ref.watch(trainingPlanProvider);
  return WeekProgress.fromSessions(plan.currentWeekSessions);
});
