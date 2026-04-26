import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/data/run_location_tracker.dart';
import 'package:running_app/features/active_run/domain/models/gps_state.dart';
import 'package:running_app/features/active_run/domain/models/run_track_point.dart';
import 'package:running_app/features/active_run/presentation/active_run_controller.dart';
import 'package:running_app/features/active_run/presentation/location_tracker_provider.dart';
import 'package:running_app/features/pre_run/presentation/run_flow_context.dart';
import 'package:running_app/features/training_plan/domain/models/session_type.dart';
import 'package:running_app/features/training_plan/domain/models/workout_step.dart';
import 'package:running_app/features/training_plan/domain/models/workout_target.dart';

class FakeClock {
  FakeClock(this._currentTime);

  DateTime _currentTime;

  DateTime get now => _currentTime;

  void advance(Duration duration) {
    _currentTime = _currentTime.add(duration);
  }
}

class FakeRunLocationTracker implements RunLocationTracker {
  FakeRunLocationTracker();

  final _controller = StreamController<RunTrackPoint>.broadcast();
  bool _started = false;

  @override
  Stream<RunTrackPoint> get points => _controller.stream;

  @override
  void start() {
    if (_started) return;
    _started = true;
  }

  @override
  void stop() {
    _started = false;
    _controller.close();
  }

  void addPoint(RunTrackPoint point) {
    if (!_controller.isClosed) {
      _controller.add(point);
    }
  }

  void addError(Object error) {
    if (!_controller.isClosed) {
      _controller.addError(error);
    }
  }
}

RunFlowSessionContext createTestSession() {
  return RunFlowSessionContext(
    sessionId: 'test-session-1',
    sessionDate: DateTime(2026, 4, 25),
    sessionType: SessionType.easyRun,
    weekNumber: 1,
    workoutTarget: WorkoutTarget.effort(TargetZone.easy),
    workoutSteps: const [],
    supplementalType: null,
    isRunSession: true,
    distanceKm: 5.0,
    durationMinutes: 30,
    elevationGainMeters: 50,
    intervalReps: null,
    intervalRepDistanceMeters: null,
    intervalRecoverySeconds: null,
    warmUpMinutes: 5,
    coolDownMinutes: 5,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActiveRunState', () {
    test('initial state has correct defaults', () {
      final state = ActiveRunState.initial();

      expect(state.session, null);
      expect(state.elapsed, Duration.zero);
      expect(state.distanceKm, 0.0);
      expect(state.currentPaceSecondsPerKm, 0);
      expect(state.averagePaceSecondsPerKm, 0);
      expect(state.gpsStatus, GpsStatus.acquiring);
      expect(state.currentBlock, null);
      expect(state.nextBlock, null);
      expect(state.blockElapsed, Duration.zero);
      expect(state.blockDistanceKm, 0.0);
      expect(state.timelineIndex, 0);
      expect(state.isPaused, false);
      expect(state.isSurging, false);
      expect(state.routePointCount, 0);
      expect(state.splits, isEmpty);
      expect(state.error, null);
      expect(state.modalIntent, ActiveRunModalIntent.none);
      expect(state.isTimerOnlyMode, false);
    });

    test('copyWith preserves unchanged fields', () {
      final state = ActiveRunState.initial();
      final copied = state.copyWith(distanceKm: 5.0);

      expect(copied.distanceKm, 5.0);
      expect(copied.elapsed, state.elapsed);
      expect(copied.gpsStatus, state.gpsStatus);
    });

    test('copyWith can set error field', () {
      final state = ActiveRunState.initial();
      final copied = state.copyWith(error: 'GPS error');

      expect(copied.error, 'GPS error');
    });
  });

  group('ActiveRunSplit', () {
    test('creates split with correct values', () {
      final split = ActiveRunSplit(
        splitIndex: 0,
        startedAt: DateTime(2026, 4, 25, 10, 0, 0),
        endedAt: DateTime(2026, 4, 25, 10, 5, 0),
        duration: const Duration(minutes: 5),
        distanceKm: 1.0,
        paceSecondsPerKm: 300,
      );

      expect(split.splitIndex, 0);
      expect(split.startedAt, DateTime(2026, 4, 25, 10, 0, 0));
      expect(split.endedAt, DateTime(2026, 4, 25, 10, 5, 0));
      expect(split.duration, const Duration(minutes: 5));
      expect(split.distanceKm, 1.0);
      expect(split.paceSecondsPerKm, 300);
    });
  });

  group('ActiveRunFinishResult', () {
    test('creates result with all fields', () {
      final result = ActiveRunFinishResult(
        runId: 'test-run-id',
        session: createTestSession(),
        checkIn: null,
        elapsed: const Duration(minutes: 30),
        distanceKm: 5.0,
        splits: const [],
      );

      expect(result.runId, 'test-run-id');
      expect(result.session, isNotNull);
      expect(result.checkIn, null);
      expect(result.elapsed, const Duration(minutes: 30));
      expect(result.distanceKm, 5.0);
      expect(result.splits, isEmpty);
    });
  });

  group('ActiveRunStartInput', () {
    test('creates input with all fields', () {
      final input = ActiveRunStartInput(
        session: createTestSession(),
        checkIn: null,
        timerOnlyMode: false,
      );

      expect(input.session, isNotNull);
      expect(input.checkIn, null);
      expect(input.timerOnlyMode, false);
    });

    test('timerOnlyMode can be true', () {
      final input = ActiveRunStartInput(
        session: createTestSession(),
        checkIn: null,
        timerOnlyMode: true,
      );

      expect(input.timerOnlyMode, true);
    });
  });

  group('FakeRunLocationTracker', () {
    test('starts and stops without error', () {
      final tracker = FakeRunLocationTracker();
      expect(() => tracker.start(), returnsNormally);
      expect(() => tracker.stop(), returnsNormally);
    });

    test('can add points to stream', () async {
      final tracker = FakeRunLocationTracker();
      tracker.start();

      final points = <RunTrackPoint>[];
      tracker.points.listen(points.add);

      final point = RunTrackPoint(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 100.0,
        speed: 5.0,
        heading: 0.0,
        source: RunTrackPointSource.gps,
      );

      tracker.addPoint(point);

      await Future.delayed(Duration.zero);

      expect(points.length, 1);
      expect(points[0].latitude, 37.7749);

      tracker.stop();
    });

    test('duplicate start does not throw', () {
      final tracker = FakeRunLocationTracker();
      tracker.start();
      expect(() => tracker.start(), returnsNormally);
      tracker.stop();
    });
  });

  group('ActiveRunController lifecycle', () {
    late FakeRunLocationTracker fakeTracker;
    late FakeClock fakeClock;
    late ProviderContainer container;

    setUp(() {
      fakeTracker = FakeRunLocationTracker();
      fakeClock = FakeClock(DateTime(2026, 4, 25, 10, 0, 0));
    });

    tearDown(() {
      container.dispose();
    });

    test('controller can be instantiated via provider', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      expect(controller, isNotNull);
    });

    test('initial state is correct', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final state = container.read(activeRunControllerProvider);
      expect(state.session, null);
      expect(state.elapsed, Duration.zero);
      expect(state.isPaused, false);
    });
  });

  group('ActiveRunController start behavior', () {
    late FakeRunLocationTracker fakeTracker;
    late FakeClock fakeClock;
    late ProviderContainer container;

    setUp(() {
      fakeTracker = FakeRunLocationTracker();
      fakeClock = FakeClock(DateTime(2026, 4, 25, 10, 0, 0));
    });

    tearDown(() {
      container.dispose();
    });

    test('start sets session and resets state', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      final session = createTestSession();

      controller.start(
        ActiveRunStartInput(
          session: session,
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      final state = container.read(activeRunControllerProvider);
      expect(state.session, isNotNull);
      expect(state.session?.sessionId, 'test-session-1');
    });

    test('start with timerOnlyMode disables GPS', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      final session = createTestSession();

      controller.start(
        ActiveRunStartInput(
          session: session,
          checkIn: null,
          timerOnlyMode: true,
        ),
      );

      final state = container.read(activeRunControllerProvider);
      expect(state.gpsStatus, GpsStatus.disabled);
      expect(state.isTimerOnlyMode, true);
    });

    test('start sets gpsStatus to acquiring in GPS mode', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      final session = createTestSession();

      controller.start(
        ActiveRunStartInput(
          session: session,
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      final state = container.read(activeRunControllerProvider);
      expect(state.gpsStatus, GpsStatus.acquiring);
    });

    test('start with null session sets error', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);

      controller.start(
        const ActiveRunStartInput(
          session: null,
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      final state = container.read(activeRunControllerProvider);
      expect(state.error, isNotNull);
    });

    test('repeated start for the same active run preserves progress', () async {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      final session = createTestSession();
      final input = ActiveRunStartInput(
        session: session,
        checkIn: null,
        timerOnlyMode: false,
      );

      await controller.start(input);
      controller.tickClock();
      controller.tickClock();

      final stateBeforeRestart = container.read(activeRunControllerProvider);
      expect(stateBeforeRestart.elapsed, const Duration(seconds: 2));

      await controller.start(input);

      final stateAfterRestart = container.read(activeRunControllerProvider);
      expect(stateAfterRestart.session?.sessionId, session.sessionId);
      expect(stateAfterRestart.elapsed, const Duration(seconds: 2));
      expect(stateAfterRestart.timelineIndex, 0);
    });
  });

  group('ActiveRunController pause behavior', () {
    late FakeRunLocationTracker fakeTracker;
    late FakeClock fakeClock;
    late ProviderContainer container;

    setUp(() {
      fakeTracker = FakeRunLocationTracker();
      fakeClock = FakeClock(DateTime(2026, 4, 25, 10, 0, 0));
    });

    tearDown(() {
      container.dispose();
    });

    test('pause sets isPaused to true', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      controller.pause();

      final state = container.read(activeRunControllerProvider);
      expect(state.isPaused, true);
    });

    test('pause clears modal intent', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      controller.pause();

      final state = container.read(activeRunControllerProvider);
      expect(state.modalIntent, ActiveRunModalIntent.none);
    });

    test('pause is idempotent', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      controller.pause();
      controller.pause();

      final state = container.read(activeRunControllerProvider);
      expect(state.isPaused, true);
    });
  });

  group('ActiveRunController resume behavior', () {
    late FakeRunLocationTracker fakeTracker;
    late FakeClock fakeClock;
    late ProviderContainer container;

    setUp(() {
      fakeTracker = FakeRunLocationTracker();
      fakeClock = FakeClock(DateTime(2026, 4, 25, 10, 0, 0));
    });

    tearDown(() {
      container.dispose();
    });

    test('resume sets isPaused to false', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      controller.pause();
      controller.resume();

      final state = container.read(activeRunControllerProvider);
      expect(state.isPaused, false);
    });

    test('resume clears modal intent', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      controller.pause();
      controller.resume();

      final state = container.read(activeRunControllerProvider);
      expect(state.modalIntent, ActiveRunModalIntent.none);
    });

    test('resume is idempotent when not paused', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      controller.resume();
      controller.resume();

      final state = container.read(activeRunControllerProvider);
      expect(state.isPaused, false);
    });
  });

  group('ActiveRunController finish behavior', () {
    late FakeRunLocationTracker fakeTracker;
    late FakeClock fakeClock;
    late ProviderContainer container;

    setUp(() {
      fakeTracker = FakeRunLocationTracker();
      fakeClock = FakeClock(DateTime(2026, 4, 25, 10, 0, 0));
    });

    tearDown(() {
      container.dispose();
    });

    test('finish returns ActiveRunFinishResult', () async {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      final result = await controller.finish();

      expect(result, isA<ActiveRunFinishResult>());
      expect(result.session, isNotNull);
    });

    test('finish sets isPaused to true', () async {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      await controller.finish();

      final state = container.read(activeRunControllerProvider);
      expect(state.isPaused, true);
    });

    test('finish clears modal intent', () async {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      await controller.finish();

      final state = container.read(activeRunControllerProvider);
      expect(state.modalIntent, ActiveRunModalIntent.none);
    });
  });

  group('ActiveRunController GPS handling', () {
    late FakeRunLocationTracker fakeTracker;
    late FakeClock fakeClock;
    late ProviderContainer container;

    setUp(() {
      fakeTracker = FakeRunLocationTracker();
      fakeClock = FakeClock(DateTime(2026, 4, 25, 10, 0, 0));
    });

    tearDown(() {
      container.dispose();
    });

    test('GPS points ignored while paused', () async {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      controller.pause();

      final pausedState = container.read(activeRunControllerProvider);

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: fakeClock.now,
          accuracy: 10.0,
          altitude: 100.0,
          speed: 5.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );

      await Future.delayed(Duration.zero);

      final stateAfterPoint = container.read(activeRunControllerProvider);
      expect(stateAfterPoint.distanceKm, pausedState.distanceKm);
    });

    test('GPS points update routePointCount when not paused', () async {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: fakeClock.now,
          accuracy: 10.0,
          altitude: 100.0,
          speed: 5.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );

      await Future.delayed(Duration.zero);

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7750,
          longitude: -122.4195,
          timestamp: fakeClock.now.add(const Duration(seconds: 10)),
          accuracy: 10.0,
          altitude: 100.0,
          speed: 5.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );

      await Future.delayed(Duration.zero);

      final state = container.read(activeRunControllerProvider);
      expect(state.routePointCount, 1);
    });

    test('resume preserves prior GPS distance and avoids pause jump', () async {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: fakeClock.now,
          accuracy: 10.0,
          altitude: 100.0,
          speed: 5.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );
      await Future.delayed(Duration.zero);

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7759,
          longitude: -122.4194,
          timestamp: fakeClock.now.add(const Duration(seconds: 20)),
          accuracy: 10.0,
          altitude: 100.0,
          speed: 5.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );
      await Future.delayed(Duration.zero);

      final distanceBeforePause = container
          .read(activeRunControllerProvider)
          .distanceKm;
      expect(distanceBeforePause, greaterThan(0));

      controller.pause();
      controller.resume();

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7769,
          longitude: -122.4194,
          timestamp: fakeClock.now.add(const Duration(seconds: 40)),
          accuracy: 10.0,
          altitude: 100.0,
          speed: 5.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );
      await Future.delayed(Duration.zero);

      expect(
        container.read(activeRunControllerProvider).distanceKm,
        distanceBeforePause,
      );

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7779,
          longitude: -122.4194,
          timestamp: fakeClock.now.add(const Duration(seconds: 60)),
          accuracy: 10.0,
          altitude: 100.0,
          speed: 5.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );
      await Future.delayed(Duration.zero);

      final distanceAfterResume = container
          .read(activeRunControllerProvider)
          .distanceKm;
      expect(distanceAfterResume, greaterThan(distanceBeforePause));
    });

    test(
      'distance block completion carries overshoot into next distance block',
      () async {
        container = ProviderContainer(
          overrides: [
            locationTrackerProvider.overrideWith((ref) => fakeTracker),
            clockProvider.overrideWith(
              (ref) =>
                  () => fakeClock.now,
            ),
          ],
        );

        final session = RunFlowSessionContext(
          sessionId: 'distance-overshoot-session',
          sessionDate: DateTime(2026, 4, 25),
          sessionType: SessionType.intervals,
          weekNumber: 1,
          workoutTarget: WorkoutTarget.pace(TargetZone.interval),
          workoutSteps: [
            WorkoutStep.work(
              distanceMeters: 400,
              target: const WorkoutTarget.pace(TargetZone.interval),
            ),
            WorkoutStep.recovery(
              distanceMeters: 400,
              target: const WorkoutTarget.effort(TargetZone.recovery),
            ),
          ],
          supplementalType: null,
          isRunSession: true,
          distanceKm: 0.8,
          durationMinutes: null,
          elevationGainMeters: null,
          intervalReps: null,
          intervalRepDistanceMeters: null,
          intervalRecoverySeconds: null,
          warmUpMinutes: null,
          coolDownMinutes: null,
        );

        final controller = container.read(activeRunControllerProvider.notifier);
        controller.start(
          ActiveRunStartInput(
            session: session,
            checkIn: null,
            timerOnlyMode: false,
          ),
        );

        fakeTracker.addPoint(
          RunTrackPoint(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: fakeClock.now,
            accuracy: 10.0,
            altitude: 100.0,
            speed: 0.0,
            heading: 0.0,
            source: RunTrackPointSource.gps,
          ),
        );
        await Future.delayed(Duration.zero);

        fakeTracker.addPoint(
          RunTrackPoint(
            latitude: 37.7787,
            longitude: -122.4194,
            timestamp: fakeClock.now.add(const Duration(seconds: 60)),
            accuracy: 10.0,
            altitude: 100.0,
            speed: 7.0,
            heading: 0.0,
            source: RunTrackPointSource.gps,
          ),
        );
        await Future.delayed(Duration.zero);

        final state = container.read(activeRunControllerProvider);
        expect(state.timelineIndex, 1);
        expect(state.currentBlock?.distanceMeters, 400);
        expect(state.blockDistanceKm, greaterThan(0));
        expect(state.blockDistanceKm, lessThan(0.05));
      },
    );
  });

  group('ActiveRunController dismissModal', () {
    late FakeRunLocationTracker fakeTracker;
    late FakeClock fakeClock;
    late ProviderContainer container;

    setUp(() {
      fakeTracker = FakeRunLocationTracker();
      fakeClock = FakeClock(DateTime(2026, 4, 25, 10, 0, 0));
    });

    tearDown(() {
      container.dispose();
    });

    test('dismissModal clears modal intent', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      controller.dismissModal();

      final state = container.read(activeRunControllerProvider);
      expect(state.modalIntent, ActiveRunModalIntent.none);
    });
  });

  group('ActiveRunController endRun', () {
    late FakeRunLocationTracker fakeTracker;
    late FakeClock fakeClock;
    late ProviderContainer container;

    setUp(() {
      fakeTracker = FakeRunLocationTracker();
      fakeClock = FakeClock(DateTime(2026, 4, 25, 10, 0, 0));
    });

    tearDown(() {
      container.dispose();
    });

    test('endRun pauses and stops tracker', () async {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      await controller.endRun();

      final state = container.read(activeRunControllerProvider);
      expect(state.isPaused, true);
    });
  });

  group('ActiveRunController timer-only restrictions', () {
    late FakeRunLocationTracker fakeTracker;
    late FakeClock fakeClock;
    late ProviderContainer container;

    setUp(() {
      fakeTracker = FakeRunLocationTracker();
      fakeClock = FakeClock(DateTime(2026, 4, 25, 10, 0, 0));
    });

    tearDown(() {
      container.dispose();
    });

    test('start with timerOnlyMode and no distance blocks succeeds', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      final session = createTestSession();

      controller.start(
        ActiveRunStartInput(
          session: session,
          checkIn: null,
          timerOnlyMode: true,
        ),
      );

      final state = container.read(activeRunControllerProvider);
      expect(state.isTimerOnlyMode, true);
      expect(state.error, isNull);
    });

    test(
      'start with timerOnlyMode and distance blocks sets error and modalIntent',
      () {
        container = ProviderContainer(
          overrides: [
            locationTrackerProvider.overrideWith((ref) => fakeTracker),
            clockProvider.overrideWith(
              (ref) =>
                  () => fakeClock.now,
            ),
          ],
        );

        final controller = container.read(activeRunControllerProvider.notifier);
        final distanceSession = RunFlowSessionContext(
          sessionId: 'distance-session',
          sessionDate: DateTime(2026, 4, 25),
          sessionType: SessionType.intervals,
          weekNumber: 1,
          workoutTarget: WorkoutTarget.pace(TargetZone.interval),
          workoutSteps: [
            WorkoutStep.work(
              distanceMeters: 400,
              target: const WorkoutTarget.pace(TargetZone.interval),
            ),
          ],
          supplementalType: null,
          isRunSession: true,
          distanceKm: 5.0,
          durationMinutes: 30,
          elevationGainMeters: 50,
          intervalReps: null,
          intervalRepDistanceMeters: null,
          intervalRecoverySeconds: null,
          warmUpMinutes: null,
          coolDownMinutes: null,
        );

        controller.start(
          ActiveRunStartInput(
            session: distanceSession,
            checkIn: null,
            timerOnlyMode: true,
          ),
        );

        final state = container.read(activeRunControllerProvider);
        expect(
          state.error,
          'Timer-only mode is not supported for distance-based workouts',
        );
        expect(state.modalIntent, ActiveRunModalIntent.timerOnlyRestriction);
      },
    );

    test('start with timerOnlyMode false and distance blocks succeeds', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      final distanceSession = RunFlowSessionContext(
        sessionId: 'distance-session',
        sessionDate: DateTime(2026, 4, 25),
        sessionType: SessionType.intervals,
        weekNumber: 1,
        workoutTarget: WorkoutTarget.pace(TargetZone.interval),
        workoutSteps: [
          WorkoutStep.work(
            distanceMeters: 400,
            target: const WorkoutTarget.pace(TargetZone.interval),
          ),
        ],
        supplementalType: null,
        isRunSession: true,
        distanceKm: 5.0,
        durationMinutes: 30,
        elevationGainMeters: 50,
        intervalReps: null,
        intervalRepDistanceMeters: null,
        intervalRecoverySeconds: null,
        warmUpMinutes: null,
        coolDownMinutes: null,
      );

      controller.start(
        ActiveRunStartInput(
          session: distanceSession,
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      final state = container.read(activeRunControllerProvider);
      expect(state.error, isNull);
      expect(state.isTimerOnlyMode, false);
    });
  });

  group('ActiveRunController GPS lost handling', () {
    late FakeRunLocationTracker fakeTracker;
    late FakeClock fakeClock;
    late ProviderContainer container;

    setUp(() {
      fakeTracker = FakeRunLocationTracker();
      fakeClock = FakeClock(DateTime(2026, 4, 25, 10, 0, 0));
    });

    tearDown(() {
      container.dispose();
    });

    RunFlowSessionContext createDistanceBlockSession() {
      return RunFlowSessionContext(
        sessionId: 'distance-session',
        sessionDate: DateTime(2026, 4, 25),
        sessionType: SessionType.intervals,
        weekNumber: 1,
        workoutTarget: WorkoutTarget.pace(TargetZone.interval),
        workoutSteps: [
          WorkoutStep.work(
            distanceMeters: 400,
            target: const WorkoutTarget.pace(TargetZone.interval),
          ),
        ],
        supplementalType: null,
        isRunSession: true,
        distanceKm: 5.0,
        durationMinutes: 30,
        elevationGainMeters: 50,
        intervalReps: null,
        intervalRepDistanceMeters: null,
        intervalRecoverySeconds: null,
        warmUpMinutes: null,
        coolDownMinutes: null,
      );
    }

    RunFlowSessionContext createDurationBlockSession() {
      return RunFlowSessionContext(
        sessionId: 'duration-session',
        sessionDate: DateTime(2026, 4, 25),
        sessionType: SessionType.easyRun,
        weekNumber: 1,
        workoutTarget: WorkoutTarget.effort(TargetZone.easy),
        workoutSteps: [
          WorkoutStep.work(
            duration: const Duration(minutes: 20),
            target: const WorkoutTarget.effort(TargetZone.easy),
          ),
        ],
        supplementalType: null,
        isRunSession: true,
        distanceKm: 5.0,
        durationMinutes: 30,
        elevationGainMeters: 50,
        intervalReps: null,
        intervalRepDistanceMeters: null,
        intervalRecoverySeconds: null,
        warmUpMinutes: null,
        coolDownMinutes: null,
      );
    }

    test(
      'GPS lost during distance-based block triggers auto-pause and gpsLostAutoPause modal',
      () async {
        container = ProviderContainer(
          overrides: [
            locationTrackerProvider.overrideWith((ref) => fakeTracker),
            clockProvider.overrideWith(
              (ref) =>
                  () => fakeClock.now,
            ),
          ],
        );

        final controller = container.read(activeRunControllerProvider.notifier);
        controller.start(
          ActiveRunStartInput(
            session: createDistanceBlockSession(),
            checkIn: null,
            timerOnlyMode: false,
          ),
        );

        fakeTracker.addPoint(
          RunTrackPoint(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: fakeClock.now,
            accuracy: 10.0,
            altitude: 100.0,
            speed: 5.0,
            heading: 0.0,
            source: RunTrackPointSource.gps,
          ),
        );

        await Future.delayed(Duration.zero);

        fakeTracker.addPoint(
          RunTrackPoint(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: fakeClock.now,
            accuracy: 100.0,
            altitude: 100.0,
            speed: 0.0,
            heading: 0.0,
            source: RunTrackPointSource.gps,
          ),
        );

        await Future.delayed(Duration.zero);

        final state = container.read(activeRunControllerProvider);
        expect(state.isPaused, true);
        expect(state.modalIntent, ActiveRunModalIntent.gpsLostAutoPause);
      },
    );

    test(
      'GPS lost during duration-based block shows gpsLostWarning modal without auto-pause',
      () async {
        container = ProviderContainer(
          overrides: [
            locationTrackerProvider.overrideWith((ref) => fakeTracker),
            clockProvider.overrideWith(
              (ref) =>
                  () => fakeClock.now,
            ),
          ],
        );

        final controller = container.read(activeRunControllerProvider.notifier);
        controller.start(
          ActiveRunStartInput(
            session: createDurationBlockSession(),
            checkIn: null,
            timerOnlyMode: false,
          ),
        );

        fakeTracker.addPoint(
          RunTrackPoint(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: fakeClock.now,
            accuracy: 10.0,
            altitude: 100.0,
            speed: 5.0,
            heading: 0.0,
            source: RunTrackPointSource.gps,
          ),
        );

        await Future.delayed(Duration.zero);

        fakeTracker.addPoint(
          RunTrackPoint(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: fakeClock.now,
            accuracy: 100.0,
            altitude: 100.0,
            speed: 0.0,
            heading: 0.0,
            source: RunTrackPointSource.gps,
          ),
        );

        await Future.delayed(Duration.zero);

        final state = container.read(activeRunControllerProvider);
        expect(state.isPaused, false);
        expect(state.modalIntent, ActiveRunModalIntent.gpsLostWarning);
      },
    );

    test('No duplicate modals when GPS stays lost', () async {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createDistanceBlockSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: fakeClock.now,
          accuracy: 10.0,
          altitude: 100.0,
          speed: 5.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );

      await Future.delayed(Duration.zero);

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: fakeClock.now,
          accuracy: 100.0,
          altitude: 100.0,
          speed: 0.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );

      await Future.delayed(Duration.zero);

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: fakeClock.now,
          accuracy: 100.0,
          altitude: 100.0,
          speed: 0.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );

      await Future.delayed(Duration.zero);

      final state = container.read(activeRunControllerProvider);
      expect(state.modalIntent, ActiveRunModalIntent.gpsLostAutoPause);
    });

    test(
      'Resume requires user action after auto-pause due to GPS lost',
      () async {
        container = ProviderContainer(
          overrides: [
            locationTrackerProvider.overrideWith((ref) => fakeTracker),
            clockProvider.overrideWith(
              (ref) =>
                  () => fakeClock.now,
            ),
          ],
        );

        final controller = container.read(activeRunControllerProvider.notifier);
        controller.start(
          ActiveRunStartInput(
            session: createDistanceBlockSession(),
            checkIn: null,
            timerOnlyMode: false,
          ),
        );

        fakeTracker.addPoint(
          RunTrackPoint(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: fakeClock.now,
            accuracy: 10.0,
            altitude: 100.0,
            speed: 5.0,
            heading: 0.0,
            source: RunTrackPointSource.gps,
          ),
        );

        await Future.delayed(Duration.zero);

        fakeTracker.addPoint(
          RunTrackPoint(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: fakeClock.now,
            accuracy: 100.0,
            altitude: 100.0,
            speed: 0.0,
            heading: 0.0,
            source: RunTrackPointSource.gps,
          ),
        );

        await Future.delayed(Duration.zero);

        var state = container.read(activeRunControllerProvider);
        expect(state.isPaused, true);

        fakeTracker.addPoint(
          RunTrackPoint(
            latitude: 37.7750,
            longitude: -122.4195,
            timestamp: fakeClock.now,
            accuracy: 10.0,
            altitude: 100.0,
            speed: 5.0,
            heading: 0.0,
            source: RunTrackPointSource.gps,
          ),
        );

        await Future.delayed(Duration.zero);

        state = container.read(activeRunControllerProvider);
        expect(state.isPaused, true);
        expect(state.modalIntent, ActiveRunModalIntent.gpsLostAutoPause);

        controller.resume();

        state = container.read(activeRunControllerProvider);
        expect(state.isPaused, false);
        expect(state.modalIntent, ActiveRunModalIntent.none);
      },
    );

    test('GPS points ignored while paused due to GPS lost', () async {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createDistanceBlockSession(),
          checkIn: null,
          timerOnlyMode: false,
        ),
      );

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: fakeClock.now,
          accuracy: 10.0,
          altitude: 100.0,
          speed: 5.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );

      await Future.delayed(Duration.zero);

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: fakeClock.now,
          accuracy: 100.0,
          altitude: 100.0,
          speed: 0.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );

      await Future.delayed(Duration.zero);

      final pausedState = container.read(activeRunControllerProvider);
      expect(pausedState.isPaused, true);

      final routePointCountBefore = pausedState.routePointCount;

      fakeTracker.addPoint(
        RunTrackPoint(
          latitude: 37.7750,
          longitude: -122.4195,
          timestamp: fakeClock.now,
          accuracy: 10.0,
          altitude: 100.0,
          speed: 5.0,
          heading: 0.0,
          source: RunTrackPointSource.gps,
        ),
      );

      await Future.delayed(Duration.zero);

      final stateAfterPoint = container.read(activeRunControllerProvider);
      expect(stateAfterPoint.routePointCount, routePointCountBefore);
      expect(stateAfterPoint.isPaused, true);
    });
  });

  group('ActiveRunController timer tick with FakeClock', () {
    late FakeRunLocationTracker fakeTracker;
    late FakeClock fakeClock;
    late ProviderContainer container;

    setUp(() {
      fakeTracker = FakeRunLocationTracker();
      fakeClock = FakeClock(DateTime(2026, 4, 25, 10, 0, 0));
    });

    tearDown(() {
      container.dispose();
    });

    test('tickClock advances elapsed time deterministically', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: true,
        ),
      );

      expect(
        container.read(activeRunControllerProvider).elapsed,
        Duration.zero,
      );

      controller.tickClock();
      expect(
        container.read(activeRunControllerProvider).elapsed,
        const Duration(seconds: 1),
      );

      controller.tickClock();
      expect(
        container.read(activeRunControllerProvider).elapsed,
        const Duration(seconds: 2),
      );

      controller.tickClock();
      expect(
        container.read(activeRunControllerProvider).elapsed,
        const Duration(seconds: 3),
      );
    });

    test('tickClock advances duration-based block elapsed', () {
      container = ProviderContainer(
        overrides: [
          locationTrackerProvider.overrideWith((ref) => fakeTracker),
          clockProvider.overrideWith(
            (ref) =>
                () => fakeClock.now,
          ),
        ],
      );

      final controller = container.read(activeRunControllerProvider.notifier);
      controller.start(
        ActiveRunStartInput(
          session: createTestSession(),
          checkIn: null,
          timerOnlyMode: true,
        ),
      );

      controller.tickClock();
      controller.tickClock();
      controller.tickClock();

      final state = container.read(activeRunControllerProvider);
      expect(state.elapsed, const Duration(seconds: 3));
      expect(state.blockElapsed, const Duration(seconds: 3));
    });
  });
}
