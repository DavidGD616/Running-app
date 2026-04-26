import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../active_run_controller.dart';
import '../active_run_live_activity_mapper.dart';
import '../active_run_live_activity_sync.dart';
import '../active_run_timeline.dart';
import '../../domain/models/gps_state.dart';
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
  late final _session =
      widget.args?.session ?? ref.read(activeRunSessionProvider);
  late final _checkIn =
      widget.args?.checkIn ??
      ref.read(activeRunSessionProvider.notifier).checkIn;

  final _bridge = RunLiveActivityBridge.instance;
  final _backgroundService = RunLiveActivityBackgroundService.instance;
  late final ActiveRunLiveActivitySync _syncCoordinator =
      ActiveRunLiveActivitySync(
        bridge: _bridge,
        backgroundService: _backgroundService,
      );
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(activeRunControllerProvider.notifier)
          .start(
            ActiveRunStartInput(
              session: _session,
              checkIn: _checkIn,
              timerOnlyMode:
                  widget.args?.timerOnlyMode ??
                  ref.read(activeRunProgressProvider)?.timerOnlyMode ??
                  false,
            ),
          );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_finished) {
      _syncCoordinator.end();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_finished) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.detached) {
        ref.read(activeRunControllerProvider.notifier).onAppBackground();
      }
    }
  }

  int get _currentRep {
    final state = ref.watch(activeRunControllerProvider);
    final block = state.currentBlock;
    if (block?.repIndex != null) return block!.repIndex!;
    final reps = _session?.intervalReps ?? 6;
    final rep = (state.elapsed.inSeconds ~/ 180) + 1;
    return rep > reps ? reps : rep;
  }

  Duration get _blockRemaining {
    final state = ref.watch(activeRunControllerProvider);
    final block = state.currentBlock;
    if (block?.duration != null) {
      final remaining = block!.duration! - state.blockElapsed;
      return remaining.isNegative ? Duration.zero : remaining;
    }
    return Duration.zero;
  }

  double get _plannedPaceSecondsPerKm {
    final session = _session;
    final plannedKm = session?.distanceKm ?? 6.0;
    final plannedSeconds = (session?.durationMinutes ?? 45) * 60;
    if (plannedKm <= 0 || plannedSeconds <= 0) return 450;
    return plannedSeconds / plannedKm;
  }

  bool get _isWorkBlock {
    final state = ref.watch(activeRunControllerProvider);
    final currentBlock = state.currentBlock;
    if (currentBlock != null) {
      return currentBlock.kind == ActiveRunBlockKind.work ||
          currentBlock.kind == ActiveRunBlockKind.stride;
    }
    return false;
  }

  void _finishRun() {
    if (_finished) return;
    _finished = true;
    () async {
      await _syncCoordinator.end();
      if (!mounted) return;
      final result = await ref
          .read(activeRunControllerProvider.notifier)
          .finish();
      if (!mounted) return;
      ref.read(activeRunSessionProvider.notifier).clear();
      ref.read(activeRunProgressProvider.notifier).clear();
      context.push(
        RouteNames.logRun,
        extra: LogRunArgs(
          session: _session,
          checkIn: _checkIn,
          runId: result.runId,
          actualDuration: result.elapsed,
          actualDistanceKm: result.distanceKm,
        ),
      );
    }();
  }

  void _togglePause() {
    final controller = ref.read(activeRunControllerProvider.notifier);
    if (ref.read(activeRunControllerProvider).isPaused) {
      controller.resume();
    } else {
      controller.pause();
    }
  }

  void _showModalForIntent(ActiveRunModalIntent intent) {
    switch (intent) {
      case ActiveRunModalIntent.gpsLostAutoPause:
        _showGpsLostAutoPauseDialog();
      case ActiveRunModalIntent.gpsLostWarning:
        _showGpsLostWarningDialog();
      case ActiveRunModalIntent.timerOnlyRestriction:
        _showTimerOnlyRestrictionDialog();
      case ActiveRunModalIntent.endRunConfirm:
        _showEndRunConfirmDialog();
      case ActiveRunModalIntent.finishConfirm:
      case ActiveRunModalIntent.none:
        break;
    }
  }

  void _showGpsLostAutoPauseDialog() {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(activeRunControllerProvider.notifier);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.activeRunGpsLostAutoPauseTitle),
        content: Text(l10n.activeRunGpsLostAutoPauseBody),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              controller.resume();
              controller.dismissModal();
            },
            child: Text(l10n.activeRunWaitForGps),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              controller.dismissModal();
              _finishRun();
            },
            child: Text(l10n.activeRunEndRun),
          ),
        ],
      ),
    );
  }

  void _showGpsLostWarningDialog() {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(activeRunControllerProvider.notifier);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.activeRunGpsLostWarningTitle),
        content: Text(l10n.activeRunGpsLostWarningBody),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              controller.dismissModal();
            },
            child: Text(l10n.activeRunDismiss),
          ),
        ],
      ),
    );
  }

  void _showTimerOnlyRestrictionDialog() {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(activeRunControllerProvider);
    final error = state.error ?? '';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.activeRunTimerOnlyRestrictionTitle),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(activeRunControllerProvider.notifier).dismissModal();
            },
            child: Text(l10n.activeRunDismiss),
          ),
        ],
      ),
    );
  }

  void _showEndRunConfirmDialog() {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(activeRunControllerProvider.notifier);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.activeRunEndRun),
        content: Text(l10n.activeRunGpsLostAutoPauseBody),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              controller.dismissModal();
            },
            child: Text(l10n.activeRunDismiss),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              controller.dismissModal();
              _finishRun();
            },
            child: Text(l10n.activeRunEndRun),
          ),
        ],
      ),
    );
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
      ActiveRunBlockKind.stride => l10n.activeRunStride,
      ActiveRunBlockKind.recovery => l10n.activeRunRecovery,
      ActiveRunBlockKind.coolDown => l10n.sessionDetailCoolDown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    ref.listen(activeRunControllerProvider, (prev, next) {
      if (next.modalIntent != ActiveRunModalIntent.none &&
          prev?.modalIntent != next.modalIntent) {
        _showModalForIntent(next.modalIntent);
      }

      if (_session != null) {
        final unitSystem =
            ref.read(userPreferencesProvider).value?.unitSystem ??
            UnitSystem.km;
        final data = buildRunLiveActivityData(
          state: next,
          session: _session,
          unitSystem: unitSystem,
          l10n: l10n,
        );
        _syncCoordinator.sync(
          data: data,
          timelineIndex: next.timelineIndex,
          gpsStatus: next.gpsStatus,
          isTimerOnlyMode: next.isTimerOnlyMode,
        );
      }
    });

    final runState = ref.watch(activeRunControllerProvider);
    final state = runState;
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;
    final session = _session;
    final type = session?.sessionType ?? SessionType.easyRun;
    final title = _sessionTitle(type, l10n);
    final plannedSummary = _plannedSummary(session, unitSystem, l10n);
    final currentBlock = state.currentBlock;
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
                    GpsStatusHeroPaceCard(
                      gpsStatus: state.gpsStatus,
                      timerOnlyMode: state.isTimerOnlyMode,
                      label: l10n.activeRunCurrentPace,
                      value: state.isTimerOnlyMode
                          ? '--:--'
                          : _formatPace(
                              state.currentPaceSecondsPerKm
                                  .clamp(210, 780)
                                  .toDouble(),
                              unitSystem,
                            ),
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
                            value: _formatDuration(state.elapsed),
                            unit: l10n.activeRunTimeUnit,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _MetricTile(
                            iconAsset: 'assets/icons/distance.svg',
                            label: l10n.activeRunDistance,
                            value: UnitFormatter.formatDistanceValue(
                              state.isTimerOnlyMode ? 0.0 : state.distanceKm,
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
                      isSurging: state.isSurging,
                      onToggleSurge: () {
                        ref
                            .read(activeRunControllerProvider.notifier)
                            .toggleSurge();
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
                      label: state.isPaused
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

  double get _averagePaceSecondsPerKm {
    final state = ref.watch(activeRunControllerProvider);
    if (state.distanceKm <= 0.01) return _plannedPaceSecondsPerKm;
    return state.elapsed.inSeconds / state.distanceKm;
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
      ActiveRunBlockKind.stride => l10n.activeRunStride,
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
    final state = ref.watch(activeRunControllerProvider);
    if (block?.distanceMeters != null) {
      final remainingMeters =
          block!.distanceMeters! - (state.blockDistanceKm * 1000).round();
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
    final state = ref.watch(activeRunControllerProvider);
    final block = state.nextBlock;
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
}

class GpsStatusHeroPaceCard extends StatelessWidget {
  const GpsStatusHeroPaceCard({
    super.key,
    required this.gpsStatus,
    required this.timerOnlyMode,
    required this.label,
    required this.value,
    required this.unit,
    required this.guidance,
    required this.color,
  });

  final GpsStatus gpsStatus;
  final bool timerOnlyMode;
  final String label;
  final String value;
  final String unit;
  final String guidance;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String statusChipText;
    Color statusChipColor;
    if (timerOnlyMode) {
      statusChipText = l10n.activeRunTimerOnlyLabel;
      statusChipColor = AppColors.textSecondary;
    } else {
      switch (gpsStatus) {
        case GpsStatus.acquiring:
          statusChipText = l10n.gpsAcquiringTitle;
          statusChipColor = AppColors.warning;
        case GpsStatus.weak:
          statusChipText = l10n.gpsWeakTitle;
          statusChipColor = AppColors.warning;
        case GpsStatus.lost:
          statusChipText = l10n.gpsLostTitle;
          statusChipColor = AppColors.error;
        case GpsStatus.ready:
          statusChipText = '';
          statusChipColor = AppColors.accentPrimary;
        case GpsStatus.disabled:
          statusChipText = l10n.activeRunTimerOnlyLabel;
          statusChipColor = AppColors.textSecondary;
      }
    }

    String paceValue = value;
    if (timerOnlyMode ||
        gpsStatus == GpsStatus.lost ||
        gpsStatus == GpsStatus.acquiring) {
      paceValue = '--:--';
    }

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
              if (statusChipText.isNotEmpty)
                GpsStatusChip(text: statusChipText, color: statusChipColor),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  paceValue,
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
            timerOnlyMode
                ? l10n.gpsWaitForSignal
                : (gpsStatus == GpsStatus.acquiring ||
                      gpsStatus == GpsStatus.lost)
                ? l10n.gpsWaitForSignal
                : guidance,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class GpsStatusChip extends StatelessWidget {
  const GpsStatusChip({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
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
        ActiveRunBlockKind.stride => 1,
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
      ActiveRunBlockKind.stride => l10n.activeRunStride,
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
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _FocusStat(label: secondaryLabel, value: secondaryValue),
              ),
            ],
          ),
          if (footer.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              footer,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/trending_up.svg',
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
            children: List.generate(phases.length, (index) {
              final isActive = index == activeIndex;
              final isPast = index < activeIndex;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < phases.length - 1 ? AppSpacing.sm : 0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.accentPrimary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(
                      color: isActive
                          ? AppColors.accentPrimary
                          : isPast
                          ? AppColors.accentPrimary.withValues(alpha: 0.3)
                          : AppColors.borderDefault,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        phases[index],
                        style: AppTypography.caption.copyWith(
                          color: isActive
                              ? AppColors.accentPrimary
                              : AppColors.textSecondary,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
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
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/zap.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  isSurging ? AppColors.warning : AppColors.accentPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.activeRunFartlekFocusTitle,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color:
                      (isSurging ? AppColors.warning : AppColors.accentPrimary)
                          .withValues(alpha: 0.15),
                  borderRadius: AppRadius.borderMd,
                ),
                child: Text(
                  isSurging ? l10n.activeRunEndSurge : l10n.activeRunStartSurge,
                  style: AppTypography.caption.copyWith(
                    color: isSurging
                        ? AppColors.warning
                        : AppColors.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.activeRunGuidanceFartlek,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: isSurging
                  ? l10n.activeRunEndSurge
                  : l10n.activeRunStartSurge,
              variant: AppButtonVariant.secondary,
              onPressed: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}
