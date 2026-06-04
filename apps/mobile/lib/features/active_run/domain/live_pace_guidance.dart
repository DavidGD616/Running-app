import '../../training_plan/domain/models/workout_target.dart';

enum LivePaceGuidanceAction { none, tooFast, tooSlow }

enum LivePaceGuidanceSeverity { none, gentle, firm }

class LivePaceGuidanceResult {
  const LivePaceGuidanceResult({
    required this.action,
    required this.messageKey,
    required this.severity,
  });

  const LivePaceGuidanceResult.none()
    : action = LivePaceGuidanceAction.none,
      messageKey = null,
      severity = LivePaceGuidanceSeverity.none;

  final LivePaceGuidanceAction action;
  final String? messageKey;
  final LivePaceGuidanceSeverity severity;
}

class LivePaceGuidanceInput {
  const LivePaceGuidanceInput({
    required this.currentPaceSecondsPerKm,
    required this.currentBlockTarget,
    this.fallbackTarget,
    this.fallbackZone,
    required this.runElapsed,
    required this.blockElapsed,
    required this.timelineIndex,
    required this.isPaused,
    required this.isTimerOnlyMode,
    required this.isGpsReady,
    required this.now,
  });

  final int currentPaceSecondsPerKm;
  final WorkoutTarget? currentBlockTarget;
  final WorkoutTarget? fallbackTarget;
  final TargetZone? fallbackZone;
  final Duration runElapsed;
  final Duration blockElapsed;
  final int timelineIndex;
  final bool isPaused;
  final bool isTimerOnlyMode;
  final bool isGpsReady;
  final DateTime now;
}

class LivePaceGuidanceEvaluator {
  LivePaceGuidanceEvaluator({
    Duration? sampleWindow,
    int? sampleCountWindow,
    int? minSampleCount,
    Duration? runWarmupSkip,
    Duration? blockWarmupSkip,
    Duration? cooldown,
  }) : _sampleWindow = sampleWindow ?? const Duration(seconds: 20),
       _sampleCountWindow = sampleCountWindow ?? 5,
       _minSampleCount = minSampleCount ?? 3,
       _runWarmupSkip = runWarmupSkip ?? const Duration(seconds: 45),
       _blockWarmupSkip = blockWarmupSkip ?? const Duration(seconds: 10),
       _cooldown = cooldown ?? const Duration(seconds: 90);

  final Duration _sampleWindow;
  final int _sampleCountWindow;
  final int _minSampleCount;
  final Duration _runWarmupSkip;
  final Duration _blockWarmupSkip;
  final Duration _cooldown;

  int? _lastTimelineIndex;
  LivePaceGuidanceAction _deviationDirection = LivePaceGuidanceAction.none;
  Duration? _deviationStartedAt;
  final Map<LivePaceGuidanceAction, DateTime?> _lastAlertAt = {
    LivePaceGuidanceAction.none: null,
    LivePaceGuidanceAction.tooFast: null,
    LivePaceGuidanceAction.tooSlow: null,
  };
  final List<_PaceSample> _samples = [];

  LivePaceGuidanceResult evaluate(LivePaceGuidanceInput input) {
    _resetForTimelineIndex(input.timelineIndex);

    if (!_isEligibleForGuidance(input)) {
      _resetSustainedState();
      return const LivePaceGuidanceResult.none();
    }

    final resolvedTarget = _resolveTarget(input);
    final zone = resolvedTarget?.zone;
    final paceMin = resolvedTarget?.target.paceMinSecPerKm;
    final paceMax = resolvedTarget?.target.paceMaxSecPerKm;
    if (zone == null ||
        resolvedTarget == null ||
        paceMin == null ||
        paceMax == null) {
      _resetSustainedState();
      return const LivePaceGuidanceResult.none();
    }

    final direction = _directionForPace(
      paceSeconds: input.currentPaceSecondsPerKm,
      zone: zone,
      paceMin: paceMin,
      paceMax: paceMax,
    );

    if (direction == LivePaceGuidanceAction.none) {
      _samples.clear();
      _deviationDirection = LivePaceGuidanceAction.none;
      _deviationStartedAt = null;
      return const LivePaceGuidanceResult.none();
    }

    if (_deviationDirection != direction) {
      _deviationDirection = direction;
      _samples.clear();
      _deviationStartedAt = input.runElapsed;
    }

    _addSample(_PaceSample(at: input.runElapsed, direction: direction));

    if (!_isSustained(input.runElapsed)) {
      return const LivePaceGuidanceResult.none();
    }

    final lastAlertAt = _lastAlertAt[direction];
    if (lastAlertAt != null && input.now.difference(lastAlertAt) < _cooldown) {
      return const LivePaceGuidanceResult.none();
    }

    _lastAlertAt[direction] = input.now;
    return LivePaceGuidanceResult(
      action: direction,
      messageKey: _messageKey(
        action: direction,
        severity: _severity(direction, zone),
      ),
      severity: _severity(direction, zone),
    );
  }

  ({WorkoutTarget target, TargetZone zone})? _resolveTarget(
    LivePaceGuidanceInput input,
  ) {
    final blockTargetHasPaceRange =
        input.currentBlockTarget != null &&
        input.currentBlockTarget!.paceMinSecPerKm != null &&
        input.currentBlockTarget!.paceMaxSecPerKm != null;

    final fallbackTargetHasPaceRange =
        input.fallbackTarget != null &&
        input.fallbackTarget!.paceMinSecPerKm != null &&
        input.fallbackTarget!.paceMaxSecPerKm != null;

    if (blockTargetHasPaceRange) {
      return (
        target: input.currentBlockTarget!,
        zone: input.currentBlockTarget!.zone,
      );
    }
    if (fallbackTargetHasPaceRange) {
      final zone =
          input.currentBlockTarget?.zone ??
          input.fallbackZone ??
          input.fallbackTarget!.zone;
      return (target: input.fallbackTarget!, zone: zone);
    }

    return null;
  }

  void _resetForTimelineIndex(int timelineIndex) {
    if (_lastTimelineIndex == timelineIndex) return;
    _lastTimelineIndex = timelineIndex;
    _resetSustainedState();
  }

  void _resetSustainedState() {
    _deviationDirection = LivePaceGuidanceAction.none;
    _deviationStartedAt = null;
    _samples.clear();
  }

  bool _isEligibleForGuidance(LivePaceGuidanceInput input) {
    if (input.isPaused) return false;
    if (input.isTimerOnlyMode) return false;
    if (!input.isGpsReady) return false;
    if (input.currentPaceSecondsPerKm <= 0) return false;
    if (input.runElapsed < _runWarmupSkip) return false;
    if (input.blockElapsed < _blockWarmupSkip) return false;
    return true;
  }

  void _addSample(_PaceSample sample) {
    _samples.add(sample);
    final cutoff = sample.at - _sampleWindow;
    _samples.removeWhere((entry) => entry.at < cutoff);

    if (_samples.length > _sampleCountWindow) {
      _samples.removeRange(0, _samples.length - _sampleCountWindow);
    }
  }

  bool _isSustained(Duration nowElapsed) {
    if (_deviationStartedAt == null) return false;
    if (_samples.length < _minSampleCount) return false;
    if (nowElapsed - _deviationStartedAt! < _sampleWindow) return false;

    for (final sample in _samples) {
      if (sample.direction != _deviationDirection) {
        return false;
      }
    }

    return true;
  }

  LivePaceGuidanceAction _directionForPace({
    required int paceSeconds,
    required TargetZone zone,
    required int paceMin,
    required int paceMax,
  }) {
    final tolerance = _zoneTolerance(zone);
    final tooFastThreshold = paceMin - tolerance.tooFastSeconds;
    final tooSlowThreshold = paceMax + tolerance.tooSlowSeconds;

    if (paceSeconds <= tooFastThreshold) return LivePaceGuidanceAction.tooFast;
    if (paceSeconds >= tooSlowThreshold) return LivePaceGuidanceAction.tooSlow;

    return LivePaceGuidanceAction.none;
  }

  String? _messageKey({
    required LivePaceGuidanceAction action,
    required LivePaceGuidanceSeverity severity,
  }) {
    return switch (action) {
      LivePaceGuidanceAction.tooFast =>
        severity == LivePaceGuidanceSeverity.firm
            ? 'activeRunEaseOffFirm'
            : 'activeRunEaseOff',
      LivePaceGuidanceAction.tooSlow => 'activeRunPickUp',
      LivePaceGuidanceAction.none => null,
    };
  }

  LivePaceGuidanceSeverity _severity(
    LivePaceGuidanceAction action,
    TargetZone zone,
  ) {
    if (action == LivePaceGuidanceAction.tooFast &&
        (zone == TargetZone.easy ||
            zone == TargetZone.steady ||
            zone == TargetZone.longRun ||
            zone == TargetZone.recovery)) {
      return LivePaceGuidanceSeverity.firm;
    }

    return switch (action) {
      LivePaceGuidanceAction.tooFast => LivePaceGuidanceSeverity.gentle,
      LivePaceGuidanceAction.tooSlow => LivePaceGuidanceSeverity.gentle,
      LivePaceGuidanceAction.none => LivePaceGuidanceSeverity.none,
    };
  }

  _ZoneTolerance _zoneTolerance(TargetZone zone) {
    return switch (zone) {
      TargetZone.easy ||
      TargetZone.steady ||
      TargetZone.longRun ||
      TargetZone.recovery => const _ZoneTolerance(
        tooFastSeconds: 30,
        tooSlowSeconds: 70,
      ),
      TargetZone.tempo || TargetZone.threshold => const _ZoneTolerance(
        tooFastSeconds: 15,
        tooSlowSeconds: 15,
      ),
      TargetZone.racePace => const _ZoneTolerance(
        tooFastSeconds: 10,
        tooSlowSeconds: 10,
      ),
      TargetZone.interval => const _ZoneTolerance(
        tooFastSeconds: 9,
        tooSlowSeconds: 9,
      ),
    };
  }
}

class _PaceSample {
  const _PaceSample({required this.at, required this.direction});

  final Duration at;
  final LivePaceGuidanceAction direction;
}

class _ZoneTolerance {
  const _ZoneTolerance({
    required this.tooFastSeconds,
    required this.tooSlowSeconds,
  });

  final int tooFastSeconds;
  final int tooSlowSeconds;
}
