import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activity/activity.dart';
import '../../pre_run/presentation/run_flow_context.dart';
import '../data/supabase_plan_version_repository.dart';
import '../domain/models/plan_adjustment.dart';
import '../domain/models/plan_revision.dart';
import '../domain/models/session_feedback.dart';
import '../domain/models/session_type.dart';
import '../domain/models/training_plan.dart';
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

/// Thrown when no active plan is found in cache or remote.
class NoPlanFoundException implements Exception {
  const NoPlanFoundException();
}

/// Provides the active training plan loaded from [planVersionRepositoryProvider].
///
/// On first frame: returns cached plan from SharedPreferences (zero latency).
/// In background: refreshes from Supabase and updates state if a newer plan arrives.
/// No cache + no remote plan: throws [NoPlanFoundException].
final trainingPlanProvider =
    AsyncNotifierProvider<TrainingPlanNotifier, TrainingPlan>(
      TrainingPlanNotifier.new,
    );

class TrainingPlanNotifier extends AsyncNotifier<TrainingPlan> {
  final Map<String, SessionStatus> _manualStatusOverrides = {};

  @override
  Future<TrainingPlan> build() async {
    final repo = ref.watch(planVersionRepositoryProvider);

    // Fast sync read from cache (SP) for zero-latency first frame.
    final cached = repo.loadActivePlanSync();
    if (cached != null) {
      // Trigger async refresh in background without blocking first frame.
      Future.microtask(() async {
        final refreshed = await repo.loadActivePlanAsync();
        if (refreshed != null && ref.mounted) {
          state = AsyncData(_applyActivityStatus(refreshed));
        }
      });
      return _applyActivityStatus(cached);
    }

    // No cache — full async load (first install after sign-in).
    final plan = await repo.loadActivePlanAsync();
    if (plan != null) return _applyActivityStatus(plan);

    throw const NoPlanFoundException();
  }

  void skipSession(String sessionId) {
    // Always record the adjustment and revision regardless of whether the plan
    // is loaded yet — the sessionId is all we need for the persistence record.
    final now = DateTime.now();
    final eventIdSuffix = now.microsecondsSinceEpoch.toString();
    final adjustment = PlanAdjustment(
      id: 'adjustment_${sessionId}_$eventIdSuffix',
      plannedSessionId: sessionId,
      createdAt: now,
      trigger: PlanAdjustmentTrigger.skippedSession,
      reason: PlanAdjustmentReason.skippedByRunner,
    );
    final revision = PlanRevision(
      id: 'revision_${sessionId}_$eventIdSuffix',
      createdAt: now,
      reason: PlanRevisionReason.skippedSession,
      summaryKey: 'revision_skipped_session',
      plannedSessionId: sessionId,
      adjustmentIds: [adjustment.id],
    );
    unawaited(
      ref.read(planAdjustmentsProvider.notifier).recordAdjustment(adjustment),
    );
    unawaited(
      ref.read(planRevisionsProvider.notifier).recordRevision(revision),
    );

    _manualStatusOverrides[sessionId] = SessionStatus.skipped;
    // Only update plan state if a plan is already loaded; overrides will be
    // applied automatically when the plan resolves via _applyActivityStatus.
    final current = state.value;
    if (current != null) {
      state = AsyncData(_applyOverrides(current));
    }
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
    // Only update plan state if a plan is already loaded.
    final current = state.value;
    if (current != null) {
      state = AsyncData(_applyOverrides(current));
    }
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

  /// Applies completed-activity status and manual overrides to a loaded plan.
  TrainingPlan _applyActivityStatus(TrainingPlan plan) {
    final completedActivities = ref.read(completedActivitiesProvider);
    final linkedSessionIds = completedActivities
        .where((activity) => activity.hasLinkedSession)
        .map((activity) => activity.linkedSessionId!)
        .toSet();

    final updatedSessions = plan.sessions
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
      id: plan.id,
      raceType: plan.raceType,
      totalWeeks: plan.totalWeeks,
      currentWeekNumber: plan.currentWeekNumber,
      sessions: updatedSessions,
      supportSessions: plan.supportSessions,
    );
  }

  /// Re-applies only manual overrides to the current plan (used by
  /// [skipSession] and [restoreSession] where the base plan is already loaded).
  TrainingPlan _applyOverrides(TrainingPlan plan) {
    final completedActivities = ref.read(completedActivitiesProvider);
    final linkedSessionIds = completedActivities
        .where((activity) => activity.hasLinkedSession)
        .map((activity) => activity.linkedSessionId!)
        .toSet();

    final updatedSessions = plan.sessions
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
      id: plan.id,
      raceType: plan.raceType,
      totalWeeks: plan.totalWeeks,
      currentWeekNumber: plan.currentWeekNumber,
      sessions: updatedSessions,
      supportSessions: plan.supportSessions,
    );
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
  final plan = ref.watch(trainingPlanProvider).value;
  if (plan == null) return WeekProgress.fromSessions(const []);
  return WeekProgress.fromSessions(plan.currentWeekSessions);
});
