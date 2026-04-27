import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pre_run/presentation/run_flow_context.dart';
import '../data/distance_accumulator.dart';
import '../data/pace_smoother.dart';
import '../data/run_repository.dart';
import '../domain/models/gps_state.dart';
import '../domain/models/run_track_point.dart';
import 'active_run_timeline.dart';
import 'location_tracker_provider.dart';
import 'run_repository_provider.dart';

final clockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now(),
);

enum ActiveRunModalIntent {
  none,
  gpsLostAutoPause,
  gpsLostWarning,
  timerOnlyRestriction,
  finishConfirm,
  endRunConfirm,
}

@immutable
class ActiveRunStartInput {
  const ActiveRunStartInput({
    required this.session,
    required this.checkIn,
    required this.timerOnlyMode,
  });

  final RunFlowSessionContext? session;
  final PreRunCheckIn? checkIn;
  final bool timerOnlyMode;
}

@immutable
class ActiveRunSplit {
  const ActiveRunSplit({
    required this.splitIndex,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.distanceKm,
    required this.paceSecondsPerKm,
  });

  final int splitIndex;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final double distanceKm;
  final int paceSecondsPerKm;
}

@immutable
class ActiveRunState {
  const ActiveRunState({
    required this.session,
    required this.elapsed,
    required this.distanceKm,
    required this.currentPaceSecondsPerKm,
    required this.averagePaceSecondsPerKm,
    required this.gpsStatus,
    required this.currentBlock,
    required this.nextBlock,
    required this.blockElapsed,
    required this.blockDistanceKm,
    required this.timelineIndex,
    required this.isPaused,
    required this.isSurging,
    required this.routePointCount,
    required this.splits,
    required this.error,
    required this.modalIntent,
    required this.isTimerOnlyMode,
    required this.checkIn,
  });

  factory ActiveRunState.initial() => const ActiveRunState(
    session: null,
    elapsed: Duration.zero,
    distanceKm: 0.0,
    currentPaceSecondsPerKm: 0,
    averagePaceSecondsPerKm: 0,
    gpsStatus: GpsStatus.acquiring,
    currentBlock: null,
    nextBlock: null,
    blockElapsed: Duration.zero,
    blockDistanceKm: 0.0,
    timelineIndex: 0,
    isPaused: false,
    isSurging: false,
    routePointCount: 0,
    splits: [],
    error: null,
    modalIntent: ActiveRunModalIntent.none,
    isTimerOnlyMode: false,
    checkIn: null,
  );

  final RunFlowSessionContext? session;
  final Duration elapsed;
  final double distanceKm;
  final int currentPaceSecondsPerKm;
  final int averagePaceSecondsPerKm;
  final GpsStatus gpsStatus;
  final ActiveRunTimelineBlock? currentBlock;
  final ActiveRunTimelineBlock? nextBlock;
  final Duration blockElapsed;
  final double blockDistanceKm;
  final int timelineIndex;
  final bool isPaused;
  final bool isSurging;
  final int routePointCount;
  final List<ActiveRunSplit> splits;
  final String? error;
  final ActiveRunModalIntent modalIntent;
  final bool isTimerOnlyMode;
  final PreRunCheckIn? checkIn;

  ActiveRunState copyWith({
    RunFlowSessionContext? session,
    Duration? elapsed,
    double? distanceKm,
    int? currentPaceSecondsPerKm,
    int? averagePaceSecondsPerKm,
    GpsStatus? gpsStatus,
    ActiveRunTimelineBlock? currentBlock,
    ActiveRunTimelineBlock? nextBlock,
    Duration? blockElapsed,
    double? blockDistanceKm,
    int? timelineIndex,
    bool? isPaused,
    bool? isSurging,
    int? routePointCount,
    List<ActiveRunSplit>? splits,
    String? error,
    ActiveRunModalIntent? modalIntent,
    bool? isTimerOnlyMode,
    PreRunCheckIn? checkIn,
    bool clearCurrentBlock = false,
    bool clearNextBlock = false,
  }) {
    return ActiveRunState(
      session: session ?? this.session,
      elapsed: elapsed ?? this.elapsed,
      distanceKm: distanceKm ?? this.distanceKm,
      currentPaceSecondsPerKm:
          currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
      averagePaceSecondsPerKm:
          averagePaceSecondsPerKm ?? this.averagePaceSecondsPerKm,
      gpsStatus: gpsStatus ?? this.gpsStatus,
      currentBlock: clearCurrentBlock
          ? null
          : currentBlock ?? this.currentBlock,
      nextBlock: clearNextBlock ? null : nextBlock ?? this.nextBlock,
      blockElapsed: blockElapsed ?? this.blockElapsed,
      blockDistanceKm: blockDistanceKm ?? this.blockDistanceKm,
      timelineIndex: timelineIndex ?? this.timelineIndex,
      isPaused: isPaused ?? this.isPaused,
      isSurging: isSurging ?? this.isSurging,
      routePointCount: routePointCount ?? this.routePointCount,
      splits: splits ?? this.splits,
      error: error,
      modalIntent: modalIntent ?? this.modalIntent,
      isTimerOnlyMode: isTimerOnlyMode ?? this.isTimerOnlyMode,
      checkIn: checkIn ?? this.checkIn,
    );
  }
}

class ActiveRunController extends Notifier<ActiveRunState> {
  Timer? _timer;
  Timer? _progressTimer;
  StreamSubscription<RunTrackPoint>? _gpsSubscription;
  RunTrackPoint? _lastAcceptedPoint;
  int _accumulatedDistanceMeters = 0;
  int _lastSplitDistanceMeters = 0;
  DateTime? _splitStartTime;
  int _splitsCount = 0;

  DistanceAccumulator _distanceAccumulator = const DistanceAccumulator();
  PaceSmoother _paceSmoother = const PaceSmoother();
  GpsState _gpsState = GpsState.initial();

  final List<RunTrackPoint> _routePointBuffer = [];
  String? _runId;
  int _nextRoutePointIndex = 0;
  Future<void>? _routePointFlushFuture;

  static const int _routePointFlushThreshold = 25;

  @override
  ActiveRunState build() => ActiveRunState.initial();

  Future<void> start(ActiveRunStartInput input) async {
    final session = input.session;
    final timerOnlyMode = input.timerOnlyMode;

    if (session == null) {
      state = state.copyWith(
        error: 'No session available to start active run',
        modalIntent: ActiveRunModalIntent.endRunConfirm,
      );
      return;
    }

    final timeline = ActiveRunTimeline.fromSession(session);
    final hasDistanceBlocks = timeline.blocks.any(
      (block) => block.distanceMeters != null && block.distanceMeters! > 0,
    );

    if (timerOnlyMode && hasDistanceBlocks) {
      state = state.copyWith(
        error: 'Timer-only mode is not supported for distance-based workouts',
        modalIntent: ActiveRunModalIntent.timerOnlyRestriction,
      );
      return;
    }

    if (_isSameActiveRunStartRequest(input)) {
      return;
    }

    _resetAccumulators();
    _runId = ref.read(clockProvider)().millisecondsSinceEpoch.toString();

    final blocks = timeline.blocks;
    final firstBlock = blocks.isNotEmpty ? blocks.first : null;
    final nextBlock = blocks.length > 1 ? blocks[1] : null;

    state = ActiveRunState(
      session: session,
      elapsed: Duration.zero,
      distanceKm: 0.0,
      currentPaceSecondsPerKm: 0,
      averagePaceSecondsPerKm: 0,
      gpsStatus: timerOnlyMode ? GpsStatus.disabled : GpsStatus.acquiring,
      currentBlock: firstBlock,
      nextBlock: nextBlock,
      blockElapsed: Duration.zero,
      blockDistanceKm: 0.0,
      timelineIndex: 0,
      isPaused: false,
      isSurging: false,
      routePointCount: 0,
      splits: const [],
      error: null,
      modalIntent: ActiveRunModalIntent.none,
      isTimerOnlyMode: timerOnlyMode,
      checkIn: input.checkIn,
    );

    _startTimer();
    if (!timerOnlyMode) {
      _startGps();
    }

    try {
      final db = await ref.read(runDatabaseProvider.future);
      final repository = RunRepository(db: db);
      await repository.insertActiveRun(
        runId: _runId!,
        startedAtMs: ref.read(clockProvider)().millisecondsSinceEpoch,
        timerOnly: timerOnlyMode,
        session: session,
      );
    } catch (_) {}

    _startProgressTimer();
  }

  bool _isSameActiveRunStartRequest(ActiveRunStartInput input) {
    final currentSession = state.session;
    final incomingSession = input.session;
    if (_runId == null || currentSession == null || incomingSession == null) {
      return false;
    }

    return currentSession.sessionId == incomingSession.sessionId &&
        state.isTimerOnlyMode == input.timerOnlyMode;
  }

  void _resetAccumulators() {
    _distanceAccumulator = const DistanceAccumulator();
    _paceSmoother = const PaceSmoother();
    _gpsState = GpsState.initial();
    _lastAcceptedPoint = null;
    _accumulatedDistanceMeters = 0;
    _lastSplitDistanceMeters = 0;
    _splitStartTime = null;
    _splitsCount = 0;
    _routePointBuffer.clear();
    _nextRoutePointIndex = 0;
    _runId = null;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTimerTick());
  }

  void tickClock() {
    _onTimerTick();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveActiveProgress();
    });
  }

  Future<void> _saveActiveProgress() async {
    if (_runId == null) return;
    try {
      final db = await ref.read(runDatabaseProvider.future);
      final repository = RunRepository(db: db);
      await repository.updateActiveRunSummary(
        runId: _runId!,
        durationMs: state.elapsed.inMilliseconds,
        distanceKm: state.distanceKm,
      );
    } catch (_) {}
  }

  Future<void> _flushRoutePoints() async {
    if (_runId == null) return;
    if (_routePointFlushFuture != null) {
      return _routePointFlushFuture!;
    }
    if (_routePointBuffer.isEmpty) return;

    _routePointFlushFuture = _flushRoutePointsLoop().whenComplete(() {
      _routePointFlushFuture = null;
    });
    return _routePointFlushFuture!;
  }

  Future<void> _flushRoutePointsLoop() async {
    while (_runId != null && _routePointBuffer.isNotEmpty) {
      final runId = _runId!;
      final pendingPoints = List<RunTrackPoint>.of(_routePointBuffer);
      final startIndex = _nextRoutePointIndex;
      _routePointBuffer.clear();
      _nextRoutePointIndex += pendingPoints.length;

      try {
        final db = await ref.read(runDatabaseProvider.future);
        final repository = RunRepository(db: db);
        final points = pendingPoints.asMap().entries.map((e) {
          return RunRoutePoint.fromTrackPoint(
            runId: runId,
            index: startIndex + e.key,
            point: e.value,
          );
        }).toList();
        await repository.insertRoutePoints(points);
      } catch (_) {
        _nextRoutePointIndex = startIndex;
        _routePointBuffer.insertAll(0, pendingPoints);
        return;
      }
    }
  }

  ActiveRunTimelineBlock? _nextTimelineBlock() {
    final timeline = ActiveRunTimeline.fromSession(state.session);
    final blocks = timeline.blocks;
    final nextIndex = state.timelineIndex + 1;
    if (nextIndex >= blocks.length) return null;
    return blocks[nextIndex];
  }

  double _distanceCarryoverForNextBlock(double overshootKm) {
    final nextBlock = _nextTimelineBlock();
    if (nextBlock == null || !nextBlock.isDistanceBased) return 0.0;
    return overshootKm;
  }

  void _onTimerTick() {
    if (state.isPaused) return;
    if (state.session == null) return;

    final currentBlock = state.currentBlock;
    final newElapsed = state.elapsed + const Duration(seconds: 1);

    var nextBlockElapsed = state.blockElapsed;
    var shouldAdvance = false;

    if (currentBlock != null && currentBlock.isDurationBased) {
      nextBlockElapsed = state.blockElapsed + const Duration(seconds: 1);
      if (currentBlock.duration != null &&
          nextBlockElapsed >= currentBlock.duration!) {
        shouldAdvance = true;
      }
    }

    state = state.copyWith(elapsed: newElapsed, blockElapsed: nextBlockElapsed);
    if (shouldAdvance) {
      _advanceToNextBlock();
    }
  }

  void _advanceToNextBlock({double initialBlockDistanceKm = 0.0}) {
    final timeline = ActiveRunTimeline.fromSession(state.session);
    final blocks = timeline.blocks;
    final nextIndex = state.timelineIndex + 1;

    if (nextIndex < blocks.length) {
      final nextBlock = blocks[nextIndex];
      final nextNextBlock = nextIndex + 1 < blocks.length
          ? blocks[nextIndex + 1]
          : null;

      state = state.copyWith(
        timelineIndex: nextIndex,
        currentBlock: nextBlock,
        nextBlock: nextNextBlock,
        clearNextBlock: nextNextBlock == null,
        blockElapsed: Duration.zero,
        blockDistanceKm: initialBlockDistanceKm,
      );
    } else {
      state = state.copyWith(
        timelineIndex: nextIndex,
        currentBlock: null,
        nextBlock: null,
        clearCurrentBlock: true,
        clearNextBlock: true,
        blockElapsed: Duration.zero,
        blockDistanceKm: 0.0,
      );
    }
  }

  void _startGps() {
    final tracker = ref.read(locationTrackerProvider);
    tracker.start();
    _gpsSubscription?.cancel();
    _gpsSubscription = tracker.points.listen((point) async {
      await _onGpsPoint(point);
    });
  }

  Future<void> _onGpsPoint(RunTrackPoint point) async {
    if (state.isPaused) return;
    if (state.isTimerOnlyMode) return;
    if (state.session == null) return;

    _gpsState = _gpsState.recordFix(
      GpsFix(
        latitude: point.latitude,
        longitude: point.longitude,
        accuracy: point.accuracy,
        timestamp: point.timestamp,
      ),
    );

    state = state.copyWith(gpsStatus: _gpsState.status);

    if (_gpsState.isLost) {
      _handleGpsLost();
      return;
    }

    final gpsPoint = GpsPoint(
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: point.timestamp,
    );

    _distanceAccumulator = _distanceAccumulator.add(gpsPoint);

    if (_distanceAccumulator.lastPoint != gpsPoint) {
      return;
    }

    if (_lastAcceptedPoint == null) {
      _lastAcceptedPoint = point;
      _splitStartTime = point.timestamp;
      return;
    }

    final deltaMs = point.timestamp
        .difference(_lastAcceptedPoint!.timestamp)
        .inMilliseconds;
    final deltaMeters =
        _distanceAccumulator.totalDistanceMeters - _accumulatedDistanceMeters;

    if (deltaMeters > 0 && deltaMs > 0) {
      _paceSmoother = _paceSmoother.add(deltaMeters.toDouble(), deltaMs);
      final smoothedPace = _paceSmoother.currentPaceSecondsPerKm;
      if (smoothedPace != null) {
        state = state.copyWith(currentPaceSecondsPerKm: smoothedPace);
      }
    }

    _accumulatedDistanceMeters = _distanceAccumulator.totalDistanceMeters
        .round();
    final totalDistanceKm = _accumulatedDistanceMeters / 1000.0;
    final nextBlockDistanceKm = state.blockDistanceKm + (deltaMeters / 1000.0);

    int avgPace = state.averagePaceSecondsPerKm;
    if (_accumulatedDistanceMeters > 0 && state.elapsed.inSeconds > 0) {
      avgPace = ((state.elapsed.inSeconds * 1000) / _accumulatedDistanceMeters)
          .round();
    }

    state = state.copyWith(
      distanceKm: totalDistanceKm,
      blockDistanceKm: nextBlockDistanceKm,
      averagePaceSecondsPerKm: avgPace,
    );

    _checkSplits(point.timestamp);
    _checkDistanceBlockCompletion(nextBlockDistanceKm);

    _routePointBuffer.add(point);
    if (_routePointBuffer.length >= _routePointFlushThreshold) {
      await _flushRoutePoints();
    }

    _lastAcceptedPoint = point;
    state = state.copyWith(routePointCount: state.routePointCount + 1);
  }

  void _checkSplits(DateTime timestamp) {
    final currentKm = _accumulatedDistanceMeters ~/ 1000;
    final lastSplitKm = _lastSplitDistanceMeters ~/ 1000;

    if (currentKm > lastSplitKm && currentKm > 0) {
      final splitDuration = timestamp.difference(_splitStartTime ?? timestamp);
      final splitDistanceKm = (currentKm - lastSplitKm).toDouble();
      final paceSecondsPerKm = splitDuration.inSeconds / splitDistanceKm;

      final split = ActiveRunSplit(
        splitIndex: _splitsCount,
        startedAt: _splitStartTime ?? timestamp,
        endedAt: timestamp,
        duration: splitDuration,
        distanceKm: splitDistanceKm,
        paceSecondsPerKm: paceSecondsPerKm.round(),
      );

      state = state.copyWith(splits: [...state.splits, split]);

      _splitsCount++;
      _lastSplitDistanceMeters = currentKm * 1000;
      _splitStartTime = timestamp;
    }
  }

  void _checkDistanceBlockCompletion(double blockDistanceKm) {
    var currentBlockDistanceKm = blockDistanceKm;

    while (true) {
      final currentBlock = state.currentBlock;
      if (currentBlock == null) return;
      if (!currentBlock.isDistanceBased) return;

      final blockTargetKm = (currentBlock.distanceMeters ?? 0) / 1000.0;
      if (blockTargetKm <= 0) return;
      if (currentBlockDistanceKm < blockTargetKm) return;

      final overshootKm = currentBlockDistanceKm - blockTargetKm;
      final carryoverKm = _distanceCarryoverForNextBlock(overshootKm);
      _advanceToNextBlock(initialBlockDistanceKm: carryoverKm);
      if (carryoverKm <= 0) return;
      currentBlockDistanceKm = carryoverKm;
    }
  }

  void _handleGpsLost() {
    if (state.modalIntent == ActiveRunModalIntent.gpsLostAutoPause ||
        state.modalIntent == ActiveRunModalIntent.gpsLostWarning) {
      return;
    }

    final currentBlock = state.currentBlock;

    if (currentBlock != null && currentBlock.isDistanceBased) {
      state = state.copyWith(
        modalIntent: ActiveRunModalIntent.gpsLostAutoPause,
        isPaused: true,
      );
    } else {
      state = state.copyWith(modalIntent: ActiveRunModalIntent.gpsLostWarning);
    }
  }

  void pause() {
    if (state.isPaused) return;
    unawaited(_flushRoutePoints());
    state = state.copyWith(
      isPaused: true,
      modalIntent: ActiveRunModalIntent.none,
    );
  }

  void resume() {
    if (!state.isPaused) return;

    _lastAcceptedPoint = null;
    _distanceAccumulator = _distanceAccumulator.clearLastPoint();

    state = state.copyWith(
      isPaused: false,
      modalIntent: ActiveRunModalIntent.none,
    );
  }

  void toggleSurge() {
    state = state.copyWith(isSurging: !state.isSurging);
  }

  Future<ActiveRunFinishResult> finish() async {
    _timer?.cancel();
    _timer = null;
    _progressTimer?.cancel();
    _progressTimer = null;

    _gpsSubscription?.cancel();
    _gpsSubscription = null;

    try {
      final tracker = ref.read(locationTrackerProvider);
      tracker.stop();
    } catch (_) {}

    await _flushRoutePoints();

    final runId = _runId;
    final splits = state.splits;
    final elapsed = state.elapsed;
    final distanceKm = state.distanceKm;

    if (runId != null) {
      try {
        final db = await ref.read(runDatabaseProvider.future);
        final repository = RunRepository(db: db);
        final runSplits = splits.map((s) {
          return RunSplit(
            runId: runId,
            splitIndex: s.splitIndex,
            boundaryMeters: (s.distanceKm * 1000).round(),
            startedAt: s.startedAt,
            endedAt: s.endedAt,
            durationMs: s.duration.inMilliseconds,
            paceSecondsPerKm: s.paceSecondsPerKm.toDouble(),
          );
        }).toList();

        await repository.finishRun(
          runId: runId,
          endedAt: ref.read(clockProvider)(),
          durationMs: elapsed.inMilliseconds,
          distanceKm: distanceKm,
          splits: runSplits,
          finalPoints: [],
        );
      } catch (_) {}
    }

    _runId = null;

    final result = ActiveRunFinishResult(
      runId: runId,
      session: state.session,
      checkIn: state.checkIn,
      elapsed: elapsed,
      distanceKm: distanceKm,
      splits: splits,
    );

    state = state.copyWith(
      isPaused: true,
      modalIntent: ActiveRunModalIntent.none,
    );

    return result;
  }

  void dismissModal() {
    state = state.copyWith(modalIntent: ActiveRunModalIntent.none);
  }

  Future<void> onAppBackground() async {
    await _saveActiveProgress();
    await _flushRoutePoints();
  }

  Future<void> endRun() async {
    await finish();
  }
}

class ActiveRunFinishResult {
  const ActiveRunFinishResult({
    this.runId,
    required this.session,
    required this.checkIn,
    required this.elapsed,
    required this.distanceKm,
    required this.splits,
  });

  final String? runId;
  final RunFlowSessionContext? session;
  final PreRunCheckIn? checkIn;
  final Duration elapsed;
  final double distanceKm;
  final List<ActiveRunSplit> splits;
}

final activeRunControllerProvider =
    NotifierProvider<ActiveRunController, ActiveRunState>(
      ActiveRunController.new,
    );
