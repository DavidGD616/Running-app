import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activity/activity.dart';
import '../../pre_run/presentation/run_flow_context.dart';
import '../data/training_plan_seed_data.dart';
import '../domain/models/plan_adjustment.dart';
import '../domain/models/plan_revision.dart';
import '../domain/models/session_feedback.dart';
import '../domain/models/session_type.dart';
import '../domain/models/training_plan.dart';
import '../domain/models/training_session.dart';
import '../domain/models/week_progress.dart';
import 'adaptation_provider.dart';

final sessionFeedbacksProvider = Provider<List<SessionFeedback>>((ref) {
  return ref.watch(sessionFeedbackProvider).value ?? const [];
});

final sessionFeedbacksForSessionProvider =
    Provider.family<List<SessionFeedback>, String>((ref, sessionId) {
      return ref
          .watch(sessionFeedbacksProvider)
          .where((feedback) => feedback.plannedSessionId == sessionId)
          .toList(growable: false);
    });

final sessionAdjustmentRequestsProvider = Provider<List<PlanAdjustment>>((ref) {
  return ref.watch(planAdjustmentsProvider).value ?? const [];
});

final sessionAdjustmentRequestsForSessionProvider =
    Provider.family<List<PlanAdjustment>, String>((ref, sessionId) {
      return ref
          .watch(sessionAdjustmentRequestsProvider)
          .where((adjustment) => adjustment.plannedSessionId == sessionId)
          .toList(growable: false);
    });

/// Provides the active training plan.
/// Swap the body to load from an API or local DB in a future sprint.
final trainingPlanProvider =
    NotifierProvider<TrainingPlanNotifier, TrainingPlan>(() {
      return TrainingPlanNotifier();
    });

class TrainingPlanNotifier extends Notifier<TrainingPlan> {
  final Map<String, SessionStatus> _manualStatusOverrides = {};

  @override
  TrainingPlan build() {
    final completedActivities = ref.watch(completedActivitiesProvider);
    return _composePlan(completedActivities);
  }

  void skipSession(String sessionId) {
    final session = _sessionById(sessionId);
    if (session != null) {
      final now = DateTime.now();
      final eventIdSuffix = now.microsecondsSinceEpoch.toString();
      final adjustment = PlanAdjustment(
        id: 'adjustment_${sessionId}_$eventIdSuffix',
        plannedSessionId: session.id,
        createdAt: now,
        trigger: PlanAdjustmentTrigger.skippedSession,
        reason: PlanAdjustmentReason.skippedByRunner,
      );
      final revision = PlanRevision(
        id: 'revision_${sessionId}_$eventIdSuffix',
        createdAt: now,
        reason: PlanRevisionReason.skippedSession,
        summaryKey: 'revision_skipped_session',
        plannedSessionId: session.id,
        adjustmentIds: [adjustment.id],
      );
      unawaited(
        ref.read(planAdjustmentsProvider.notifier).recordAdjustment(adjustment),
      );
      unawaited(
        ref.read(planRevisionsProvider.notifier).recordRevision(revision),
      );
    }

    _manualStatusOverrides[sessionId] = SessionStatus.skipped;
    state = _composePlan(ref.read(completedActivitiesProvider));
  }

  void restoreSession(String sessionId) {
    _manualStatusOverrides.remove(sessionId);
    final pendingAdjustments =
        (ref.read(planAdjustmentsProvider).value ?? const <PlanAdjustment>[])
            .where(
              (adjustment) =>
                  adjustment.plannedSessionId == sessionId &&
                  adjustment.status == PlanAdjustmentStatus.pending,
            )
            .toList(growable: false);
    for (final adjustment in pendingAdjustments) {
      unawaited(
        ref
            .read(planAdjustmentsProvider.notifier)
            .recordAdjustment(
              adjustment.copyWith(status: PlanAdjustmentStatus.dismissed),
            ),
      );
    }
    state = _composePlan(ref.read(completedActivitiesProvider));
  }

  void recordCompletedRunFeedback({
    required RunFlowSessionContext session,
    required String activityId,
    required ActivityPerceivedEffort? perceivedEffort,
    required PreRunCheckIn? checkIn,
    required String? notes,
    required DateTime recordedAt,
  }) {
    final eventIdSuffix = recordedAt.microsecondsSinceEpoch.toString();
    final feedback = SessionFeedback(
      id: 'feedback_${activityId}_$eventIdSuffix',
      recordedAt: recordedAt,
      plannedSessionId: session.sessionId,
      activityId: activityId,
      difficulty: _difficultyFromEffort(perceivedEffort),
      recoveryStatus: _recoveryStatusFromCheckIn(checkIn),
      notes: notes,
    );
    unawaited(
      ref.read(sessionFeedbackProvider.notifier).recordFeedback(feedback),
    );
  }

  TrainingPlan _composePlan(Iterable<ActivityRecord> activities) {
    final seed = buildSeedTrainingPlan();
    final linkedSessionIds = activities
        .where((activity) => activity.hasLinkedSession)
        .map((activity) => activity.linkedSessionId!)
        .toSet();
    final updatedSessions = seed.sessions
        .map((session) {
          final manualStatus = _manualStatusOverrides[session.id];
          if (manualStatus != null) {
            return session.copyWith(status: manualStatus);
          }

          if (linkedSessionIds.contains(session.id)) {
            return session.copyWith(status: SessionStatus.completed);
          }

          return session;
        })
        .toList(growable: false);

    return TrainingPlan(
      id: seed.id,
      raceType: seed.raceType,
      totalWeeks: seed.totalWeeks,
      currentWeekNumber: seed.currentWeekNumber,
      sessions: updatedSessions,
      supportSessions: seed.supportSessions,
    );
  }

  TrainingSession? _sessionById(String sessionId) {
    for (final session in state.sessions) {
      if (session.id == sessionId) return session;
    }
    return null;
  }
}

SessionFeedbackDifficulty? _difficultyFromEffort(
  ActivityPerceivedEffort? effort,
) {
  return switch (effort) {
    ActivityPerceivedEffort.veryEasy => SessionFeedbackDifficulty.veryEasy,
    ActivityPerceivedEffort.easy ||
    ActivityPerceivedEffort.moderate => SessionFeedbackDifficulty.manageable,
    ActivityPerceivedEffort.hard => SessionFeedbackDifficulty.hard,
    ActivityPerceivedEffort.veryHard => SessionFeedbackDifficulty.veryHard,
    null => null,
  };
}

SessionRecoveryStatus? _recoveryStatusFromCheckIn(PreRunCheckIn? checkIn) {
  return switch (checkIn?.sleep) {
    PreRunSleepLevel.great => SessionRecoveryStatus.fresh,
    PreRunSleepLevel.okay => SessionRecoveryStatus.okay,
    PreRunSleepLevel.poor => SessionRecoveryStatus.fatigued,
    null => null,
  };
}

/// Derived provider — computes week progress from the current week's sessions.
final weekProgressProvider = Provider<WeekProgress>((ref) {
  final plan = ref.watch(trainingPlanProvider);
  return WeekProgress.fromSessions(plan.currentWeekSessions);
});
