import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pre_run/presentation/run_flow_context.dart';
import '../data/distance_accumulator.dart';
import '../data/pace_smoother.dart';
import '../data/run_repository.dart';
import '../domain/active_run_target_resolver.dart';
import '../domain/live_pace_guidance.dart';
import '../domain/models/gps_state.dart';
import '../domain/models/run_track_point.dart';
import 'active_run_timeline.dart';
import 'active_run_progress_provider.dart';
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

enum PaceDisplayQuality { waiting, stable }

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
    required this.displayPaceSecondsPerKm,
    required this.averagePaceSecondsPerKm,
    required this.paceQuality,
    required this.resolvedTarget,
    required this.paceStatus,
    required this.paceGuidance,
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
    displayPaceSecondsPerKm: null,
    averagePaceSecondsPerKm: 0,
    paceQuality: PaceDisplayQuality.waiting,
    resolvedTarget: null,
    paceStatus: LivePaceGuidanceResult.none(),
    paceGuidance: LivePaceGuidanceResult.none(),
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
  final int? displayPaceSecondsPerKm;
  final int averagePaceSecondsPerKm;
  final PaceDisplayQuality paceQuality;
  final ActiveRunResolvedTarget? resolvedTarget;
  final LivePaceGuidanceResult paceStatus;
  final LivePaceGuidanceResult paceGuidance;
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
    int? displayPaceSecondsPerKm,
    int? averagePaceSecondsPerKm,
    PaceDisplayQuality? paceQuality,
    ActiveRunResolvedTarget? resolvedTarget,
    LivePaceGuidanceResult? paceStatus,
    LivePaceGuidanceResult? paceGuidance,
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
    bool clearDisplayPace = false,
    bool clearResolvedTarget = false,
    bool clearCurrentBlock = false,
    bool clearNextBlock = false,
  }) {
    return ActiveRunState(
      session: session ?? this.session,
      elapsed: elapsed ?? this.elapsed,
      distanceKm: distanceKm ?? this.distanceKm,
      currentPaceSecondsPerKm:
          currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
      displayPaceSecondsPerKm: clearDisplayPace
          ? null
          : displayPaceSecondsPerKm ?? this.displayPaceSecondsPerKm,
      averagePaceSecondsPerKm:
          averagePaceSecondsPerKm ?? this.averagePaceSecondsPerKm,
      paceQuality: paceQuality ?? this.paceQuality,
      resolvedTarget: clearResolvedTarget
          ? null
          : resolvedTarget ?? this.resolvedTarget,
      paceStatus: paceStatus ?? this.paceStatus,
      paceGuidance: paceGuidance ?? this.paceGuidance,
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
  final ActiveRunTargetResolver _targetResolver =
      const ActiveRunTargetResolver();
  LivePaceGuidanceEvaluator _paceGuidanceEvaluator =
      LivePaceGuidanceEvaluator();

  final List<RunTrackPoint> _routePointBuffer = [];
  String? _runId;
  int? _startedAtMs;
  int _nextRoutePointIndex = 0;
  Future<void>? _routePointFlushFuture;

  static const int _routePointFlushThreshold = 25;
  static const double _maxPaceAccuracyMeters = 35.0;

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

    final persistedProgress = ref.read(activeRunProgressProvider);
    if (_canRestoreFromProgress(session, timerOnlyMode, persistedProgress)) {
      _restoreFromProgress(
        session: session,
        checkIn: input.checkIn,
        progress: persistedProgress!,
      );
    } else {
      if (persistedProgress?.sessionId != null &&
          persistedProgress?.sessionId != session.sessionId) {
        await ref.read(activeRunProgressProvider.notifier).clear();
      }
      _resetAccumulators();
      _runId = ref.read(clockProvider)().millisecondsSinceEpoch.toString();
      _startedAtMs = ref.read(clockProvider)().millisecondsSinceEpoch;
      final blocks = timeline.blocks;
      final firstBlock = blocks.isNotEmpty ? blocks.first : null;
      final nextBlock = blocks.length > 1 ? blocks[1] : null;

      state = ActiveRunState(
        session: session,
        elapsed: Duration.zero,
        distanceKm: 0.0,
        currentPaceSecondsPerKm: 0,
        displayPaceSecondsPerKm: null,
        averagePaceSecondsPerKm: 0,
        paceQuality: PaceDisplayQuality.waiting,
        resolvedTarget: null,
        paceStatus: const LivePaceGuidanceResult.none(),
        paceGuidance: const LivePaceGuidanceResult.none(),
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
      _refreshPaceGuidance();
    }

    _startTimer();
    if (!timerOnlyMode) {
      _startGps();
    }

    try {
      final db = await ref.read(runDatabaseProvider.future);
      final repository = RunRepository(db: db);
      await repository.insertActiveRun(
        runId: _runId!,
        startedAtMs:
            _startedAtMs ?? ref.read(clockProvider)().millisecondsSinceEpoch,
        timerOnly: timerOnlyMode,
        session: session,
      );
    } catch (_) {}

    unawaited(_saveActiveProgress());
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

  bool _canRestoreFromProgress(
    RunFlowSessionContext? session,
    bool timerOnlyMode,
    ActiveRunProgress? progress,
  ) {
    if (session == null || progress == null) return false;
    if (progress.timerOnlyMode != timerOnlyMode) return false;
    if (progress.sessionId == null) return false;
    return progress.sessionId == session.sessionId;
  }

  void _restoreFromProgress({
    required RunFlowSessionContext? session,
    required PreRunCheckIn? checkIn,
    required ActiveRunProgress progress,
  }) {
    if (session == null) return;
    final timeline = ActiveRunTimeline.fromSession(session).blocks;
    final timelineIndex = timeline.isEmpty
        ? 0
        : progress.timelineIndex.clamp(0, timeline.length);
    final currentBlock = _blockAtIndex(timeline, timelineIndex);
    final nextBlock = _blockAtIndex(timeline, timelineIndex + 1);

    _resetAccumulators();
    _runId =
        progress.runId ??
        ref.read(clockProvider)().millisecondsSinceEpoch.toString();
    _startedAtMs =
        progress.startedAtMs ??
        _startedAtMs ??
        ref.read(clockProvider)().millisecondsSinceEpoch;
    _accumulatedDistanceMeters = (progress.distanceKm * 1000).round();
    _distanceAccumulator = DistanceAccumulator(
      totalDistanceMeters: progress.distanceKm * 1000,
      lastPoint: progress.lastAcceptedPoint != null
          ? _toGpsPoint(progress.lastAcceptedPoint!)
          : null,
      isResettable: false,
    );
    _lastAcceptedPoint = progress.lastAcceptedPoint;
    _lastSplitDistanceMeters = progress.splits.fold<int>(
      0,
      (total, split) => total + (split.distanceKm * 1000).round(),
    );
    _splitStartTime = progress.segmentStartedAtMs != null
        ? DateTime.fromMillisecondsSinceEpoch(progress.segmentStartedAtMs!)
        : null;
    _splitsCount = progress.currentRep > 0
        ? progress.currentRep
        : progress.splits.length;
    _nextRoutePointIndex = 0;

    state = ActiveRunState(
      session: session,
      elapsed: Duration(milliseconds: progress.accumulatedActiveMs),
      distanceKm: progress.distanceKm,
      currentPaceSecondsPerKm: progress.currentPaceSecondsPerKm,
      displayPaceSecondsPerKm: progress.currentPaceSecondsPerKm,
      averagePaceSecondsPerKm: _averagePaceForRestore(
        progress.distanceKm,
        progress.accumulatedActiveMs,
      ),
      paceQuality: PaceDisplayQuality.stable,
      resolvedTarget: null,
      paceStatus: const LivePaceGuidanceResult.none(),
      paceGuidance: const LivePaceGuidanceResult.none(),
      gpsStatus: progress.gpsStatus == GpsStatus.disabled
          ? GpsStatus.disabled
          : progress.gpsStatus,
      currentBlock: currentBlock,
      nextBlock: nextBlock,
      blockElapsed: Duration(milliseconds: progress.blockElapsedMs),
      blockDistanceKm: progress.blockDistanceKm,
      timelineIndex: timelineIndex,
      isPaused: progress.isPaused,
      isSurging: progress.isSurging,
      routePointCount: 0,
      splits: progress.splits
          .map(
            (entry) => ActiveRunSplit(
              splitIndex: entry.splitIndex,
              startedAt: DateTime.fromMillisecondsSinceEpoch(entry.startedAtMs),
              endedAt: DateTime.fromMillisecondsSinceEpoch(entry.endedAtMs),
              duration: Duration(milliseconds: entry.durationMs),
              distanceKm: entry.distanceKm,
              paceSecondsPerKm: entry.paceSecondsPerKm,
            ),
          )
          .toList(),
      error: null,
      modalIntent: ActiveRunModalIntent.none,
      isTimerOnlyMode: progress.timerOnlyMode,
      checkIn: checkIn,
    );

    _gpsState = progress.lastAcceptedPoint == null
        ? GpsState.initial()
        : GpsState(
            status: progress.gpsStatus,
            lastFix: GpsFix(
              latitude: progress.lastAcceptedPoint!.latitude,
              longitude: progress.lastAcceptedPoint!.longitude,
              accuracy: progress.lastAcceptedPoint!.accuracy,
              timestamp: progress.lastAcceptedPoint!.timestamp,
            ),
            lastStatusChange: DateTime.now(),
          );

    if (state.isPaused) {
      _paceSmoother = const PaceSmoother();
    }

    _refreshPaceGuidance();
  }

  int _averagePaceForRestore(double distanceKm, int elapsedMs) {
    if (distanceKm <= 0) return 0;
    final seconds = elapsedMs ~/ 1000;
    if (seconds <= 0) return 0;
    return ((seconds * 1000) / (distanceKm * 1000)).round();
  }

  GpsPoint _toGpsPoint(RunTrackPoint point) {
    return GpsPoint(
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: point.timestamp,
    );
  }

  ActiveRunTimelineBlock? _blockAtIndex(
    List<ActiveRunTimelineBlock> blocks,
    int index,
  ) {
    if (index < 0 || index >= blocks.length) return null;
    return blocks[index];
  }

  void _resetAccumulators() {
    _distanceAccumulator = const DistanceAccumulator();
    _paceSmoother = const PaceSmoother();
    _paceGuidanceEvaluator = LivePaceGuidanceEvaluator();
    _gpsState = GpsState.initial();
    _lastAcceptedPoint = null;
    _accumulatedDistanceMeters = 0;
    _lastSplitDistanceMeters = 0;
    _splitStartTime = null;
    _splitsCount = 0;
    _routePointBuffer.clear();
    _nextRoutePointIndex = 0;
    _runId = null;
    _startedAtMs = null;
    _routePointFlushFuture = null;
  }

  void _refreshPaceGuidance() {
    final resolvedTarget = _targetResolver.resolve(
      currentBlockTarget: state.currentBlock?.target,
      blockRole: _guidanceRoleFor(state.currentBlock),
      fallbackTarget: state.session?.workoutTarget,
      paceZones: state.session?.paceZones,
    );
    final displayPace = state.displayPaceSecondsPerKm;
    final guidanceInput = resolvedTarget == null || displayPace == null
        ? null
        : LivePaceGuidanceInput(
            currentPaceSecondsPerKm: displayPace,
            currentBlockTarget: resolvedTarget.target,
            fallbackTarget: null,
            fallbackZone: resolvedTarget.zone,
            runElapsed: state.elapsed,
            blockElapsed: state.blockElapsed,
            timelineIndex: state.timelineIndex,
            isPaused: state.isPaused,
            isTimerOnlyMode: state.isTimerOnlyMode,
            isGpsReady: state.gpsStatus == GpsStatus.ready,
            now: ref.read(clockProvider)(),
          );
    final paceStatus = guidanceInput == null
        ? const LivePaceGuidanceResult.none()
        : _paceGuidanceEvaluator.statusFor(guidanceInput);
    final guidance = guidanceInput == null
        ? const LivePaceGuidanceResult.none()
        : _paceGuidanceEvaluator.evaluate(guidanceInput);

    state = state.copyWith(
      resolvedTarget: resolvedTarget,
      clearResolvedTarget: resolvedTarget == null,
      paceStatus: paceStatus,
      paceGuidance: guidance,
    );
  }

  PaceGuidanceBlockRole? _guidanceRoleFor(ActiveRunTimelineBlock? block) {
    return switch (block?.kind) {
      ActiveRunBlockKind.warmUp => PaceGuidanceBlockRole.warmUp,
      ActiveRunBlockKind.work => PaceGuidanceBlockRole.work,
      ActiveRunBlockKind.recovery => PaceGuidanceBlockRole.recovery,
      ActiveRunBlockKind.coolDown => PaceGuidanceBlockRole.coolDown,
      ActiveRunBlockKind.stride => PaceGuidanceBlockRole.stride,
      null => null,
    };
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
    final progress = _buildActiveRunProgress();
    try {
      final db = await ref.read(runDatabaseProvider.future);
      final repository = RunRepository(db: db);
      await repository.updateActiveRunSummary(
        runId: _runId!,
        durationMs: state.elapsed.inMilliseconds,
        distanceKm: state.distanceKm,
      );
    } catch (_) {}
    try {
      await ref.read(activeRunProgressProvider.notifier).save(progress);
    } catch (_) {}
  }

  ActiveRunProgress _buildActiveRunProgress() {
    return ActiveRunProgress(
      runId: _runId!,
      sessionId: state.session?.sessionId,
      timerOnlyMode: state.isTimerOnlyMode,
      startedAtMs: _startedAtMs,
      distanceKm: state.distanceKm,
      accumulatedActiveMs: state.elapsed.inMilliseconds,
      timelineIndex: state.timelineIndex,
      blockElapsedMs: state.blockElapsed.inMilliseconds,
      blockDistanceKm: state.blockDistanceKm,
      currentRep: _splitsCount,
      isPaused: state.isPaused,
      isSurging: state.isSurging,
      segmentStartedAtMs: _splitStartTime?.millisecondsSinceEpoch,
      lastTickAtMs: ref.read(clockProvider)().millisecondsSinceEpoch,
      currentPaceSecondsPerKm: state.currentPaceSecondsPerKm,
      gpsStatus: state.gpsStatus,
      lastAcceptedPoint: _lastAcceptedPoint,
      splits: state.splits
          .map(
            (split) => SplitEntry(
              splitIndex: split.splitIndex,
              startedAtMs: split.startedAt.millisecondsSinceEpoch,
              endedAtMs: split.endedAt.millisecondsSinceEpoch,
              durationMs: split.duration.inMilliseconds,
              distanceKm: split.distanceKm,
              paceSecondsPerKm: split.paceSecondsPerKm,
            ),
          )
          .toList(),
    );
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
    } else {
      _refreshPaceGuidance();
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
    _refreshPaceGuidance();
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
      _refreshPaceGuidance();
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

    if (deltaMeters > 0 &&
        deltaMs > 0 &&
        point.accuracy <= _maxPaceAccuracyMeters) {
      _paceSmoother = _paceSmoother.add(
        deltaMeters.toDouble(),
        deltaMs,
        at: point.timestamp,
      );
      final smoothedPace = _paceSmoother.currentPaceSecondsPerKm;
      if (smoothedPace != null) {
        state = state.copyWith(
          currentPaceSecondsPerKm: smoothedPace,
          displayPaceSecondsPerKm: smoothedPace,
          paceQuality: PaceDisplayQuality.stable,
        );
      } else {
        state = state.copyWith(
          paceQuality: PaceDisplayQuality.waiting,
          clearDisplayPace: true,
          paceStatus: const LivePaceGuidanceResult.none(),
          paceGuidance: const LivePaceGuidanceResult.none(),
        );
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
    _refreshPaceGuidance();
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
        paceQuality: PaceDisplayQuality.waiting,
        paceStatus: const LivePaceGuidanceResult.none(),
        paceGuidance: const LivePaceGuidanceResult.none(),
      );
    } else {
      state = state.copyWith(
        modalIntent: ActiveRunModalIntent.gpsLostWarning,
        paceQuality: PaceDisplayQuality.waiting,
        paceStatus: const LivePaceGuidanceResult.none(),
        paceGuidance: const LivePaceGuidanceResult.none(),
      );
    }
  }

  void pause() {
    if (state.isPaused) return;
    unawaited(_flushRoutePoints());
    state = state.copyWith(
      isPaused: true,
      modalIntent: ActiveRunModalIntent.none,
      paceStatus: const LivePaceGuidanceResult.none(),
      paceGuidance: const LivePaceGuidanceResult.none(),
    );
    unawaited(_saveActiveProgress());
    _refreshPaceGuidance();
  }

  void resume() {
    if (!state.isPaused) return;

    _lastAcceptedPoint = null;
    _distanceAccumulator = _distanceAccumulator.clearLastPoint();
    _paceSmoother = _paceSmoother.reset();

    state = state.copyWith(
      isPaused: false,
      modalIntent: ActiveRunModalIntent.none,
      paceQuality: PaceDisplayQuality.waiting,
      clearDisplayPace: true,
      paceStatus: const LivePaceGuidanceResult.none(),
      paceGuidance: const LivePaceGuidanceResult.none(),
    );
    unawaited(_saveActiveProgress());
    _refreshPaceGuidance();
  }

  void toggleSurge() {
    state = state.copyWith(isSurging: !state.isSurging);
  }

  Future<void> _stopRuntime({bool flushRoutePoints = false}) async {
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

    if (flushRoutePoints) {
      await _flushRoutePoints();
    }
  }

  Future<ActiveRunFinishResult> finish() async {
    await _stopRuntime(flushRoutePoints: true);

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

    await ref.read(activeRunProgressProvider.notifier).clear();
    return result;
  }

  Future<void> discard() async {
    await _stopRuntime();
    _runId = null;
    _routePointBuffer.clear();
    _routePointFlushFuture = null;
    _resetAccumulators();
    await ref.read(activeRunProgressProvider.notifier).clear();
    state = ActiveRunState.initial();
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
