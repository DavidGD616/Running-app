import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../../core/utils/time_source.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../active_run_timeline.dart';
import '../../domain/run_live_activity_data.dart';
import '../run_live_activity_background_service.dart';
import '../run_live_activity_bridge.dart';
import '../active_run_session_provider.dart';
import '../active_run_progress_provider.dart';
import '../../../pre_run/presentation/run_flow_context.dart';
import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/workout_target.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class ActiveRunScreen extends ConsumerStatefulWidget {
  const ActiveRunScreen({super.key, this.args});

  final ActiveRunArgs? args;

  @override
  ConsumerState<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends ConsumerState<ActiveRunScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  late final ActiveRunTimeline _timeline;

  DateTime? _segmentStartedAt;
  DateTime? _lastTickAt;
  int _accumulatedActiveMs = 0;
  bool _activityStarted = false;
  // Set to false if POST_NOTIFICATIONS is denied; not reset mid-session.
  // User must restart the app after granting permission in Settings.
  bool _liveActivityNotificationsAllowed = true;
  Future<bool>? _notificationPermissionFuture;
  int _lastSentTimelineIndex = 0;
  double _lastSentDistanceMilestone = 0;
  DateTime _lastSentLiveActivityAt = DateTime.fromMillisecondsSinceEpoch(0);

  double _distanceKm = 0;
  double _blockDistanceKm = 0;
  Duration _blockElapsed = Duration.zero;
  int _timelineIndex = 0;
  bool _isPaused = false;
  bool _isSurging = false;
  DateTime _lastSavedProgressAt = DateTime.fromMillisecondsSinceEpoch(0);

  late final _session =
      widget.args?.session ?? ref.read(activeRunSessionProvider);
  late final _checkIn =
      widget.args?.checkIn ??
      ref.read(activeRunSessionProvider.notifier).checkIn;

  final _bridge = RunLiveActivityBridge.instance;
  final _backgroundService = RunLiveActivityBackgroundService.instance;
  StreamSubscription<RunServiceEvent>? _eventsSub;
  bool _finished = false;

  DateTime get _now => ref.read(timeSourceProvider).now();

  Duration get _currentElapsed {
    final seg = _segmentStartedAt;
    if (seg == null) return Duration(milliseconds: _accumulatedActiveMs);
    return Duration(milliseconds: _accumulatedActiveMs) + _now.difference(seg);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _timeline = ActiveRunTimeline.fromSession(_session);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _eventsSub = _bridge.events().listen(_onServiceEvent);

    final progress = ref.read(activeRunProgressProvider);
    if (progress != null) {
      final now = _now;
      _distanceKm = progress.distanceKm;
      _accumulatedActiveMs = progress.accumulatedActiveMs;
      _timelineIndex = progress.timelineIndex;
      _blockElapsed = Duration(milliseconds: progress.blockElapsedMs);
      _blockDistanceKm = progress.blockDistanceKm;
      _isPaused = progress.isPaused;
      _isSurging = progress.isSurging;
      // Activity was already started before the cold-start; mark it so we
      // don't call startActivity/start again and get duplicate services.
      _activityStarted = true;
      // Do NOT restore _lastTickAt — a stale timestamp would cause a phantom
      // distance jump on the first tick after restore. Let it default to 1s.
      if (progress.isPaused) {
        _segmentStartedAt = null;
        _lastTickAt = null;
      } else {
        _segmentStartedAt = now;
        _lastTickAt = now;
      }
      _lastSavedProgressAt = now;
    }
  }

  void _onServiceEvent(RunServiceEvent event) {
    if (_finished || !mounted) return;
    if (event.isFinished) {
      // Service ended (e.g. user dismissed notification action).
      // Mirror final state so log-run reflects authoritative numbers.
      _distanceKm = event.distanceKm;
      _accumulatedActiveMs = event.elapsedMs;
      _segmentStartedAt = null;
      _finishRun();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventsSub?.cancel();
    _timer?.cancel();
    // Only tear down the live activity and background service when the run was
    // intentionally finished. If the widget is disposed for any other reason
    // (navigation away, OS reclaim) the service must keep running so the user
    // can return and resume.
    if (_finished) {
      _backgroundService.stop();
      _bridge.endActivity();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // Save immediately when the app is backgrounded so iOS has the latest
    // progress if it suspends the Dart engine before the next 5s tick.
    if (!_finished &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.detached)) {
      await _saveProgress();
      _lastSavedProgressAt = _now;
      return;
    }
    if (state != AppLifecycleState.resumed || _isPaused) return;
    final snapshot = await _bridge.getRunState();
    if (!mounted) return;
    if (snapshot != null && snapshot.seeded && !snapshot.isPaused) {
      final currentElapsedMs = _currentElapsed.inMilliseconds;
      final deltaMs = snapshot.elapsedMs - currentElapsedMs;
      final deltaKm = snapshot.distanceKm - _distanceKm;
      if (deltaMs > 0 || deltaKm > 0) {
        setState(() {
          if (deltaMs > 0) {
            _accumulatedActiveMs += deltaMs;
          }
          _segmentStartedAt = _now;
          _lastTickAt = _now;
          if (deltaKm > 0) {
            _distanceKm = snapshot.distanceKm;
          }
          // Adopt service's authoritative block tracking so labels stay aligned
          // even after multi-block transitions during background.
          if (snapshot.blockIndex >= 0 &&
              snapshot.blockIndex < _timeline.blocks.length) {
            _timelineIndex = snapshot.blockIndex;
          }
          _blockElapsed = Duration(milliseconds: snapshot.blockElapsedMs);
          _blockDistanceKm = snapshot.blockDistanceKm;
          _advanceTimeline();
        });
        _maybeSendActivityUpdate(wasFirstTick: false);
        return;
      }
    }
    _tick();
  }

  void _tick() {
    if (_isPaused) {
      _lastTickAt = null;
      return;
    }

    final now = _now;
    final wasFirstTick = _segmentStartedAt == null && _accumulatedActiveMs == 0;
    _segmentStartedAt ??= now;

    final lastTick = _lastTickAt;
    final deltaSeconds = lastTick == null
        ? 1.0
        : (now.difference(lastTick).inMilliseconds / 1000.0).clamp(0.0, 3600.0);
    _lastTickAt = now;

    setState(() {
      final distanceDeltaKm = _kmPerSecond * _paceMultiplier * deltaSeconds;
      _distanceKm += distanceDeltaKm;
      _blockDistanceKm += distanceDeltaKm;
      _blockElapsed += Duration(milliseconds: (deltaSeconds * 1000).round());
      _advanceTimeline();
    });

    final timeSinceLastSave = _now.difference(_lastSavedProgressAt);
    if (timeSinceLastSave.inSeconds >= 5) {
      unawaited(_saveProgress());
      _lastSavedProgressAt = _now;
    }

    _maybeSendActivityUpdate(wasFirstTick: wasFirstTick);
  }

  void _advanceTimeline() {
    while (true) {
      final block = _currentBlock;
      if (block == null || _timelineIndex >= _timeline.blocks.length - 1) {
        return;
      }
      final isDurationComplete =
          block.duration != null && _blockElapsed >= block.duration!;
      final isDistanceComplete =
          block.distanceMeters != null &&
          _blockDistanceKm * 1000 >= block.distanceMeters!;
      if (!isDurationComplete && !isDistanceComplete) return;

      _timelineIndex += 1;
      _blockElapsed = Duration.zero;
      _blockDistanceKm = 0;
    }
  }

  ActiveRunTimelineBlock? get _currentBlock {
    if (_timeline.isEmpty) return null;
    return _timeline.blocks[_timelineIndex.clamp(
      0,
      _timeline.blocks.length - 1,
    )];
  }

  ActiveRunTimelineBlock? get _nextBlock {
    if (_timelineIndex >= _timeline.blocks.length - 1) return null;
    return _timeline.blocks[_timelineIndex + 1];
  }

  double get _kmPerSecond {
    final session = _session;
    final plannedKm = session?.distanceKm ?? 6.0;
    final plannedSeconds = (session?.durationMinutes ?? 45) * 60;
    if (plannedSeconds <= 0) return 0.0022;
    return plannedKm / plannedSeconds;
  }

  double get _paceMultiplier {
    final type = _session?.sessionType ?? SessionType.easyRun;
    final elapsed = _currentElapsed;
    final cycle = elapsed.inSeconds % 12;
    final drift = cycle < 4
        ? 1.04
        : cycle < 8
        ? 0.96
        : 1.0;

    final block = _currentBlock;
    if (block != null) {
      return switch (block.kind) {
        ActiveRunBlockKind.work => switch (type) {
          SessionType.intervals => 1.22,
          SessionType.hillRepeats => 1.16,
          SessionType.tempoRun ||
          SessionType.thresholdRun ||
          SessionType.racePaceRun => 1.08,
          _ => 1.0,
        },
        ActiveRunBlockKind.recovery => 0.72,
        ActiveRunBlockKind.coolDown => 0.78,
        ActiveRunBlockKind.warmUp => 0.86,
      };
    }

    if (type == SessionType.intervals || type == SessionType.hillRepeats) {
      return _isWorkBlock ? 1.22 : 0.72;
    }
    if (type == SessionType.fartlek && _isSurging) return 1.18;
    if (type == SessionType.recoveryRun) return 0.88;
    if (type == SessionType.racePaceRun) return 1.08;
    return drift;
  }

  bool get _isWorkBlock {
    final currentBlock = _currentBlock;
    if (currentBlock != null) {
      return currentBlock.kind == ActiveRunBlockKind.work;
    }
    final elapsed = _currentElapsed;
    final blockIndex = elapsed.inSeconds ~/ 90;
    return blockIndex.isEven;
  }

  int get _currentRep {
    final block = _currentBlock;
    if (block?.repIndex != null) return block!.repIndex!;
    final reps = _session?.intervalReps ?? 6;
    final rep = (_currentElapsed.inSeconds ~/ 180) + 1;
    return rep > reps ? reps : rep;
  }

  Duration get _blockRemaining {
    final block = _currentBlock;
    if (block?.duration != null) {
      final remaining = block!.duration! - _blockElapsed;
      return remaining.isNegative ? Duration.zero : remaining;
    }
    final blockLength = _isWorkBlock ? 90 : 90;
    final seconds = blockLength - (_currentElapsed.inSeconds % blockLength);
    return Duration(seconds: seconds);
  }

  double get _averagePaceSecondsPerKm {
    if (_distanceKm <= 0.01) return _plannedPaceSecondsPerKm;
    return _currentElapsed.inSeconds / _distanceKm;
  }

  double get _currentPaceSecondsPerKm {
    final pace = _plannedPaceSecondsPerKm / _paceMultiplier;
    return pace.clamp(210, 780).toDouble();
  }

  double get _plannedPaceSecondsPerKm {
    final session = _session;
    final plannedKm = session?.distanceKm ?? 6.0;
    final plannedSeconds = (session?.durationMinutes ?? 45) * 60;
    if (plannedKm <= 0 || plannedSeconds <= 0) return 450;
    return plannedSeconds / plannedKm;
  }

  Future<void> _saveProgress() {
    final elapsed = _currentElapsed;
    final progress = ActiveRunProgress(
      distanceKm: _distanceKm,
      accumulatedActiveMs: elapsed.inMilliseconds,
      timelineIndex: _timelineIndex,
      blockElapsedMs: _blockElapsed.inMilliseconds,
      blockDistanceKm: _blockDistanceKm,
      currentRep: _currentRep,
      isPaused: _isPaused,
      isSurging: _isSurging,
      segmentStartedAtMs: _segmentStartedAt?.millisecondsSinceEpoch,
      lastTickAtMs: _lastTickAt?.millisecondsSinceEpoch,
    );
    return ref.read(activeRunProgressProvider.notifier).save(progress);
  }

  void _finishRun() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    _backgroundService.stop();
    _bridge.endActivity();
    ref.read(activeRunSessionProvider.notifier).clear();
    ref.read(activeRunProgressProvider.notifier).clear();
    context.push(
      RouteNames.logRun,
      extra: LogRunArgs(
        session: _session,
        checkIn: _checkIn,
        actualDuration: _currentElapsed,
        actualDistanceKm: _distanceKm,
      ),
    );
  }

  void _togglePause() {
    setState(() {
      final now = _now;
      _isPaused = !_isPaused;
      if (_isPaused) {
        final segmentStartedAt = _segmentStartedAt;
        if (segmentStartedAt != null) {
          _accumulatedActiveMs += now
              .difference(segmentStartedAt)
              .inMilliseconds;
        }
        _segmentStartedAt = null;
        _lastTickAt = null;
      } else {
        _segmentStartedAt = now;
        _lastTickAt = now;
      }
    });
    _maybeSendActivityUpdate(wasFirstTick: false, isPauseToggle: true);
  }

  Future<void> _maybeSendActivityUpdate({
    required bool wasFirstTick,
    bool isPauseToggle = false,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    if (!_liveActivityNotificationsAllowed) return;

    final shouldStart = !_activityStarted;
    final timelineChanged = _timelineIndex != _lastSentTimelineIndex;
    final currentMilestone = (_distanceKm * 10).floor() * 0.1;
    final milestoneCrossed = currentMilestone > _lastSentDistanceMilestone;
    final timeSinceLastUpdate = _now.difference(_lastSentLiveActivityAt);
    final periodicUpdate = timeSinceLastUpdate.inSeconds >= 1;

    if (!shouldStart &&
        !timelineChanged &&
        !milestoneCrossed &&
        !isPauseToggle &&
        !periodicUpdate) {
      return;
    }

    if (shouldStart && !await _ensureLiveActivityNotificationsAllowed()) {
      _liveActivityNotificationsAllowed = false;
      return;
    }

    if (timelineChanged) {
      _lastSentTimelineIndex = _timelineIndex;
    }
    if (milestoneCrossed) {
      _lastSentDistanceMilestone = currentMilestone;
    }

    final data = _buildLiveActivityData();
    if (shouldStart) {
      _activityStarted = true;
      _bridge.startActivity(data);
      _backgroundService.start(data);
    } else {
      _bridge.updateActivity(data);
      _backgroundService.update(data);
    }
    _lastSentLiveActivityAt = _now;
  }

  RunLiveActivityData _buildLiveActivityData() {
    final l10n = AppLocalizations.of(context)!;
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;
    final session = _session;
    final type = session?.sessionType ?? SessionType.easyRun;
    final elapsed = _currentElapsed;
    final currentBlock = _currentBlock;
    final nextBlock = _nextBlockLabel(type, l10n);
    final totalReps = currentBlock?.totalReps ?? session?.intervalReps ?? 6;
    final repLabel =
        (type == SessionType.intervals || type == SessionType.hillRepeats)
        ? '${l10n.activeRunRep} $_currentRep / $totalReps'
        : null;

    return RunLiveActivityData(
      workoutName: _sessionTitle(type, l10n),
      elapsedSeconds: elapsed.inSeconds,
      elapsedLabel: _formatDuration(elapsed),
      elapsedUnitLabel: l10n.activeRunTimeUnit,
      distanceTitleLabel: l10n.activeRunNotificationDistanceShort,
      distanceLabel: _formatLiveActivityDistance(unitSystem, l10n),
      currentPaceShortTitleLabel: l10n.activeRunNotificationPaceShort,
      currentPaceLabel:
          '${_formatPace(_currentPaceSecondsPerKm, unitSystem)} /${UnitFormatter.unitLabel(unitSystem, l10n)}',
      currentPaceTitleLabel: l10n.activeRunCurrentPace,
      avgPaceLabel:
          '${_formatPace(_averagePaceSecondsPerKm, unitSystem)} /${UnitFormatter.unitLabel(unitSystem, l10n)}',
      avgPaceTitleLabel: l10n.activeRunAveragePace,
      currentBlockLabel: _currentBlockLabel(currentBlock, type, l10n),
      nextBlockLabel: nextBlock == null
          ? null
          : l10n.activeRunNextBlock(nextBlock),
      repLabel: repLabel,
      isPaused: _isPaused,
      distanceKm: _distanceKm,
      paceSecondsPerKm: _currentPaceSecondsPerKm.round(),
      unitFactor: unitSystem == UnitSystem.km ? 1.0 : 0.621371,
      distanceUnit: UnitFormatter.unitLabel(unitSystem, l10n),
      paceUnit: UnitFormatter.paceLabel(unitSystem, l10n),
      plannedDistanceKm: session?.distanceKm,
      plannedDurationMs: session?.durationMinutes == null
          ? null
          : session!.durationMinutes! * 60 * 1000,
      timeline: _buildLiveActivityTimeline(type, l10n),
      blockProgressFraction: _computeBlockProgressFraction(currentBlock),
      plannedPaceLabel: _plannedPaceSecondsPerKm > 0
          ? '${_formatPace(_plannedPaceSecondsPerKm, unitSystem)} /${UnitFormatter.unitLabel(unitSystem, l10n)}'
          : '',
      blockRemainingLabel: _computeBlockRemainingLabel(
        currentBlock,
        unitSystem,
        l10n,
      ),
    );
  }

  List<RunLiveActivityTimelineBlock>? _buildLiveActivityTimeline(
    SessionType type,
    AppLocalizations l10n,
  ) {
    if (_timeline.isEmpty) return null;
    final blocks = _timeline.blocks;
    return List.generate(blocks.length, (i) {
      final block = blocks[i];
      final next = i + 1 < blocks.length ? blocks[i + 1] : null;
      final blockLabel = _currentBlockLabel(block, type, l10n);
      final nextLabel = next == null
          ? null
          : l10n.activeRunNextBlock(_currentBlockLabel(next, type, l10n));
      final repLabel =
          (type == SessionType.intervals || type == SessionType.hillRepeats) &&
              block.repIndex != null &&
              block.totalReps != null
          ? '${l10n.activeRunRep} ${block.repIndex} / ${block.totalReps}'
          : null;
      return RunLiveActivityTimelineBlock(
        durationMs: block.duration?.inMilliseconds,
        distanceMeters: block.distanceMeters,
        blockLabel: blockLabel,
        nextLabel: nextLabel,
        repLabel: repLabel,
      );
    });
  }

  double _computeBlockProgressFraction(ActiveRunTimelineBlock? block) {
    if (block == null) return 0.0;
    if (block.duration != null && block.duration! > Duration.zero) {
      return (_blockElapsed.inMilliseconds / block.duration!.inMilliseconds)
          .clamp(0.0, 1.0);
    }
    if (block.distanceMeters != null && block.distanceMeters! > 0) {
      return ((_blockDistanceKm * 1000) / block.distanceMeters!).clamp(
        0.0,
        1.0,
      );
    }
    return 0.0;
  }

  String? _computeBlockRemainingLabel(
    ActiveRunTimelineBlock? block,
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    if (block == null) return null;
    if (block.duration != null && block.duration! > Duration.zero) {
      final remaining = block.duration! - _blockElapsed;
      if (remaining.inSeconds <= 0) return null;
      return '${_formatDuration(remaining)} left';
    }
    if (block.distanceMeters != null && block.distanceMeters! > 0) {
      final remainingKm = (block.distanceMeters! / 1000.0) - _blockDistanceKm;
      if (remainingKm <= 0.005) return null;
      final dist = UnitFormatter.formatDistanceWithUnit(
        remainingKm,
        unitSystem,
        l10n,
      );
      return '$dist left';
    }
    return null;
  }

  Future<bool> _ensureLiveActivityNotificationsAllowed() {
    if (!Platform.isAndroid) return Future.value(true);
    final existingFuture = _notificationPermissionFuture;
    if (existingFuture != null) return existingFuture;

    return _notificationPermissionFuture = () async {
      final sdkInt = await _bridge.androidSdkInt();
      if (sdkInt != null && sdkInt < 33) return true;
      final status = await Permission.notification.request();
      return status.isGranted || status.isLimited || status.isProvisional;
    }();
  }

  String _currentBlockLabel(
    ActiveRunTimelineBlock? block,
    SessionType type,
    AppLocalizations l10n,
  ) {
    if (block == null) return _targetValue(type, l10n);
    return switch (block.kind) {
      ActiveRunBlockKind.warmUp => l10n.sessionDetailWarmUp,
      ActiveRunBlockKind.work =>
        type == SessionType.hillRepeats
            ? l10n.activeRunClimb
            : l10n.activeRunFastRep,
      ActiveRunBlockKind.recovery => l10n.activeRunRecovery,
      ActiveRunBlockKind.coolDown => l10n.sessionDetailCoolDown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;
    final session = _session;
    final type = session?.sessionType ?? SessionType.easyRun;
    final title = _sessionTitle(type, l10n);
    final plannedSummary = _plannedSummary(session, unitSystem, l10n);
    final currentBlock = _currentBlock;
    final totalReps = currentBlock?.totalReps ?? session?.intervalReps ?? 6;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.activeRunTitle,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTypography.headlineLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                plannedSummary,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _HeroPaceCard(
                      label: l10n.activeRunCurrentPace,
                      value: _formatPace(_currentPaceSecondsPerKm, unitSystem),
                      unit: UnitFormatter.paceLabel(unitSystem, l10n),
                      guidance: _guidanceFor(type, l10n),
                      color: _accentFor(type),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            iconAsset: 'assets/icons/clock.svg',
                            label: l10n.activeRunElapsed,
                            value: _formatDuration(_currentElapsed),
                            unit: l10n.activeRunTimeUnit,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _MetricTile(
                            iconAsset: 'assets/icons/distance.svg',
                            label: l10n.activeRunDistance,
                            value: UnitFormatter.formatDistanceValue(
                              _distanceKm,
                              unitSystem,
                            ),
                            unit: UnitFormatter.unitLabel(unitSystem, l10n),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            iconAsset: 'assets/icons/pace.svg',
                            label: l10n.activeRunAveragePace,
                            value: _formatPace(
                              _averagePaceSecondsPerKm,
                              unitSystem,
                            ),
                            unit: UnitFormatter.paceLabel(unitSystem, l10n),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _MetricTile(
                            iconAsset: 'assets/icons/target.svg',
                            label: l10n.activeRunTarget,
                            value: _targetValueFor(type, currentBlock, l10n),
                            unit: _targetUnit(type, l10n),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _WorkoutFocusPanel(
                      type: type,
                      currentRep: _currentRep,
                      totalReps: totalReps,
                      blockRemainingLabel: _blockRemainingLabel(
                        currentBlock,
                        unitSystem,
                        l10n,
                      ),
                      currentBlock: currentBlock,
                      nextBlockLabel: _nextBlockLabel(type, l10n),
                      isWorkBlock: _isWorkBlock,
                      isSurging: _isSurging,
                      onToggleSurge: () {
                        setState(() => _isSurging = !_isSurging);
                        _maybeSendActivityUpdate(wasFirstTick: false);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              decoration: const BoxDecoration(
                color: AppColors.backgroundPrimary,
                border: Border(top: BorderSide(color: AppColors.borderDefault)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: _isPaused
                          ? l10n.activeRunResume
                          : l10n.activeRunPause,
                      variant: AppButtonVariant.secondary,
                      onPressed: _togglePause,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: l10n.activeRunFinish,
                      onPressed: _finishRun,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _plannedSummary(
    RunFlowSessionContext? session,
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    final duration = session?.durationMinutes;
    final distance = session?.distanceKm;
    if (duration != null && distance != null) {
      return l10n.activeRunPlannedSummary(
        UnitFormatter.formatDuration(duration, l10n),
        UnitFormatter.formatDistanceWithUnit(distance, unitSystem, l10n),
      );
    }
    if (duration != null) {
      return l10n.activeRunPlannedDuration(
        UnitFormatter.formatDuration(duration, l10n),
      );
    }
    if (distance != null) {
      return l10n.activeRunPlannedDistance(
        UnitFormatter.formatDistanceWithUnit(distance, unitSystem, l10n),
      );
    }
    return '';
  }

  String _sessionTitle(SessionType type, AppLocalizations l10n) {
    switch (type) {
      case SessionType.restDay:
        return l10n.sessionTypeRestDay;
      case SessionType.easyRun:
        return l10n.weeklyPlanSessionEasyRun;
      case SessionType.longRun:
        return l10n.weeklyPlanSessionLongRun;
      case SessionType.progressionRun:
        return l10n.sessionTypeProgressionRun;
      case SessionType.intervals:
        return l10n.weeklyPlanSessionIntervals;
      case SessionType.hillRepeats:
        return l10n.sessionTypeHillRepeats;
      case SessionType.fartlek:
        return l10n.sessionTypeFartlek;
      case SessionType.tempoRun:
        return l10n.sessionTypeTempoRun;
      case SessionType.thresholdRun:
        return l10n.sessionTypeThresholdRun;
      case SessionType.racePaceRun:
        return l10n.sessionTypeRacePaceRun;
      case SessionType.recoveryRun:
        return l10n.weeklyPlanSessionRecoveryRun;
      case SessionType.crossTraining:
        return l10n.sessionTypeCrossTraining;
    }
  }

  String _guidanceFor(SessionType type, AppLocalizations l10n) {
    return switch (type) {
      SessionType.easyRun => l10n.activeRunGuidanceEasy,
      SessionType.longRun => l10n.activeRunGuidanceLong,
      SessionType.progressionRun => l10n.activeRunGuidanceProgression,
      SessionType.intervals => l10n.activeRunGuidanceIntervals,
      SessionType.hillRepeats => l10n.activeRunGuidanceHills,
      SessionType.fartlek => l10n.activeRunGuidanceFartlek,
      SessionType.tempoRun => l10n.activeRunGuidanceTempo,
      SessionType.thresholdRun => l10n.activeRunGuidanceThreshold,
      SessionType.racePaceRun => l10n.activeRunGuidanceRacePace,
      SessionType.recoveryRun => l10n.activeRunGuidanceRecovery,
      SessionType.crossTraining => l10n.activeRunGuidanceEasy,
      SessionType.restDay => l10n.activeRunGuidanceRecovery,
    };
  }

  Color _accentFor(SessionType type) {
    return switch (type.category) {
      SessionCategory.endurance => AppColors.accentPrimary,
      SessionCategory.speedWork => AppColors.info,
      SessionCategory.threshold => AppColors.warning,
      SessionCategory.raceSpecific => AppColors.error,
      SessionCategory.recovery => AppColors.accentLight,
      SessionCategory.rest => AppColors.textSecondary,
    };
  }

  String _targetValueFor(
    SessionType type,
    ActiveRunTimelineBlock? block,
    AppLocalizations l10n,
  ) {
    if (block == null) return _targetValue(type, l10n);

    final target = block.target;
    final zone = target?.zone;
    if (zone != null) {
      return switch (zone) {
        TargetZone.recovery => l10n.activeRunTargetEasy,
        TargetZone.easy => l10n.activeRunTargetEasy,
        TargetZone.steady => l10n.activeRunTargetSteady,
        TargetZone.tempo => l10n.activeRunTargetTempo,
        TargetZone.threshold => l10n.activeRunTargetThreshold,
        TargetZone.interval =>
          type == SessionType.hillRepeats
              ? l10n.activeRunTargetClimb
              : l10n.activeRunTargetFast,
        TargetZone.racePace => l10n.activeRunTargetRace,
        TargetZone.longRun => l10n.activeRunTargetSteady,
      };
    }

    return switch (block.kind) {
      ActiveRunBlockKind.warmUp => l10n.sessionDetailWarmUp,
      ActiveRunBlockKind.work => _targetValue(type, l10n),
      ActiveRunBlockKind.recovery => l10n.activeRunRecovery,
      ActiveRunBlockKind.coolDown => l10n.sessionDetailCoolDown,
    };
  }

  String _targetValue(SessionType type, AppLocalizations l10n) {
    return switch (type) {
      SessionType.intervals => l10n.activeRunTargetFast,
      SessionType.hillRepeats => l10n.activeRunTargetClimb,
      SessionType.tempoRun => l10n.activeRunTargetTempo,
      SessionType.thresholdRun => l10n.activeRunTargetThreshold,
      SessionType.racePaceRun => l10n.activeRunTargetRace,
      SessionType.recoveryRun => l10n.activeRunTargetEasy,
      SessionType.longRun => l10n.activeRunTargetSteady,
      SessionType.progressionRun => l10n.activeRunTargetBuild,
      SessionType.fartlek => l10n.activeRunTargetSurges,
      SessionType.easyRun => l10n.activeRunTargetEasy,
      SessionType.crossTraining => l10n.activeRunTargetSteady,
      SessionType.restDay => l10n.activeRunTargetEasy,
    };
  }

  String _targetUnit(SessionType type, AppLocalizations l10n) {
    return switch (type) {
      SessionType.intervals ||
      SessionType.hillRepeats ||
      SessionType.tempoRun ||
      SessionType.thresholdRun ||
      SessionType.racePaceRun => l10n.activeRunTargetPaceUnit,
      _ => l10n.activeRunTargetEffortUnit,
    };
  }

  String _blockRemainingLabel(
    ActiveRunTimelineBlock? block,
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    if (block?.distanceMeters != null) {
      final remainingMeters =
          block!.distanceMeters! - (_blockDistanceKm * 1000).round();
      final value = UnitFormatter.formatWorkoutRepDistance(
        remainingMeters.clamp(0, block.distanceMeters!),
        unitSystem,
        l10n,
      );
      return l10n.activeRunBlockRemaining(value);
    }

    return l10n.activeRunBlockRemaining(_formatDuration(_blockRemaining));
  }

  String? _nextBlockLabel(SessionType type, AppLocalizations l10n) {
    final block = _nextBlock;
    if (block == null) return null;
    return _currentBlockLabel(block, type, l10n);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  String _formatPace(double secondsPerKm, UnitSystem unitSystem) {
    final seconds = unitSystem == UnitSystem.km
        ? secondsPerKm.round()
        : (secondsPerKm * 1.609344).round();
    final minutes = seconds ~/ 60;
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  String _formatLiveActivityDistance(
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    final value = UnitFormatter.distanceValue(_distanceKm, unitSystem);
    final formatted = value < 1
        ? value.toStringAsFixed(2)
        : value.toStringAsFixed(1);
    return '$formatted ${UnitFormatter.unitLabel(unitSystem, l10n)}';
  }
}

class _HeroPaceCard extends StatelessWidget {
  const _HeroPaceCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.guidance,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final String guidance;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderXl,
        border: Border.all(color: color.withValues(alpha: 0.44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineLarge.copyWith(
                    fontSize: 56,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  unit,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            guidance,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String iconAsset;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                  AppColors.accentPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutFocusPanel extends StatelessWidget {
  const _WorkoutFocusPanel({
    required this.type,
    required this.currentRep,
    required this.totalReps,
    required this.blockRemainingLabel,
    required this.currentBlock,
    required this.nextBlockLabel,
    required this.isWorkBlock,
    required this.isSurging,
    required this.onToggleSurge,
  });

  final SessionType type;
  final int currentRep;
  final int totalReps;
  final String blockRemainingLabel;
  final ActiveRunTimelineBlock? currentBlock;
  final String? nextBlockLabel;
  final bool isWorkBlock;
  final bool isSurging;
  final VoidCallback onToggleSurge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (currentBlock != null &&
        (type == SessionType.intervals || type == SessionType.hillRepeats)) {
      final blockName = _blockLabel(currentBlock!, type, l10n);
      final next = nextBlockLabel;
      return _FocusCard(
        iconAsset: type == SessionType.hillRepeats
            ? 'assets/icons/mountain.svg'
            : 'assets/icons/zap.svg',
        title: type == SessionType.hillRepeats
            ? l10n.activeRunHillFocusTitle
            : l10n.activeRunIntervalFocusTitle,
        primaryLabel: l10n.activeRunCurrentBlock,
        primaryValue: blockName,
        secondaryLabel: currentBlock!.isRepBlock
            ? l10n.activeRunRep
            : l10n.activeRunTarget,
        secondaryValue: currentBlock!.isRepBlock
            ? '$currentRep / $totalReps'
            : _targetLabel(currentBlock!, type, l10n),
        footer: next == null
            ? blockRemainingLabel
            : '$blockRemainingLabel · ${l10n.activeRunNextBlock(next)}',
      );
    }

    if (type == SessionType.intervals || type == SessionType.hillRepeats) {
      return _FocusCard(
        iconAsset: type == SessionType.hillRepeats
            ? 'assets/icons/mountain.svg'
            : 'assets/icons/zap.svg',
        title: type == SessionType.hillRepeats
            ? l10n.activeRunHillFocusTitle
            : l10n.activeRunIntervalFocusTitle,
        primaryLabel: l10n.activeRunCurrentBlock,
        primaryValue: isWorkBlock
            ? type == SessionType.hillRepeats
                  ? l10n.activeRunClimb
                  : l10n.activeRunFastRep
            : l10n.activeRunRecovery,
        secondaryLabel: l10n.activeRunRep,
        secondaryValue: '$currentRep / $totalReps',
        footer: blockRemainingLabel,
      );
    }

    if (type == SessionType.progressionRun) {
      return _PhaseCard(
        title: l10n.activeRunProgressionFocusTitle,
        activeIndex: _progressionIndex(currentBlock),
        phases: [
          l10n.activeRunEasyBlock,
          l10n.activeRunSteadyBlock,
          l10n.activeRunStrongBlock,
        ],
      );
    }

    if (type == SessionType.fartlek) {
      return _FartlekCard(isSurging: isSurging, onToggle: onToggleSurge);
    }

    if (type == SessionType.tempoRun ||
        type == SessionType.thresholdRun ||
        type == SessionType.racePaceRun) {
      return _FocusCard(
        iconAsset: 'assets/icons/target.svg',
        title: l10n.activeRunPaceFocusTitle,
        primaryLabel: l10n.activeRunTarget,
        primaryValue: switch (type) {
          SessionType.tempoRun => l10n.activeRunTargetTempo,
          SessionType.thresholdRun => l10n.activeRunTargetThreshold,
          _ => l10n.activeRunTargetRace,
        },
        secondaryLabel: l10n.activeRunControl,
        secondaryValue: l10n.activeRunOnTarget,
        footer: l10n.activeRunPaceFocusFooter,
      );
    }

    if (type == SessionType.longRun) {
      return _FocusCard(
        iconAsset: 'assets/icons/flame.svg',
        title: l10n.activeRunLongFocusTitle,
        primaryLabel: l10n.activeRunFocus,
        primaryValue: l10n.activeRunTargetSteady,
        secondaryLabel: l10n.activeRunReminder,
        secondaryValue: l10n.activeRunFuel,
        footer: l10n.activeRunLongFocusFooter,
      );
    }

    return _FocusCard(
      iconAsset: 'assets/icons/route.svg',
      title: type == SessionType.recoveryRun
          ? l10n.activeRunRecoveryFocusTitle
          : l10n.activeRunEasyFocusTitle,
      primaryLabel: l10n.activeRunFocus,
      primaryValue: type == SessionType.recoveryRun
          ? l10n.activeRunTargetEasy
          : l10n.activeRunTargetSteady,
      secondaryLabel: l10n.activeRunControl,
      secondaryValue: l10n.activeRunRelaxed,
      footer: type == SessionType.recoveryRun
          ? l10n.activeRunRecoveryFocusFooter
          : l10n.activeRunEasyFocusFooter,
    );
  }

  int _progressionIndex(ActiveRunTimelineBlock? block) {
    if (block != null) {
      return switch (block.kind) {
        ActiveRunBlockKind.warmUp => 0,
        ActiveRunBlockKind.work => 1,
        ActiveRunBlockKind.recovery => 1,
        ActiveRunBlockKind.coolDown => 2,
      };
    }
    final cycle = DateTime.now().second % 45;
    if (cycle < 15) return 0;
    if (cycle < 30) return 1;
    return 2;
  }

  String _blockLabel(
    ActiveRunTimelineBlock block,
    SessionType type,
    AppLocalizations l10n,
  ) {
    return switch (block.kind) {
      ActiveRunBlockKind.warmUp => l10n.sessionDetailWarmUp,
      ActiveRunBlockKind.work =>
        type == SessionType.hillRepeats
            ? l10n.activeRunClimb
            : l10n.activeRunFastRep,
      ActiveRunBlockKind.recovery => l10n.activeRunRecovery,
      ActiveRunBlockKind.coolDown => l10n.sessionDetailCoolDown,
    };
  }

  String _targetLabel(
    ActiveRunTimelineBlock block,
    SessionType type,
    AppLocalizations l10n,
  ) {
    final blockTarget = block.target;
    final zone = blockTarget?.zone;
    if (zone != null) {
      return switch (zone) {
        TargetZone.recovery => l10n.activeRunTargetEasy,
        TargetZone.easy => l10n.activeRunTargetEasy,
        TargetZone.steady => l10n.activeRunTargetSteady,
        TargetZone.tempo => l10n.activeRunTargetTempo,
        TargetZone.threshold => l10n.activeRunTargetThreshold,
        TargetZone.interval =>
          type == SessionType.hillRepeats
              ? l10n.activeRunTargetClimb
              : l10n.activeRunTargetFast,
        TargetZone.racePace => l10n.activeRunTargetRace,
        TargetZone.longRun => l10n.activeRunTargetSteady,
      };
    }
    return _blockLabel(block, type, l10n);
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.iconAsset,
    required this.title,
    required this.primaryLabel,
    required this.primaryValue,
    required this.secondaryLabel,
    required this.secondaryValue,
    required this.footer,
  });

  final String iconAsset;
  final String title;
  final String primaryLabel;
  final String primaryValue;
  final String secondaryLabel;
  final String secondaryValue;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppColors.accentPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _FocusStat(label: primaryLabel, value: primaryValue),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _FocusStat(label: secondaryLabel, value: secondaryValue),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            footer,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusStat extends StatelessWidget {
  const _FocusStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: AppRadius.borderMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.title,
    required this.activeIndex,
    required this.phases,
  });

  final String title;
  final int activeIndex;
  final List<String> phases;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (var i = 0; i < phases.length; i++) ...[
                Expanded(
                  child: _PhaseStep(
                    label: phases[i],
                    isActive: i == activeIndex,
                  ),
                ),
                if (i != phases.length - 1)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PhaseStep extends StatelessWidget {
  const _PhaseStep({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 72,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accentMuted : AppColors.backgroundElevated,
        borderRadius: AppRadius.borderMd,
        border: Border.all(
          color: isActive ? AppColors.accentPrimary : AppColors.borderDefault,
        ),
      ),
      child: Center(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.labelMedium.copyWith(
            color: isActive ? AppColors.accentPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FartlekCard extends StatelessWidget {
  const _FartlekCard({required this.isSurging, required this.onToggle});

  final bool isSurging;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.activeRunFartlekFocusTitle,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _FocusStat(
            label: l10n.activeRunCurrentBlock,
            value: isSurging ? l10n.activeRunSurge : l10n.activeRunEasyBlock,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: isSurging
                ? l10n.activeRunEndSurge
                : l10n.activeRunStartSurge,
            variant: AppButtonVariant.secondary,
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}
