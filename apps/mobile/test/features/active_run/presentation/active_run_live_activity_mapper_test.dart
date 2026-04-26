import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/domain/models/gps_state.dart';
import 'package:running_app/features/active_run/presentation/active_run_live_activity_mapper.dart';
import 'package:running_app/features/active_run/presentation/active_run_timeline.dart';
import 'package:running_app/features/active_run/presentation/active_run_controller.dart';
import 'package:running_app/features/pre_run/presentation/run_flow_context.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/workout_target.dart';
import 'package:running_app/features/user_preferences/domain/user_preferences.dart';
import 'package:running_app/l10n/app_localizations.dart';
import 'package:running_app/l10n/app_localizations_en.dart';

RunFlowSessionContext createTestSession({
  SessionType type = SessionType.easyRun,
  double distanceKm = 5.0,
  int durationMinutes = 30,
}) {
  return RunFlowSessionContext(
    sessionId: 'test-session-1',
    sessionDate: DateTime(2026, 4, 25),
    sessionType: type,
    weekNumber: 1,
    workoutTarget: WorkoutTarget.effort(TargetZone.easy),
    workoutSteps: const [],
    supplementalType: null,
    isRunSession: true,
    distanceKm: distanceKm,
    durationMinutes: durationMinutes,
    elevationGainMeters: 50,
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
    warmUpMinutes: 5,
    coolDownMinutes: 5,
  );
}

AppLocalizations createL10n() {
  return AppLocalizationsEn();
}

ActiveRunState createRunningState({
  Duration elapsed = const Duration(minutes: 10, seconds: 30),
  double distanceKm = 1.23,
  int currentPaceSecondsPerKm = 300,
  int averagePaceSecondsPerKm = 330,
  GpsStatus gpsStatus = GpsStatus.ready,
  ActiveRunTimelineBlock? currentBlock,
  ActiveRunTimelineBlock? nextBlock,
  Duration blockElapsed = Duration.zero,
  double blockDistanceKm = 0.0,
  int timelineIndex = 0,
  RunFlowSessionContext? session,
  bool isTimerOnlyMode = false,
}) {
  return ActiveRunState(
    session: session,
    elapsed: elapsed,
    distanceKm: distanceKm,
    currentPaceSecondsPerKm: currentPaceSecondsPerKm,
    averagePaceSecondsPerKm: averagePaceSecondsPerKm,
    gpsStatus: gpsStatus,
    currentBlock: currentBlock,
    nextBlock: nextBlock,
    blockElapsed: blockElapsed,
    blockDistanceKm: blockDistanceKm,
    timelineIndex: timelineIndex,
    isPaused: false,
    isSurging: false,
    routePointCount: 5,
    splits: const [],
    error: null,
    modalIntent: ActiveRunModalIntent.none,
    isTimerOnlyMode: isTimerOnlyMode,
    checkIn: null,
  );
}

ActiveRunState createPausedState({
  Duration elapsed = const Duration(minutes: 10, seconds: 30),
  double distanceKm = 1.23,
  int currentPaceSecondsPerKm = 300,
  int averagePaceSecondsPerKm = 330,
  ActiveRunTimelineBlock? currentBlock,
  ActiveRunTimelineBlock? nextBlock,
  Duration blockElapsed = Duration.zero,
  double blockDistanceKm = 0.0,
  int timelineIndex = 0,
  RunFlowSessionContext? session,
}) {
  return ActiveRunState(
    session: session,
    elapsed: elapsed,
    distanceKm: distanceKm,
    currentPaceSecondsPerKm: currentPaceSecondsPerKm,
    averagePaceSecondsPerKm: averagePaceSecondsPerKm,
    gpsStatus: GpsStatus.ready,
    currentBlock: currentBlock,
    nextBlock: nextBlock,
    blockElapsed: blockElapsed,
    blockDistanceKm: blockDistanceKm,
    timelineIndex: timelineIndex,
    isPaused: true,
    isSurging: false,
    routePointCount: 5,
    splits: const [],
    error: null,
    modalIntent: ActiveRunModalIntent.none,
    isTimerOnlyMode: false,
    checkIn: null,
  );
}

void main() {
  group('buildRunLiveActivityData', () {
    group('running state', () {
      test('maps elapsed, distance, current pace, and average pace', () {
        final state = createRunningState(
          elapsed: const Duration(minutes: 10, seconds: 30),
          distanceKm: 1.23,
          currentPaceSecondsPerKm: 300,
          averagePaceSecondsPerKm: 330,
        );
        final session = createTestSession();
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: session,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.elapsedSeconds, 630);
        expect(result.elapsedLabel, '10:30');
        expect(result.distanceKm, 1.23);
        expect(result.statusTitleLabel, 'Status');
        expect(result.statusLabel, 'Tracking');
        expect(result.distanceLabel, '1.2');
        expect(result.paceSecondsPerKm, 300);
        expect(result.currentPaceLabel, '5:00 min/km');
        expect(result.avgPaceLabel, '5:30 min/km');
        expect(result.isPaused, false);
      });

      test('maps GPS status labels', () {
        final l10n = createL10n();

        final acquiring = buildRunLiveActivityData(
          state: createRunningState(gpsStatus: GpsStatus.acquiring),
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );
        final weak = buildRunLiveActivityData(
          state: createRunningState(gpsStatus: GpsStatus.weak),
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );
        final lost = buildRunLiveActivityData(
          state: createRunningState(gpsStatus: GpsStatus.lost),
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(acquiring.statusLabel, 'Waiting for GPS signal');
        expect(weak.statusLabel, 'Weak GPS signal');
        expect(lost.statusLabel, 'GPS signal lost');
      });

      test('maps timer-only status before GPS status', () {
        final result = buildRunLiveActivityData(
          state: createRunningState(
            gpsStatus: GpsStatus.ready,
            isTimerOnlyMode: true,
          ),
          session: null,
          unitSystem: UnitSystem.km,
          l10n: createL10n(),
        );

        expect(result.statusLabel, 'Timer only');
      });

      test('distance label formats correctly', () {
        final state = createRunningState(distanceKm: 5.67);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.distanceLabel, '5.7');
      });
    });

    group('paused state', () {
      test('maps isPaused = true', () {
        final state = createPausedState();
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.isPaused, true);
        expect(result.statusTitleLabel, 'Status');
        expect(result.statusLabel, 'Paused');
      });

      test('maps stable elapsed label', () {
        final state = createPausedState(
          elapsed: const Duration(minutes: 5, seconds: 45),
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.elapsedLabel, '05:45');
        expect(result.elapsedSeconds, 345);
      });

      test('elapsed label shows hours when elapsed >= 1 hour', () {
        final state = createPausedState(
          elapsed: const Duration(hours: 1, minutes: 5, seconds: 30),
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.elapsedLabel, '1:05:30');
      });
    });

    group('metric unit labels', () {
      test('distance unit is km', () {
        final state = createRunningState();
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.distanceUnit, 'km');
        expect(result.unitFactor, 1.0);
      });

      test('pace unit is min/km', () {
        final state = createRunningState(currentPaceSecondsPerKm: 300);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.paceUnit, 'min/km');
      });

      test('distance label uses km conversion', () {
        final state = createRunningState(distanceKm: 3.0);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.distanceLabel, '3.0');
      });

      test('current pace uses direct seconds per km', () {
        final state = createRunningState(currentPaceSecondsPerKm: 360);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.currentPaceLabel, '6:00 min/km');
        expect(result.paceSecondsPerKm, 360);
      });

      test('average pace uses direct seconds per km', () {
        final state = createRunningState(averagePaceSecondsPerKm: 390);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.avgPaceLabel, '6:30 min/km');
      });
    });

    group('imperial unit labels', () {
      test('distance unit is mi', () {
        final state = createRunningState(distanceKm: 1.0);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.miles,
          l10n: l10n,
        );

        expect(result.distanceUnit, 'mi');
        expect(result.unitFactor, closeTo(0.621371, 0.0001));
      });

      test('pace unit is min/mi', () {
        final state = createRunningState(currentPaceSecondsPerKm: 300);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.miles,
          l10n: l10n,
        );

        expect(result.paceUnit, 'min/mi');
      });

      test('distance label uses mile conversion', () {
        final state = createRunningState(distanceKm: 1.609344);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.miles,
          l10n: l10n,
        );

        expect(result.distanceLabel, '1.0');
      });

      test('current pace converts to seconds per mile', () {
        final state = createRunningState(currentPaceSecondsPerKm: 300);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.miles,
          l10n: l10n,
        );

        expect(result.currentPaceLabel, '8:03 min/mi');
      });

      test('average pace converts to seconds per mile', () {
        final state = createRunningState(averagePaceSecondsPerKm: 360);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.miles,
          l10n: l10n,
        );

        expect(result.avgPaceLabel, '9:39 min/mi');
      });
    });

    group('duration block progress', () {
      test('progress fraction is 0.0 when no current block', () {
        final state = createRunningState(currentBlock: null);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.blockProgressFraction, 0.0);
      });

      test('duration block progress correct at midpoint', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          duration: const Duration(minutes: 20),
          target: const WorkoutTarget.effort(TargetZone.tempo),
        );
        final state = createRunningState(
          currentBlock: block,
          blockElapsed: const Duration(minutes: 10),
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.blockProgressFraction, closeTo(0.5, 0.01));
      });

      test('duration block progress clamped to 1.0 at completion', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          duration: const Duration(minutes: 20),
          target: const WorkoutTarget.effort(TargetZone.tempo),
        );
        final state = createRunningState(
          currentBlock: block,
          blockElapsed: const Duration(minutes: 30),
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.blockProgressFraction, 1.0);
      });

      test('duration block progress is 0.0 for zero duration block', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          duration: Duration.zero,
          target: const WorkoutTarget.effort(TargetZone.tempo),
        );
        final state = createRunningState(
          currentBlock: block,
          blockElapsed: const Duration(minutes: 5),
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.blockProgressFraction, 0.0);
      });
    });

    group('distance block progress', () {
      test('distance block progress correct at midpoint', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          distanceMeters: 400,
          target: const WorkoutTarget.pace(TargetZone.interval),
        );
        final state = createRunningState(
          currentBlock: block,
          blockDistanceKm: 0.2,
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.blockProgressFraction, closeTo(0.5, 0.01));
      });

      test('distance block progress clamped to 1.0 at completion', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          distanceMeters: 400,
          target: const WorkoutTarget.pace(TargetZone.interval),
        );
        final state = createRunningState(
          currentBlock: block,
          blockDistanceKm: 0.5,
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.blockProgressFraction, 1.0);
      });

      test('distance block progress is 0.0 for zero distance block', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          distanceMeters: 0,
          target: const WorkoutTarget.pace(TargetZone.interval),
        );
        final state = createRunningState(
          currentBlock: block,
          blockDistanceKm: 0.1,
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.blockProgressFraction, 0.0);
      });
    });

    group('duration block remaining', () {
      test('block remaining label shows time remaining for duration block', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          duration: const Duration(minutes: 20),
          target: const WorkoutTarget.effort(TargetZone.tempo),
        );
        final state = createRunningState(
          currentBlock: block,
          blockElapsed: const Duration(minutes: 10),
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.blockRemainingLabel, '10:00 remaining');
      });

      test(
        'block remaining label empty when block elapsed exceeds duration',
        () {
          final block = ActiveRunTimelineBlock(
            kind: ActiveRunBlockKind.work,
            duration: const Duration(minutes: 20),
            target: const WorkoutTarget.effort(TargetZone.tempo),
          );
          final state = createRunningState(
            currentBlock: block,
            blockElapsed: const Duration(minutes: 25),
          );
          final l10n = createL10n();

          final result = buildRunLiveActivityData(
            state: state,
            session: null,
            unitSystem: UnitSystem.km,
            l10n: l10n,
          );

          expect(result.blockRemainingLabel, '');
        },
      );

      test('block remaining label empty when no current block', () {
        final state = createRunningState(currentBlock: null);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.blockRemainingLabel, '');
      });
    });

    group('distance block remaining', () {
      test(
        'block remaining label shows distance remaining for distance block',
        () {
          final block = ActiveRunTimelineBlock(
            kind: ActiveRunBlockKind.work,
            distanceMeters: 400,
            target: const WorkoutTarget.pace(TargetZone.interval),
          );
          final state = createRunningState(
            currentBlock: block,
            blockDistanceKm: 0.2,
          );
          final l10n = createL10n();

          final result = buildRunLiveActivityData(
            state: state,
            session: null,
            unitSystem: UnitSystem.km,
            l10n: l10n,
          );

          expect(result.blockRemainingLabel, '200 m remaining');
        },
      );

      test('block remaining label shows meters for distance under a mile', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          distanceMeters: 1609,
          target: const WorkoutTarget.pace(TargetZone.interval),
        );
        final state = createRunningState(
          currentBlock: block,
          blockDistanceKm: 0.4,
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.miles,
          l10n: l10n,
        );

        expect(result.blockRemainingLabel, '1209 m remaining');
      });

      test('block remaining label empty when distance exceeded', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          distanceMeters: 400,
          target: const WorkoutTarget.pace(TargetZone.interval),
        );
        final state = createRunningState(
          currentBlock: block,
          blockDistanceKm: 0.5,
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.blockRemainingLabel, '');
      });
    });

    group('zero distance average pace', () {
      test('zero distance produces placeholder average pace', () {
        final state = createRunningState(
          distanceKm: 0.0,
          averagePaceSecondsPerKm: 0,
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.avgPaceLabel, '--:-- min/km');
      });

      test('zero current pace produces placeholder pace', () {
        final state = createRunningState(currentPaceSecondsPerKm: 0);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.currentPaceLabel, '--:-- min/km');
      });

      test('negative pace produces placeholder pace', () {
        final state = createRunningState(currentPaceSecondsPerKm: -1);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.currentPaceLabel, '--:-- min/km');
      });
    });

    group('no current block fallback', () {
      test(
        'no current block falls back to session type label for easy run',
        () {
          final state = createRunningState(currentBlock: null);
          final session = createTestSession(type: SessionType.easyRun);
          final l10n = createL10n();

          final result = buildRunLiveActivityData(
            state: state,
            session: session,
            unitSystem: UnitSystem.km,
            l10n: l10n,
          );

          expect(result.currentBlockLabel, 'Easy');
        },
      );

      test(
        'no current block falls back to session type label for intervals',
        () {
          final state = createRunningState(currentBlock: null);
          final session = createTestSession(type: SessionType.intervals);
          final l10n = createL10n();

          final result = buildRunLiveActivityData(
            state: state,
            session: session,
            unitSystem: UnitSystem.km,
            l10n: l10n,
          );

          expect(result.currentBlockLabel, 'Fast');
        },
      );

      test(
        'no current block falls back to session type label for long run',
        () {
          final state = createRunningState(currentBlock: null);
          final session = createTestSession(type: SessionType.longRun);
          final l10n = createL10n();

          final result = buildRunLiveActivityData(
            state: state,
            session: session,
            unitSystem: UnitSystem.km,
            l10n: l10n,
          );

          expect(result.currentBlockLabel, 'Steady');
        },
      );

      test('no session falls back to easy label for current block', () {
        final state = createRunningState(currentBlock: null);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.currentBlockLabel, 'Easy');
      });

      test('no session produces empty workout name', () {
        final state = createRunningState(currentBlock: null);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.workoutName, '');
      });
    });

    group('current block label mapping', () {
      test('warmup block maps to Warm-up', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.warmUp,
          duration: const Duration(minutes: 5),
          target: const WorkoutTarget.effort(TargetZone.easy),
        );
        final state = createRunningState(currentBlock: block);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.currentBlockLabel, 'Warm-up');
      });

      test('work block maps to Fast Rep', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          duration: const Duration(minutes: 1),
          target: const WorkoutTarget.pace(TargetZone.interval),
        );
        final state = createRunningState(currentBlock: block);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.currentBlockLabel, 'Fast rep');
      });

      test('work block for hill repeats maps to Climb', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          duration: const Duration(minutes: 1),
          target: const WorkoutTarget.pace(TargetZone.interval),
        );
        final state = createRunningState(currentBlock: block);
        final session = createTestSession(type: SessionType.hillRepeats);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: session,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.currentBlockLabel, 'Climb');
      });

      test('recovery block maps to Recovery', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.recovery,
          duration: const Duration(minutes: 2),
          target: const WorkoutTarget.effort(TargetZone.recovery),
        );
        final state = createRunningState(currentBlock: block);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.currentBlockLabel, 'Recovery');
      });

      test('cooldown block maps to Cool-down', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.coolDown,
          duration: const Duration(minutes: 5),
          target: const WorkoutTarget.effort(TargetZone.recovery),
        );
        final state = createRunningState(currentBlock: block);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.currentBlockLabel, 'Cool-down');
      });

      test('stride block maps to Stride', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.stride,
          duration: const Duration(minutes: 1),
          target: const WorkoutTarget.effort(TargetZone.tempo),
        );
        final state = createRunningState(currentBlock: block);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.currentBlockLabel, 'Stride');
      });
    });

    group('rep label', () {
      test('rep block shows rep index and total reps', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          duration: const Duration(minutes: 1),
          distanceMeters: 400,
          repIndex: 2,
          totalReps: 5,
          target: const WorkoutTarget.pace(TargetZone.interval),
        );
        final state = createRunningState(currentBlock: block);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.repLabel, '2 / 5');
      });

      test('non-rep block has null rep label', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          duration: const Duration(minutes: 1),
          target: const WorkoutTarget.pace(TargetZone.interval),
        );
        final state = createRunningState(currentBlock: block);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.repLabel, null);
      });
    });

    group('next block label', () {
      test('next block label is populated when next block exists', () {
        final currentBlock = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          duration: const Duration(minutes: 1),
          target: const WorkoutTarget.pace(TargetZone.interval),
        );
        final nextBlock = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.recovery,
          duration: const Duration(minutes: 2),
          target: const WorkoutTarget.effort(TargetZone.recovery),
        );
        final state = createRunningState(
          currentBlock: currentBlock,
          nextBlock: nextBlock,
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.nextBlockLabel, 'Recovery');
      });

      test('next block label is null when no next block', () {
        final block = ActiveRunTimelineBlock(
          kind: ActiveRunBlockKind.work,
          duration: const Duration(minutes: 1),
          target: const WorkoutTarget.pace(TargetZone.interval),
        );
        final state = createRunningState(currentBlock: block, nextBlock: null);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.nextBlockLabel, null);
      });
    });

    group('planned pace label', () {
      test('planned pace label uses session distance and duration', () {
        final state = createRunningState();
        final session = createTestSession(
          distanceKm: 10.0,
          durationMinutes: 60,
        );
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: session,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.plannedPaceLabel, '6:00 min/km');
      });

      test('planned pace label is empty when session null', () {
        final state = createRunningState();
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.plannedPaceLabel, '');
      });
    });

    group('workout name', () {
      test('workout name uses session type for easy run', () {
        final state = createRunningState();
        final session = createTestSession(type: SessionType.easyRun);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: session,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.workoutName, 'Easy Run');
      });

      test('workout name uses session type for intervals', () {
        final state = createRunningState();
        final session = createTestSession(type: SessionType.intervals);
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: session,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.workoutName, 'Intervals');
      });

      test('workout name is empty when session is null', () {
        final state = createRunningState();
        final l10n = createL10n();

        final result = buildRunLiveActivityData(
          state: state,
          session: null,
          unitSystem: UnitSystem.km,
          l10n: l10n,
        );

        expect(result.workoutName, '');
      });
    });
  });
}
