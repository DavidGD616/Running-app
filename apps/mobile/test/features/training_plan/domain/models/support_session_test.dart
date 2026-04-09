import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/support_session.dart';

void main() {
  test('SupportSession JSON round-trips canonical support session values', () {
    final supportSession = SupportSession(
      id: 'support_w4-wed',
      date: DateTime(2026, 4, 8, 18, 30),
      weekNumber: 4,
      type: SupplementalSessionType.strength,
      status: SupportSessionStatus.completed,
      durationMinutes: 30,
      notes: 'Single-leg strength circuit',
      feedbackId: 'feedback_support_w4-wed',
      revisionId: 'revision_support_w4-wed',
      adjustmentId: 'adjustment_support_w4-wed',
    );

    final decoded = SupportSession.fromJson(supportSession.toJson());

    expect(decoded, isNotNull);
    expect(decoded!.id, supportSession.id);
    expect(decoded.type, SupplementalSessionType.strength);
    expect(decoded.status, SupportSessionStatus.completed);
    expect(decoded.isSupportSession, isTrue);
    expect(decoded.isRunSession, isFalse);
    expect(supplementalSessionTypeFromKey(decoded.type.key), decoded.type);
    expect(SessionType.crossTraining.isRunSession, isFalse);
    expect(SessionType.crossTraining.countsAsRun, isFalse);
  });

  test('SupportSession validation rejects incomplete payloads', () {
    expect(
      SupportSession.fromJson({
        'id': 'support_w4-wed',
        'date': '2026-04-08T18:30:00.000',
        'weekNumber': 4,
        'status': SupportSessionStatus.completed.key,
      }),
      isNull,
    );
    expect(
      SupportSession.fromJson({
        'id': 'support_w4-wed',
        'date': 'not-a-date',
        'weekNumber': 4,
        'type': SupplementalSessionType.strength.key,
        'status': SupportSessionStatus.completed.key,
      }),
      isNull,
    );
  });
}
