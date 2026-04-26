import 'package:flutter_test/flutter_test.dart';
import 'package:running_app/features/active_run/domain/models/gps_state.dart';
import 'package:running_app/features/active_run/domain/run_live_activity_data.dart';
import 'package:running_app/features/active_run/presentation/active_run_live_activity_sync.dart';
import 'package:running_app/features/active_run/presentation/run_live_activity_bridge.dart';
import 'package:running_app/features/active_run/presentation/run_live_activity_background_service.dart';

FakeBridge createFakeBridge() => FakeBridge();
FakeBackgroundService createFakeService() => FakeBackgroundService();

RunLiveActivityData createPayload({
  double distanceKm = 1.0,
  int paceSecondsPerKm = 300,
  String currentBlockLabel = 'Work',
  String? nextBlockLabel,
  String? repLabel,
  bool isPaused = false,
  double blockProgressFraction = 0.0,
  List<RunLiveActivityTimelineBlock>? timeline,
}) {
  return RunLiveActivityData(
    workoutName: 'Easy Run',
    elapsedSeconds: 600,
    elapsedLabel: '10:00',
    distanceLabel: '1.0',
    currentPaceTitleLabel: 'Pace',
    currentPaceLabel: '5:00',
    avgPaceTitleLabel: 'Avg',
    avgPaceLabel: '5:30',
    currentBlockLabel: currentBlockLabel,
    nextBlockLabel: nextBlockLabel,
    repLabel: repLabel,
    isPaused: isPaused,
    distanceKm: distanceKm,
    paceSecondsPerKm: paceSecondsPerKm,
    unitFactor: 1.0,
    distanceUnit: 'km',
    paceUnit: 'min/km',
    blockProgressFraction: blockProgressFraction,
    timeline: timeline,
  );
}

RunLiveActivityTimelineBlock timelineBlock(String label) =>
    RunLiveActivityTimelineBlock(blockLabel: label);

class FakeBridge implements RunLiveActivityBridgePort {
  final List<RunLiveActivityData> startCalls = [];
  final List<RunLiveActivityData> updateCalls = [];
  final List<void> endCalls = [];
  bool shouldThrowStart = false;
  bool shouldThrowUpdate = false;
  bool shouldThrowEnd = false;

  @override
  Future<void> startActivity(RunLiveActivityData data) async {
    startCalls.add(data);
    if (shouldThrowStart) throw Exception('bridge start error');
  }

  @override
  Future<void> updateActivity(RunLiveActivityData data) async {
    updateCalls.add(data);
    if (shouldThrowUpdate) throw Exception('bridge update error');
  }

  @override
  Future<void> endActivity() async {
    endCalls.add(null);
    if (shouldThrowEnd) throw Exception('bridge end error');
  }

  @override
  Stream<void> get focusActiveRunEvents => const Stream.empty();

  @override
  Stream<RunServiceEvent> events() => const Stream.empty();

  @override
  Future<RunServiceState?> getRunState() async => null;

  @override
  void initNativeCallHandler() {}

  void reset() {
    startCalls.clear();
    updateCalls.clear();
    endCalls.clear();
    shouldThrowStart = false;
    shouldThrowUpdate = false;
    shouldThrowEnd = false;
  }
}

class FakeBackgroundService implements RunLiveActivityBackgroundServicePort {
  final List<RunLiveActivityData> startCalls = [];
  final List<RunLiveActivityData> updateCalls = [];
  final List<void> stopCalls = [];
  bool shouldThrowStart = false;
  bool shouldThrowUpdate = false;
  bool shouldThrowStop = false;

  @override
  Future<void> start(RunLiveActivityData data) async {
    startCalls.add(data);
    if (shouldThrowStart) throw Exception('service start error');
  }

  @override
  Future<void> update(RunLiveActivityData data) async {
    updateCalls.add(data);
    if (shouldThrowUpdate) throw Exception('service update error');
  }

  @override
  Future<void> stop() async {
    stopCalls.add(null);
    if (shouldThrowStop) throw Exception('service stop error');
  }

  @override
  Future<void> configure() async {}

  void reset() {
    startCalls.clear();
    updateCalls.clear();
    stopCalls.clear();
    shouldThrowStart = false;
    shouldThrowUpdate = false;
    shouldThrowStop = false;
  }
}

void main() {
  group('ActiveRunLiveActivitySync', () {
    late FakeBridge bridge;
    late FakeBackgroundService service;
    late ActiveRunLiveActivitySync sync;

    setUp(() {
      bridge = createFakeBridge();
      service = createFakeService();
    });

    ActiveRunLiveActivitySync createSync({SyncClock? clock}) {
      return ActiveRunLiveActivitySync(
        bridge: bridge,
        backgroundService: service,
        clock: clock ?? (() => DateTime.now()),
      );
    }

    test('first sync starts bridge and background service', () async {
      sync = createSync();
      final data = createPayload();

      await sync.sync(data: data, timelineIndex: 0);

      expect(bridge.startCalls.length, 1);
      expect(bridge.startCalls[0].distanceKm, 1.0);
      expect(service.startCalls.length, 1);
      expect(service.startCalls[0].distanceKm, 1.0);
    });

    test('repeated same payload does not update', () async {
      sync = createSync();
      final data = createPayload();

      await sync.sync(data: data, timelineIndex: 0);
      await sync.sync(data: data, timelineIndex: 0);

      expect(bridge.startCalls.length, 1);
      expect(bridge.updateCalls.length, 0);
      expect(service.startCalls.length, 1);
      expect(service.updateCalls.length, 0);
    });

    test(
      'distance-only change before throttle does not update unless threshold '
      'exceeded',
      () async {
        var clockTime = DateTime(2026, 4, 25, 10, 0, 0);
        sync = createSync(clock: () => clockTime);

        final data1 = createPayload(distanceKm: 1.0, paceSecondsPerKm: 300);
        await sync.sync(data: data1, timelineIndex: 0);

        expect(bridge.startCalls.length, 1);
        expect(bridge.updateCalls.length, 0);
        expect(service.startCalls.length, 1);
        expect(service.updateCalls.length, 0);

        final data2 = createPayload(distanceKm: 1.005, paceSecondsPerKm: 300);
        await sync.sync(data: data2, timelineIndex: 0);

        expect(bridge.updateCalls.length, 0);
        expect(service.updateCalls.length, 0);

        final data3 = createPayload(distanceKm: 1.015, paceSecondsPerKm: 300);
        await sync.sync(data: data3, timelineIndex: 0);

        expect(bridge.updateCalls.length, 1);
        expect(service.updateCalls.length, 1);
      },
    );

    test('distance-only change after 3 seconds updates', () async {
      var clockTime = DateTime(2026, 4, 25, 10, 0, 0);
      sync = createSync(clock: () => clockTime);

      final data1 = createPayload(distanceKm: 1.0, paceSecondsPerKm: 300);
      await sync.sync(data: data1, timelineIndex: 0);

      bridge.reset();
      service.reset();

      clockTime = DateTime(2026, 4, 25, 10, 0, 4);
      final data2 = createPayload(distanceKm: 1.1, paceSecondsPerKm: 300);
      await sync.sync(data: data2, timelineIndex: 0);

      expect(bridge.updateCalls.length, 1);
      expect(service.updateCalls.length, 1);
    });

    test(
      'no-op payload after 3 seconds does NOT update (throttle requires real delta)',
      () async {
        var clockTime = DateTime(2026, 4, 25, 10, 0, 0);
        sync = createSync(clock: () => clockTime);

        final data = createPayload(distanceKm: 1.0, paceSecondsPerKm: 300);
        await sync.sync(data: data, timelineIndex: 0);

        bridge.reset();
        service.reset();

        clockTime = DateTime(2026, 4, 25, 10, 0, 5);
        await sync.sync(data: data, timelineIndex: 0);

        expect(bridge.updateCalls.length, 0);
        expect(service.updateCalls.length, 0);
      },
    );

    test('pause change updates immediately', () async {
      sync = createSync();

      final runningData = createPayload(isPaused: false);
      await sync.sync(data: runningData, timelineIndex: 0);

      bridge.reset();
      service.reset();

      final pausedData = createPayload(isPaused: true);
      await sync.sync(data: pausedData, timelineIndex: 0);

      expect(bridge.updateCalls.length, 1);
      expect(service.updateCalls.length, 1);
    });

    test('resume change updates immediately', () async {
      sync = createSync();

      final pausedData = createPayload(isPaused: true);
      await sync.sync(data: pausedData, timelineIndex: 0);

      bridge.reset();
      service.reset();

      final runningData = createPayload(isPaused: false);
      await sync.sync(data: runningData, timelineIndex: 0);

      expect(bridge.updateCalls.length, 1);
      expect(service.updateCalls.length, 1);
    });

    test('block label change triggers immediate update', () async {
      sync = createSync();

      final data1 = createPayload(currentBlockLabel: 'Work');
      await sync.sync(data: data1, timelineIndex: 0);

      bridge.reset();
      service.reset();

      final data2 = createPayload(currentBlockLabel: 'Recovery');
      await sync.sync(data: data2, timelineIndex: 1);

      expect(bridge.updateCalls.length, 1);
      expect(service.updateCalls.length, 1);
    });

    test('finish calls end/stop once', () async {
      sync = createSync();

      await sync.sync(data: createPayload(), timelineIndex: 0);

      await sync.end();
      await sync.end();

      expect(bridge.endCalls.length, 1);
      expect(service.stopCalls.length, 1);
    });

    test('sync ignores calls after end', () async {
      sync = createSync();

      await sync.sync(data: createPayload(), timelineIndex: 0);
      await sync.end();

      bridge.reset();
      service.reset();

      await sync.sync(data: createPayload(distanceKm: 2.0), timelineIndex: 0);

      expect(bridge.startCalls.length, 0);
      expect(bridge.updateCalls.length, 0);
      expect(service.startCalls.length, 0);
      expect(service.updateCalls.length, 0);
    });

    test('platform exceptions are swallowed and do not fail sync', () async {
      sync = createSync();
      service.shouldThrowStart = true;

      final data = createPayload();

      await sync.sync(data: data, timelineIndex: 0);

      expect(bridge.startCalls.length, 1);
      expect(service.startCalls.length, 1);
    });

    test('platform exceptions on update are swallowed', () async {
      sync = createSync();

      await sync.sync(data: createPayload(), timelineIndex: 0);

      bridge.shouldThrowUpdate = true;
      service.shouldThrowUpdate = true;
      bridge.reset();
      service.reset();

      final data2 = createPayload(distanceKm: 2.0);
      await sync.sync(data: data2, timelineIndex: 0);

      expect(bridge.updateCalls.length, 1);
      expect(service.updateCalls.length, 1);
    });

    test('platform exceptions on end are swallowed', () async {
      sync = createSync();

      await sync.sync(data: createPayload(), timelineIndex: 0);

      service.shouldThrowStop = true;

      await sync.end();

      expect(bridge.endCalls.length, 1);
      expect(service.stopCalls.length, 1);
    });

    test('rep label change triggers immediate update', () async {
      sync = createSync();

      await sync.sync(data: createPayload(), timelineIndex: 0);

      bridge.reset();
      service.reset();

      await sync.sync(data: createPayload(repLabel: '2 / 5'), timelineIndex: 0);

      expect(bridge.updateCalls.length, 1);
      expect(service.updateCalls.length, 1);
    });

    test('next block label change triggers immediate update', () async {
      sync = createSync();

      await sync.sync(data: createPayload(), timelineIndex: 0);

      bridge.reset();
      service.reset();

      await sync.sync(
        data: createPayload(nextBlockLabel: 'Cool-down'),
        timelineIndex: 0,
      );

      expect(bridge.updateCalls.length, 1);
      expect(service.updateCalls.length, 1);
    });

    test(
      'timeline index change triggers immediate update even with same label',
      () async {
        // Repeating label simulates intervals: Recovery between reps.
        sync = createSync();

        final data1 = createPayload(
          currentBlockLabel: 'Recovery',
          timeline: [
            timelineBlock('Work'),
            timelineBlock('Recovery'),
            timelineBlock('Work'),
            timelineBlock('Recovery'),
          ],
        );
        await sync.sync(data: data1, timelineIndex: 1);

        bridge.reset();
        service.reset();

        // Same label, different index — must update.
        final data2 = createPayload(
          currentBlockLabel: 'Recovery',
          timeline: [
            timelineBlock('Work'),
            timelineBlock('Recovery'),
            timelineBlock('Work'),
            timelineBlock('Recovery'),
          ],
        );
        await sync.sync(data: data2, timelineIndex: 3);

        expect(bridge.updateCalls.length, 1);
        expect(service.updateCalls.length, 1);
      },
    );

    test(
      'pace change below threshold before 3 seconds does not update',
      () async {
        var clockTime = DateTime(2026, 4, 25, 10, 0, 0);
        sync = createSync(clock: () => clockTime);

        final data1 = createPayload(distanceKm: 1.0, paceSecondsPerKm: 300);
        await sync.sync(data: data1, timelineIndex: 0);

        bridge.reset();
        service.reset();

        final data2 = createPayload(distanceKm: 1.0, paceSecondsPerKm: 305);
        await sync.sync(data: data2, timelineIndex: 0);

        expect(bridge.updateCalls.length, 0);
        expect(service.updateCalls.length, 0);
      },
    );

    test(
      'pace change above threshold triggers update even before 3 seconds',
      () async {
        var clockTime = DateTime(2026, 4, 25, 10, 0, 0);
        sync = createSync(clock: () => clockTime);

        final data1 = createPayload(distanceKm: 1.0, paceSecondsPerKm: 300);
        await sync.sync(data: data1, timelineIndex: 0);

        bridge.reset();
        service.reset();

        final data2 = createPayload(distanceKm: 1.0, paceSecondsPerKm: 320);
        await sync.sync(data: data2, timelineIndex: 0);

        expect(bridge.updateCalls.length, 1);
        expect(service.updateCalls.length, 1);
      },
    );

    test(
      'block progress fraction change goes through throttle logic',
      () async {
        var clockTime = DateTime(2026, 4, 25, 10, 0, 0);
        sync = createSync(clock: () => clockTime);

        final data1 = createPayload(blockProgressFraction: 0.5);
        await sync.sync(data: data1, timelineIndex: 0);

        bridge.reset();
        service.reset();

        final data2 = createPayload(blockProgressFraction: 0.7);
        await sync.sync(data: data2, timelineIndex: 0);

        expect(bridge.updateCalls.length, 0);
        expect(service.updateCalls.length, 0);

        clockTime = DateTime(2026, 4, 25, 10, 0, 4);
        final data3 = createPayload(blockProgressFraction: 0.8);
        await sync.sync(data: data3, timelineIndex: 0);

        expect(bridge.updateCalls.length, 1);
        expect(service.updateCalls.length, 1);
      },
    );

    test(
      'gps status change triggers immediate update from real state',
      () async {
        sync = createSync();

        final data = createPayload(distanceKm: 1.0, paceSecondsPerKm: 300);
        await sync.sync(
          data: data,
          timelineIndex: 0,
          gpsStatus: GpsStatus.acquiring,
        );

        bridge.reset();
        service.reset();

        await sync.sync(
          data: data,
          timelineIndex: 0,
          gpsStatus: GpsStatus.lost,
        );

        expect(bridge.updateCalls.length, 1);
        expect(service.updateCalls.length, 1);
      },
    );

    test(
      'timer-only mode change triggers immediate update from real state',
      () async {
        sync = createSync();

        final data = createPayload(distanceKm: 0.0, paceSecondsPerKm: 0);
        await sync.sync(
          data: data,
          timelineIndex: 0,
          gpsStatus: GpsStatus.disabled,
          isTimerOnlyMode: false,
        );

        bridge.reset();
        service.reset();

        await sync.sync(
          data: data,
          timelineIndex: 0,
          gpsStatus: GpsStatus.disabled,
          isTimerOnlyMode: true,
        );

        expect(bridge.updateCalls.length, 1);
        expect(service.updateCalls.length, 1);
      },
    );

    test('multiple immediate changes in sequence send once', () async {
      sync = createSync();

      await sync.sync(data: createPayload(isPaused: false), timelineIndex: 0);

      bridge.reset();
      service.reset();

      await sync.sync(
        data: createPayload(
          isPaused: true,
          currentBlockLabel: 'Recovery',
          distanceKm: 1.5,
        ),
        timelineIndex: 1,
      );

      expect(bridge.updateCalls.length, 1);
      expect(service.updateCalls.length, 1);
    });
  });
}
