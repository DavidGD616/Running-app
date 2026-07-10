import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/activity/domain/models/activity_record.dart';
import 'package:running_app/features/training_plan/domain/models/adaptation_patch.dart';
import 'package:running_app/features/training_plan/domain/models/adaptation_review.dart';
import 'package:running_app/features/training_plan/domain/models/plan_adjustment.dart';
import 'package:running_app/features/training_plan/domain/models/plan_revision.dart';
import 'package:running_app/features/training_plan/domain/models/session_feedback.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/weekly_training_summary.dart';

void main() {
  test('SessionFeedback JSON round-trips canonical values', () {
    final feedback = SessionFeedback(
      id: 'feedback_w4-tue',
      recordedAt: DateTime(2026, 4, 7, 9, 15),
      plannedSessionId: 'w4-tue',
      activityId: 'w4-tue',
      difficulty: SessionFeedbackDifficulty.hard,
      recoveryStatus: SessionRecoveryStatus.fatigued,
      notes: 'Felt flat after the third rep',
    );

    final decoded = SessionFeedback.fromJson(feedback.toJson());

    expect(decoded, isNotNull);
    expect(decoded!.id, feedback.id);
    expect(decoded.plannedSessionId, feedback.plannedSessionId);
    expect(decoded.activityId, feedback.activityId);
    expect(decoded.difficulty, SessionFeedbackDifficulty.hard);
    expect(decoded.recoveryStatus, SessionRecoveryStatus.fatigued);
    expect(decoded.notes, feedback.notes);
  });

  test('SessionFeedback validation rejects incomplete payloads', () {
    expect(
      SessionFeedback.fromJson({
        'id': '',
        'recordedAt': '2026-04-07T09:15:00.000',
      }),
      isNull,
    );
    expect(
      SessionFeedback.fromJson({
        'id': 'feedback_w4-tue',
        'recordedAt': 'not-a-date',
      }),
      isNull,
    );
  });

  test('SessionFeedback parses legacy and canonical check-in keys', () {
    final parsed = SessionFeedback.fromJson({
      'id': 'feedback_legacy',
      'recordedAt': '2026-06-01T07:15:00.000',
      'plannedSessionId': 'run-legacy',
      'difficulty': 'feedback_manageable',
      'recoveryStatus': 'recovery_fatigued',
      'sleep': 'great',
      'legs': 'normal',
      'pain': 'sharp',
      'motivation': 'motivation_mixed',
    });

    expect(parsed, isNotNull);
    expect(parsed!.sleep, SessionFeedbackSleep.great);
    expect(parsed.legs, SessionFeedbackLegs.normal);
    expect(parsed.pain, SessionFeedbackPain.severe);
    expect(parsed.motivation, SessionFeedbackMotivation.mixed);
  });

  test('PlanAdjustment and PlanRevision JSON round-trip canonical values', () {
    final adjustment = PlanAdjustment(
      id: 'adjustment_w4-wed',
      plannedSessionId: 'w4-wed',
      createdAt: DateTime(2026, 4, 8, 6, 30),
      trigger: PlanAdjustmentTrigger.skippedSession,
      reason: PlanAdjustmentReason.skippedByRunner,
      notes: 'Travel day',
    );
    final revision = PlanRevision(
      id: 'revision_w4-wed',
      createdAt: DateTime(2026, 4, 8, 6, 31),
      reason: PlanRevisionReason.skippedSession,
      summaryKey: 'revision_skipped_session',
      plannedSessionId: 'w4-wed',
      adjustmentIds: [adjustment.id],
    );

    final decodedAdjustment = PlanAdjustment.fromJson(adjustment.toJson());
    final decodedRevision = PlanRevision.fromJson(revision.toJson());

    expect(decodedAdjustment, isNotNull);
    expect(decodedAdjustment!.reason, PlanAdjustmentReason.skippedByRunner);
    expect(decodedAdjustment.trigger, PlanAdjustmentTrigger.skippedSession);
    expect(decodedAdjustment.status, PlanAdjustmentStatus.pending);

    final pendingFromSparseJson = PlanAdjustment.fromJson({
      'id': 'adjustment_w4-wed',
      'plannedSessionId': 'w4-wed',
      'createdAt': '2026-04-08T06:30:00.000',
      'trigger': PlanAdjustmentTrigger.skippedSession.key,
      'reason': PlanAdjustmentReason.skippedByRunner.key,
    });
    expect(pendingFromSparseJson, isNotNull);
    expect(pendingFromSparseJson!.status, PlanAdjustmentStatus.pending);

    expect(decodedRevision, isNotNull);
    expect(decodedRevision!.reason, PlanRevisionReason.skippedSession);
    expect(decodedRevision.adjustmentIds, [adjustment.id]);

    final filteredRevision = PlanRevision.fromJson({
      ...revision.toJson(),
      'adjustmentIds': [adjustment.id, 42, null],
    });
    expect(filteredRevision, isNotNull);
    expect(filteredRevision!.adjustmentIds, [adjustment.id]);
  });

  test(
    'PlanAdjustment and PlanRevision validation reject incomplete payloads',
    () {
      expect(
        PlanAdjustment.fromJson({
          'id': 'adjustment_w4-wed',
          'plannedSessionId': 'w4-wed',
          'createdAt': '2026-04-08T06:30:00.000',
          'trigger': PlanAdjustmentTrigger.skippedSession.key,
        }),
        isNull,
      );
      expect(
        PlanRevision.fromJson({
          'id': 'revision_w4-wed',
          'createdAt': '2026-04-08T06:31:00.000',
          'reason': PlanRevisionReason.skippedSession.key,
        }),
        isNull,
      );
    },
  );

  test('AdaptationPatch and AdaptationReview JSON round-trip', () {
    final patch = AdaptationPatch(
      type: AdaptationPatchType.replaceSession,
      reasonKey: 'reason_adapt_session_type',
      sessionId: 'run-monday',
      date: DateTime(2026, 6, 1, 6, 30),
      beforeSessionType: SessionType.easyRun,
      afterSessionType: SessionType.tempoRun,
      beforeDistanceKm: 8.0,
      afterDistanceKm: 10.0,
      beforeDurationMinutes: 38,
      afterDurationMinutes: 45,
    );
    final roundTripPatch = AdaptationPatch.fromJson(patch.toJson());
    expect(roundTripPatch, isNotNull);
    expect(roundTripPatch!.type, patch.type);
    expect(roundTripPatch.afterSessionType, patch.afterSessionType);
    expect(roundTripPatch.beforeSessionType, isNull);
    expect(roundTripPatch.beforeDistanceKm, isNull);
    final patchJson = patch.toJson();
    expect(patchJson, containsPair('targetType', 'tempoRun'));
    expect(patchJson, containsPair('targetDistanceKm', 10.0));
    expect(patchJson.containsKey('afterSessionType'), isFalse);

    final review = AdaptationReview(
      id: 'review_week_24',
      createdAt: DateTime(2026, 6, 1, 7, 0),
      weekStart: DateTime(2026, 5, 31),
      weekEnd: DateTime(2026, 6, 7),
      status: AdaptationReviewStatus.pending,
      classification: AdaptationReviewClassification.tooAggressive,
      severity: AdaptationReviewSeverity.high,
      summaryKey: 'summary_reduce_load',
      summaryArgs: const {'reason': 'pain'},
      reasonKeys: const ['adapt_reason_pain_reported'],
      patches: [patch],
      loadBefore: 46.0,
      loadAfter: 40.0,
      weeklySummary: WeeklyTrainingSummary(
        weekStart: DateTime(2026, 5, 31),
        weekEnd: DateTime(2026, 6, 7),
        plannedSessions: 2,
        completedSessions: 1,
        plannedDistanceKm: 18,
        completedDistanceKm: 9,
        plannedDurationMinutes: 100,
        completedDurationMinutes: 52,
        hardSessionCount: 1,
        skippedSessionCount: 1,
        veryHardSessionCount: 1,
        poorRecoveryCount: 1,
        painCount: 1,
      ),
    );
    final roundTripReview = AdaptationReview.fromJson(review.toJson());
    expect(roundTripReview, isNotNull);
    expect(roundTripReview!.status, review.status);
    expect(roundTripReview.severity, review.severity);
    expect(roundTripReview.summaryArgs['reason'], 'pain');
    expect(roundTripReview.reasonKeys, ['adapt_reason_pain_reported']);
    expect(roundTripReview.weeklySummary?.plannedSessions, 2);
    expect(roundTripReview.patches, hasLength(1));
    expect(roundTripReview.loadDelta, -6.0);
    expect(roundTripReview.hasLoadDecrease, isTrue);
  });

  test(
    'WeeklyTrainingSummary computes load signals and completion triggers',
    () {
      final reference = DateTime(2026, 6, 10, 7, 0);
      final mondayOffset = reference.weekday - 1;
      final weekStart = DateTime(
        reference.year,
        reference.month,
        reference.day - mondayOffset,
      );

      final sessions = [
        TrainingSession(
          id: 'run-a',
          date: weekStart.add(const Duration(days: 1)),
          type: SessionType.tempoRun,
          status: SessionStatus.completed,
          weekNumber: 1,
          distanceKm: 10,
          durationMinutes: 60,
          effort: TrainingSessionEffort.veryEasy,
        ),
        TrainingSession(
          id: 'run-b',
          date: weekStart.add(const Duration(days: 2)),
          type: SessionType.easyRun,
          status: SessionStatus.skipped,
          weekNumber: 1,
          distanceKm: 8,
          durationMinutes: 40,
          effort: TrainingSessionEffort.easy,
        ),
        TrainingSession(
          id: 'run-c',
          date: weekStart.add(const Duration(days: 3)),
          type: SessionType.longRun,
          status: SessionStatus.upcoming,
          weekNumber: 1,
          distanceKm: 16,
          durationMinutes: 90,
          effort: TrainingSessionEffort.moderate,
        ),
      ];

      final activities = [
        RunActivity(
          id: 'activity-a',
          source: ActivitySource.manual,
          completionStatus: ActivityCompletionStatus.completed,
          recordedAt: weekStart,
          actualDistanceKm: 9,
          actualDuration: const Duration(minutes: 52),
          linkedSessionId: 'run-a',
        ),
      ];

      final feedbacks = [
        SessionFeedback(
          id: 'feedback-a',
          recordedAt: weekStart,
          plannedSessionId: 'run-a',
          difficulty: SessionFeedbackDifficulty.hard,
          recoveryStatus: SessionRecoveryStatus.fatigued,
          pain: SessionFeedbackPain.none,
        ),
        SessionFeedback(
          id: 'feedback-b',
          recordedAt: weekStart,
          plannedSessionId: 'run-b',
          difficulty: SessionFeedbackDifficulty.veryHard,
          recoveryStatus: SessionRecoveryStatus.fatigued,
          pain: SessionFeedbackPain.mild,
        ),
      ];

      final summary = weeklyTrainingSummaryFromPlanAndActivityData(
        sessions: sessions,
        completedActivities: activities,
        feedbacks: feedbacks,
        referenceDate: reference,
      );

      expect(summary.plannedSessions, 2);
      expect(summary.completedSessions, 1);
      expect(summary.completionRate, closeTo(1 / 2, 0.0001));
      expect(summary.completedDistanceKm, 9);
      expect(summary.plannedDistanceKm, 18);
      expect(summary.skippedSessionCount, 1);
      expect(summary.veryHardSessionCount, 1);
      expect(summary.hasLoadSignals, isTrue);
      expect(summary.shouldTriggerAdaptationReview, isTrue);
      expect(summary.signals, contains(WeeklySummarySignal.lowCompletion));
      expect(summary.signals, contains(WeeklySummarySignal.skippedSessions));
      expect(summary.signals, contains(WeeklySummarySignal.painConcern));
    },
  );

  test('WeeklyTrainingSummary counts each hard-feedback session once', () {
    final weekStart = DateTime(2026, 7, 6);
    final sessions = [
      for (var index = 0; index < 2; index++)
        TrainingSession(
          id: 'hard-$index',
          date: weekStart.add(Duration(days: index)),
          type: SessionType.easyRun,
          status: SessionStatus.completed,
          distanceKm: 5,
          durationMinutes: 30,
          effort: TrainingSessionEffort.easy,
        ),
    ];
    final feedbacks = [
      for (var index = 0; index < 2; index++)
        SessionFeedback(
          id: 'feedback-$index',
          recordedAt: weekStart.add(Duration(days: index)),
          plannedSessionId: 'hard-$index',
          difficulty: SessionFeedbackDifficulty.hard,
        ),
    ];

    final summary = WeeklyTrainingSummary.forWeek(
      sessions: sessions,
      completedActivities: const [],
      feedbacks: feedbacks,
      weekStart: weekStart,
      referenceDate: weekStart.add(const Duration(days: 3)),
    );

    expect(summary.weekEnd, DateTime(2026, 7, 12));
    expect(summary.hardSessionCount, 2);
    expect(summary.hasHighLoadSignals, isFalse);
    expect(summary.shouldTriggerAdaptationReview, isFalse);
  });
}
