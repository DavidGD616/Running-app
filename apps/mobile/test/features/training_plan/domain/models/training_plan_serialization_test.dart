import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/training_plan/data/training_plan_seed_data.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_plan.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/workout_step.dart';
import 'package:running_app/features/training_plan/domain/models/workout_target.dart';

void main() {
  group('TrainingSession serialization', () {
    test('easyRun round-trips all structural fields', () {
      final session = TrainingSession(
        id: 'session-easy-1',
        date: DateTime.utc(2026, 4, 14),
        type: SessionType.easyRun,
        status: SessionStatus.upcoming,
        weekNumber: 3,
        distanceKm: 8.0,
        durationMinutes: 50,
        description: 'Easy aerobic run',
        effort: TrainingSessionEffort.easy,
        workoutTarget: WorkoutTarget.effort(TargetZone.easy),
        workoutSteps: [
          WorkoutStep.warmUp(duration: Duration(minutes: 5)),
          WorkoutStep.work(duration: Duration(minutes: 40)),
          WorkoutStep.coolDown(duration: Duration(minutes: 5)),
        ],
        warmUpMinutes: 5,
        coolDownMinutes: 5,
      );

      final restored = TrainingSession.fromJson(session.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, session.id);
      expect(restored.date, session.date);
      expect(restored.type, SessionType.easyRun);
      expect(restored.status, SessionStatus.upcoming);
      expect(restored.weekNumber, 3);
      expect(restored.distanceKm, 8.0);
      expect(restored.durationMinutes, 50);
      expect(restored.description, 'Easy aerobic run');
      expect(restored.effort, TrainingSessionEffort.easy);
      expect(restored.workoutTarget, isNotNull);
      expect(restored.workoutTarget!.zone, TargetZone.easy);
      expect(restored.workoutSteps, hasLength(3));
      expect(restored.warmUpMinutes, 5);
      expect(restored.coolDownMinutes, 5);
    });

    test('intervals round-trips rep metadata and nested workout steps', () {
      final session = TrainingSession(
        id: 'session-intervals-1',
        date: DateTime.utc(2026, 4, 16),
        type: SessionType.intervals,
        status: SessionStatus.today,
        weekNumber: 3,
        distanceKm: 10.0,
        durationMinutes: 60,
        intervalReps: 6,
        intervalRepDistanceMeters: 400,
        intervalRecoverySeconds: 90,
        warmUpMinutes: 10,
        coolDownMinutes: 10,
        workoutTarget: WorkoutTarget.pace(TargetZone.interval),
        workoutSteps: [
          WorkoutStep.warmUp(duration: Duration(minutes: 10)),
          WorkoutStep.repeat(
            repetitions: 6,
            steps: [
              WorkoutStep.work(
                distanceMeters: 400,
                target: WorkoutTarget.pace(TargetZone.interval),
              ),
              WorkoutStep.recovery(
                duration: Duration(seconds: 90),
                target: WorkoutTarget.effort(TargetZone.recovery),
              ),
            ],
          ),
          WorkoutStep.coolDown(duration: Duration(minutes: 10)),
        ],
      );

      final restored = TrainingSession.fromJson(session.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, session.id);
      expect(restored.type, SessionType.intervals);
      expect(restored.intervalReps, 6);
      expect(restored.intervalRepDistanceMeters, 400);
      expect(restored.intervalRecoverySeconds, 90);
      expect(restored.workoutSteps, hasLength(3));
      final repeatStep = restored.workoutSteps[1];
      expect(repeatStep.kind, WorkoutStepKind.repeat);
      expect(repeatStep.repetitions, 6);
      expect(repeatStep.steps, hasLength(2));
      expect(repeatStep.steps.first.distanceMeters, 400);
      expect(repeatStep.steps.last.duration, const Duration(seconds: 90));
    });

    test('tempoRun round-trips with warmUp, coolDown, and target zone', () {
      final session = TrainingSession(
        id: 'session-tempo-1',
        date: DateTime.utc(2026, 4, 17),
        type: SessionType.tempoRun,
        status: SessionStatus.completed,
        weekNumber: 3,
        distanceKm: 12.0,
        durationMinutes: 70,
        effort: TrainingSessionEffort.hard,
        workoutTarget: WorkoutTarget.effort(TargetZone.tempo),
        warmUpMinutes: 10,
        coolDownMinutes: 10,
        workoutSteps: [
          WorkoutStep.warmUp(duration: Duration(minutes: 10)),
          WorkoutStep.work(
            duration: Duration(minutes: 50),
            target: WorkoutTarget.effort(TargetZone.tempo),
          ),
          WorkoutStep.coolDown(duration: Duration(minutes: 10)),
        ],
      );

      final restored = TrainingSession.fromJson(session.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, session.id);
      expect(restored.type, SessionType.tempoRun);
      expect(restored.status, SessionStatus.completed);
      expect(restored.effort, TrainingSessionEffort.hard);
      expect(restored.workoutTarget!.zone, TargetZone.tempo);
      expect(restored.warmUpMinutes, 10);
      expect(restored.coolDownMinutes, 10);
      expect(restored.workoutSteps, hasLength(3));
    });

    test('phases is always empty on a deserialized session', () {
      final session = TrainingSession(
        id: 'session-phases-test',
        date: DateTime.utc(2026, 4, 14),
        type: SessionType.easyRun,
        status: SessionStatus.upcoming,
      );

      final restored = TrainingSession.fromJson(session.toJson());

      expect(restored, isNotNull);
      expect(restored!.phases, isEmpty);
    });
  });

  group('TrainingPlan serialization', () {
    test('seed plan round-trips session count and first session id', () {
      final plan = buildSeedTrainingPlan();

      final restored = TrainingPlan.fromJson(plan.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, plan.id);
      expect(restored.raceType, plan.raceType);
      expect(restored.totalWeeks, plan.totalWeeks);
      expect(restored.currentWeekNumber, plan.currentWeekNumber);
      expect(restored.sessions, hasLength(plan.sessions.length));
      expect(restored.supportSessions, hasLength(plan.supportSessions.length));
      if (plan.sessions.isNotEmpty) {
        expect(restored.sessions.first.id, plan.sessions.first.id);
      }
    });

    test('all raceType enum values survive round-trip', () {
      for (final raceType in TrainingPlanRaceType.values) {
        final session = TrainingSession(
          id: 's1',
          date: DateTime.utc(2026, 4, 14),
          type: SessionType.easyRun,
          status: SessionStatus.upcoming,
        );
        final plan = TrainingPlan(
          id: 'plan-${raceType.name}',
          raceType: raceType,
          totalWeeks: 12,
          currentWeekNumber: 1,
          sessions: [session],
        );

        final restored = TrainingPlan.fromJson(plan.toJson());

        expect(restored, isNotNull, reason: 'raceType: ${raceType.name}');
        expect(restored!.raceType, raceType,
            reason: 'raceType: ${raceType.name}');
      }
    });
  });
}
