import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/training_plan/domain/models/plan_adjustment.dart';
import 'package:running_app/features/training_plan/domain/models/plan_revision.dart';
import 'package:running_app/features/training_plan/domain/models/session_feedback.dart';

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
}
