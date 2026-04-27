import 'package:flutter/foundation.dart';

import '../domain/models/gps_state.dart';
import '../domain/run_live_activity_data.dart';
import 'run_live_activity_bridge.dart';
import 'run_live_activity_background_service.dart';

typedef SyncClock = DateTime Function();

class ActiveRunLiveActivitySync {
  ActiveRunLiveActivitySync({
    required RunLiveActivityBridgePort bridge,
    required RunLiveActivityBackgroundServicePort backgroundService,
    SyncClock? clock,
  }) : _bridge = bridge,
       _backgroundService = backgroundService,
       _clock = clock ?? (() => DateTime.now());

  final RunLiveActivityBridgePort _bridge;
  final RunLiveActivityBackgroundServicePort _backgroundService;
  final SyncClock _clock;

  bool _started = false;
  bool _ended = false;
  DateTime? _lastUpdateAt;
  _PayloadSignature? _lastSignature;

  static const _minUpdateInterval = Duration(seconds: 3);
  static const _distanceDeltaThresholdKm = 0.01;
  static const _paceDeltaThresholdSecondsPerKm = 10;

  @protected
  DateTime get _now => _clock();

  Future<void> sync({
    required RunLiveActivityData data,
    required int timelineIndex,
    GpsStatus gpsStatus = GpsStatus.ready,
    bool isTimerOnlyMode = false,
  }) async {
    if (_ended) return;

    final now = _now;
    final signature = _PayloadSignature.fromData(
      data,
      timelineIndex: timelineIndex,
      gpsStatus: gpsStatus,
      isTimerOnlyMode: isTimerOnlyMode,
    );
    final immediate = _shouldSendImmediately(signature);
    final throttled = _shouldSendThrottled(signature, now);

    if (!immediate && !throttled) return;

    _lastUpdateAt = now;
    _lastSignature = signature;

    if (!_started) {
      _started = true;
      try {
        await _bridge.startActivity(data);
        await _backgroundService.start(data);
      } catch (e) {
        debugPrint('[ActiveRunLiveActivitySync] start failed: $e');
      }
    } else {
      try {
        await _bridge.updateActivity(data);
        await _backgroundService.update(data);
      } catch (e) {
        debugPrint('[ActiveRunLiveActivitySync] update failed: $e');
      }
    }
  }

  bool _shouldSendImmediately(_PayloadSignature next) {
    final prev = _lastSignature;
    if (prev == null) return true;

    if (prev.isPaused != next.isPaused) return true;
    if (prev.timelineIndex != next.timelineIndex) return true;
    if (prev.currentBlockLabel != next.currentBlockLabel) return true;
    if (prev.nextBlockLabel != next.nextBlockLabel) return true;
    if (prev.repLabel != next.repLabel) return true;
    if (prev.gpsStatus != next.gpsStatus) return true;
    if (prev.isTimerOnlyMode != next.isTimerOnlyMode) return true;

    return false;
  }

  bool _shouldSendThrottled(_PayloadSignature next, DateTime now) {
    final prev = _lastSignature;
    if (prev == null) return true;

    if (_lastUpdateAt != null) {
      final elapsed = now.difference(_lastUpdateAt!);
      final distanceDelta = (next.distanceKm - prev.distanceKm).abs();
      final paceDelta = (next.paceSecondsPerKm - prev.paceSecondsPerKm).abs();
      final progressDelta =
          (next.blockProgressFraction - prev.blockProgressFraction).abs();

      final hasSignificantDelta =
          distanceDelta >= _distanceDeltaThresholdKm ||
          paceDelta >= _paceDeltaThresholdSecondsPerKm;

      if (elapsed < _minUpdateInterval) {
        // Before the throttle window: only push when distance/pace moved
        // beyond their thresholds.
        return hasSignificantDelta;
      }

      // After the throttle window: still require at least one tracked field
      // to differ. Pause/labels/gps already trigger the immediate path.
      final anyDelta = distanceDelta > 0 || paceDelta > 0 || progressDelta > 0;
      return anyDelta;
    }

    return true;
  }

  Future<void> end() async {
    if (_ended) return;
    _ended = true;

    try {
      await _bridge.endActivity();
      await _backgroundService.stop();
    } catch (e) {
      debugPrint('[ActiveRunLiveActivitySync] end failed: $e');
    }
  }
}

class _PayloadSignature {
  const _PayloadSignature({
    required this.distanceKm,
    required this.paceSecondsPerKm,
    required this.blockProgressFraction,
    required this.currentBlockLabel,
    required this.nextBlockLabel,
    required this.repLabel,
    required this.isPaused,
    required this.timelineIndex,
    required this.gpsStatus,
    required this.isTimerOnlyMode,
  });

  final double distanceKm;
  final int paceSecondsPerKm;
  final double blockProgressFraction;
  final String currentBlockLabel;
  final String? nextBlockLabel;
  final String? repLabel;
  final bool isPaused;
  final int timelineIndex;
  final GpsStatus gpsStatus;
  final bool isTimerOnlyMode;

  factory _PayloadSignature.fromData(
    RunLiveActivityData data, {
    required int timelineIndex,
    required GpsStatus gpsStatus,
    required bool isTimerOnlyMode,
  }) {
    return _PayloadSignature(
      distanceKm: data.distanceKm,
      paceSecondsPerKm: data.paceSecondsPerKm,
      blockProgressFraction: data.blockProgressFraction,
      currentBlockLabel: data.currentBlockLabel,
      nextBlockLabel: data.nextBlockLabel,
      repLabel: data.repLabel,
      isPaused: data.isPaused,
      timelineIndex: timelineIndex,
      gpsStatus: gpsStatus,
      isTimerOnlyMode: isTimerOnlyMode,
    );
  }
}
