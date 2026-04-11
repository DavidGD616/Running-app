import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/training_plan/domain/models/plan_version.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';

TrainingPlan _minimalPlan() {
  return TrainingPlan(
    id: 'plan-1',
    raceType: TrainingPlanRaceType.halfMarathon,
    totalWeeks: 12,
    currentWeekNumber: 1,
    sessions: [
      TrainingSession(
        id: 's1',
        date: DateTime.utc(2026, 4, 14),
        type: SessionType.easyRun,
        status: SessionStatus.upcoming,
      ),
    ],
  );
}

void main() {
  group('PlanVersion serialization', () {
    test('round-trips all fields', () {
      final version = PlanVersion(
        id: 'v-abc-123',
        generatedAt: DateTime.utc(2026, 4, 11, 10, 30),
        requestedBy: 'onboarding',
        isActive: true,
        plan: _minimalPlan(),
      );

      final restored = PlanVersion.fromJson(version.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, version.id);
      expect(restored.generatedAt, version.generatedAt);
      expect(restored.requestedBy, version.requestedBy);
      expect(restored.isActive, isTrue);
      expect(restored.plan.id, version.plan.id);
      expect(restored.plan.raceType, TrainingPlanRaceType.halfMarathon);
      expect(restored.plan.sessions, hasLength(1));
    });

    test('copyWith isActive flips the flag', () {
      final version = PlanVersion(
        id: 'v-1',
        generatedAt: DateTime.utc(2026, 4, 11),
        requestedBy: 'retry',
        isActive: true,
        plan: _minimalPlan(),
      );

      final deactivated = version.copyWith(isActive: false);

      expect(deactivated.isActive, isFalse);
      expect(deactivated.id, version.id);
    });

    test('fromJson returns null for missing required fields', () {
      expect(PlanVersion.fromJson({}), isNull);
      expect(PlanVersion.fromJson({'id': '', 'generatedAt': '2026-04-11T00:00:00.000Z', 'requestedBy': 'onboarding', 'isActive': true, 'plan': {}}), isNull);
    });

    test('schemaVersion is included in toJson', () {
      final version = PlanVersion(
        id: 'v-1',
        generatedAt: DateTime.utc(2026, 4, 11),
        requestedBy: 'onboarding',
        isActive: false,
        plan: _minimalPlan(),
      );
      expect(version.toJson()['schemaVersion'], 1);
    });
  });
}
