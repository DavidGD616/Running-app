import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/training_session.dart';
import 'package:running_app/features/training_plan/domain/models/workout_step.dart';

void main() {
  group('TrainingSession.fromJson — generated payload', () {
    test('parses description field from generated coach note', () {
      final sessionJson = {
        'id': 'gen-session-1',
        'date': '2026-04-14T00:00:00.000Z',
        'type': 'easyRun',
        'status': 'today',
        'weekNumber': 1,
        'distanceKm': 8.0,
        'durationMinutes': 50,
        'description': 'Ejecuta a tu ritmo fácil y sostenible.',
        'effort': 'easy',
        'workoutTarget': {'zone': 'easy'},
        'workoutSteps': [
          {
            'kind': 'warmUp',
            'durationMs': 300000,
            'target': {'zone': 'easy'},
          },
          {
            'kind': 'work',
            'durationMs': 2400000,
            'target': {'zone': 'easy'},
          },
          {
            'kind': 'coolDown',
            'durationMs': 300000,
            'target': {'zone': 'recovery'},
          },
        ],
        'supplementalType': null,
        'elevationGainMeters': 120,
        'intervalReps': null,
        'intervalRepDistanceMeters': null,
        'intervalRecoverySeconds': null,
        'warmUpMinutes': 5,
        'coolDownMinutes': 5,
      };

      final session = TrainingSession.fromJson(sessionJson);

      expect(session, isNotNull);
      expect(session!.description, 'Ejecuta a tu ritmo fácil y sostenible.');
      expect(session.id, 'gen-session-1');
      expect(session.type, SessionType.easyRun);
      expect(session.status, SessionStatus.today);
      expect(session.workoutSteps, hasLength(3));
    });

    test('parses nested repeat block with stride and recovery children', () {
      final sessionJson = {
        'id': 'gen-session-stride-1',
        'date': '2026-04-14T00:00:00.000Z',
        'type': 'easyRun',
        'status': 'today',
        'weekNumber': 1,
        'distanceKm': 8.0,
        'durationMinutes': 50,
        'workoutSteps': [
          {'kind': 'warmUp', 'durationMs': 300000},
          {
            'kind': 'repeat',
            'repetitions': 4,
            'steps': [
              {
                'kind': 'stride',
                'durationMs': 20000,
                'target': {'zone': 'interval'},
              },
              {
                'kind': 'recovery',
                'durationMs': 60000,
                'target': {'zone': 'recovery'},
              },
            ],
          },
          {'kind': 'coolDown', 'durationMs': 300000},
        ],
      };

      final session = TrainingSession.fromJson(sessionJson);

      expect(session, isNotNull);
      expect(session!.workoutSteps, hasLength(3));

      final repeatStep = session.workoutSteps[1];
      expect(repeatStep.kind, WorkoutStepKind.repeat);
      expect(repeatStep.repetitions, 4);
      expect(repeatStep.steps, hasLength(2));
      expect(repeatStep.steps[0].kind, WorkoutStepKind.stride);
      expect(repeatStep.steps[0].duration, const Duration(seconds: 20));
      expect(repeatStep.steps[1].kind, WorkoutStepKind.recovery);
      expect(repeatStep.steps[1].duration, const Duration(seconds: 60));
    });

    test('parses a full generated stride session from JSON fixture', () {
      final fixture = File(
        'test/features/training_plan/domain/models/generated_session_fixture.json',
      );
      final fixtureJson =
          json.decode(fixture.readAsStringSync()) as Map<String, dynamic>;

      final session = TrainingSession.fromJson(fixtureJson);

      expect(session, isNotNull);
      expect(session!.id, 'gen-session-1');
      expect(session.description, 'Ejecuta a tu ritmo fácil y sostenible.');
      expect(session.workoutSteps, hasLength(4));
      expect(session.workoutSteps[0].kind, WorkoutStepKind.warmUp);
      expect(session.workoutSteps[0].duration, const Duration(minutes: 5));
      expect(session.workoutSteps[1].kind, WorkoutStepKind.work);
      expect(session.workoutSteps[1].duration, const Duration(minutes: 40));
      expect(session.workoutSteps[2].kind, WorkoutStepKind.repeat);
      expect(session.workoutSteps[2].repetitions, 4);
      expect(session.workoutSteps[2].steps, hasLength(2));
      expect(session.workoutSteps[2].steps[0].kind, WorkoutStepKind.stride);
      expect(session.workoutSteps[2].steps[1].kind, WorkoutStepKind.recovery);
      expect(session.workoutSteps[3].kind, WorkoutStepKind.coolDown);
      expect(session.workoutSteps[3].duration, const Duration(minutes: 5));
    });

    test('gracefully handles null/missing description', () {
      final sessionJson = {
        'id': 'gen-session-no-desc',
        'date': '2026-04-14T00:00:00.000Z',
        'type': 'easyRun',
        'status': 'upcoming',
        'weekNumber': 1,
        'workoutSteps': [
          {'kind': 'work', 'durationMs': 2400000},
        ],
      };

      final session = TrainingSession.fromJson(sessionJson);

      expect(session, isNotNull);
      expect(session!.description, isNull);
      expect(session.workoutSteps, hasLength(1));
    });

    test('gracefully skips invalid workout steps', () {
      final sessionJson = {
        'id': 'gen-session-mixed-steps',
        'date': '2026-04-14T00:00:00.000Z',
        'type': 'easyRun',
        'status': 'upcoming',
        'weekNumber': 1,
        'workoutSteps': [
          {'kind': 'warmUp', 'durationMs': 300000},
          {'kind': 'invalidKind', 'durationMs': 1000},
          {'kind': 'work', 'durationMs': 2400000},
          null,
          {'kind': 'coolDown', 'durationMs': 300000},
        ],
      };

      final session = TrainingSession.fromJson(sessionJson);

      expect(session, isNotNull);
      expect(session!.workoutSteps, hasLength(3));
      expect(session.workoutSteps[0].kind, WorkoutStepKind.warmUp);
      expect(session.workoutSteps[1].kind, WorkoutStepKind.work);
      expect(session.workoutSteps[2].kind, WorkoutStepKind.coolDown);
    });

    test('parses generic Map workoutSteps from Supabase response', () {
      final sessionJson = <Object, Object>{
        'id': 'gen-session-generic-map',
        'date': '2026-04-14T00:00:00.000Z',
        'type': 'easyRun',
        'status': 'upcoming',
        'weekNumber': 1,
        'workoutSteps': <Object>[
          <String, Object>{
            'kind': 'warmUp',
            'durationMs': 300000,
            'target': <String, Object>{'zone': 'easy'},
          },
          <String, Object>{
            'kind': 'repeat',
            'repetitions': 2,
            'steps': <Object>[
              <String, Object>{'kind': 'stride', 'durationMs': 20000},
            ],
          },
        ],
      };

      final session = TrainingSession.fromJson(
        sessionJson.map((key, value) => MapEntry('$key', value)),
      );

      expect(session, isNotNull);
      expect(session!.workoutSteps, hasLength(2));
      expect(session.workoutSteps[0].kind, WorkoutStepKind.warmUp);
      expect(session.workoutSteps[1].kind, WorkoutStepKind.repeat);
      expect(session.workoutSteps[1].repetitions, 2);
      expect(session.workoutSteps[1].steps[0].kind, WorkoutStepKind.stride);
    });
  });
}
