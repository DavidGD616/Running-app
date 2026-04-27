import '../../../core/utils/unit_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/models/gps_state.dart';
import '../domain/run_live_activity_data.dart';
import 'active_run_timeline.dart';
import 'active_run_controller.dart';
import '../../pre_run/presentation/run_flow_context.dart';
import '../../training_plan/domain/models/session_type.dart';
import '../../user_preferences/domain/user_preferences.dart';

RunLiveActivityData buildRunLiveActivityData({
  required ActiveRunState state,
  required RunFlowSessionContext? session,
  required UnitSystem unitSystem,
  required AppLocalizations l10n,
}) {
  final isPaused = state.isPaused;
  final elapsedSeconds = state.elapsed.inSeconds;
  final elapsedLabel = _formatDuration(state.elapsed);

  final distanceKm = state.distanceKm;
  final paceSecondsPerKm = state.currentPaceSecondsPerKm;

  final unitFactor = unitSystem == UnitSystem.km ? 1.0 : 0.621371;
  final distanceUnit = unitSystem == UnitSystem.km ? 'km' : 'mi';
  final paceUnit = UnitFormatter.paceLabel(unitSystem, l10n);

  final distanceLabel = UnitFormatter.formatDistanceValue(
    distanceKm,
    unitSystem,
  );
  final currentPaceLabel = _formatPaceWithUnit(
    unitSystem == UnitSystem.km
        ? paceSecondsPerKm
        : (paceSecondsPerKm * 1.609344).round(),
    paceUnit,
  );
  final avgPaceLabel = _formatPaceWithUnit(
    unitSystem == UnitSystem.km
        ? state.averagePaceSecondsPerKm
        : (state.averagePaceSecondsPerKm * 1.609344).round(),
    paceUnit,
  );

  final currentBlockLabel = _currentBlockLabel(
    state.currentBlock,
    session?.sessionType ?? SessionType.easyRun,
    l10n,
  );
  final nextBlockLabel = state.nextBlock != null
      ? _currentBlockLabel(
          state.nextBlock!,
          session?.sessionType ?? SessionType.easyRun,
          l10n,
        )
      : null;
  final repLabel =
      state.currentBlock?.isRepBlock == true &&
          state.currentBlock?.repIndex != null &&
          state.currentBlock?.totalReps != null
      ? '${state.currentBlock!.repIndex} / ${state.currentBlock!.totalReps}'
      : null;

  final blockProgressFraction = _blockProgressFraction(state);

  final blockRemainingLabel = _blockRemainingLabel(state, unitSystem, l10n);

  final plannedDistanceKm = session?.distanceKm;
  final plannedDurationMs = session?.durationMinutes != null
      ? session!.durationMinutes! * 60 * 1000
      : null;

  final plannedPaceLabel = _plannedPaceLabel(session, unitSystem, l10n);

  final timeline = _buildTimeline(session, state.timelineIndex, l10n);

  return RunLiveActivityData(
    workoutName: _workoutName(session?.sessionType, l10n),
    statusTitleLabel: l10n.activeRunStatusTitle,
    statusLabel: _statusLabel(state, l10n),
    elapsedSeconds: elapsedSeconds,
    elapsedLabel: elapsedLabel,
    elapsedUnitLabel: l10n.activeRunTimeUnit,
    distanceTitleLabel: l10n.activeRunDistanceTitle,
    distanceLabel: distanceLabel,
    currentPaceTitleLabel: l10n.activeRunCurrentPace,
    currentPaceShortTitleLabel: l10n.activeRunCurrentPaceShort,
    currentPaceLabel: currentPaceLabel,
    avgPaceTitleLabel: l10n.activeRunAveragePace,
    avgPaceLabel: avgPaceLabel,
    currentBlockLabel: currentBlockLabel,
    nextBlockLabel: nextBlockLabel,
    nextBlockTitleLabel: l10n.activeRunUpNext,
    repLabel: repLabel,
    isPaused: isPaused,
    distanceKm: distanceKm,
    paceSecondsPerKm: paceSecondsPerKm,
    unitFactor: unitFactor,
    distanceUnit: distanceUnit,
    paceUnit: paceUnit,
    plannedDistanceKm: plannedDistanceKm,
    plannedDurationMs: plannedDurationMs,
    timeline: timeline,
    blockProgressFraction: blockProgressFraction,
    plannedPaceLabel: plannedPaceLabel,
    blockRemainingLabel: blockRemainingLabel,
  );
}

String _statusLabel(ActiveRunState state, AppLocalizations l10n) {
  if (state.isPaused) return l10n.activeRunPausedStatusLabel;
  if (state.isTimerOnlyMode || state.gpsStatus == GpsStatus.disabled) {
    return l10n.activeRunTimerOnlyLabel;
  }
  return switch (state.gpsStatus) {
    GpsStatus.acquiring => l10n.gpsWaitForSignal,
    GpsStatus.weak => l10n.gpsWeakSignal,
    GpsStatus.lost => l10n.gpsLostSignal,
    GpsStatus.ready => l10n.activeRunTrackingStatusLabel,
    GpsStatus.disabled => l10n.activeRunTimerOnlyLabel,
  };
}

String _workoutName(SessionType? type, AppLocalizations l10n) {
  if (type == null) return '';
  return switch (type) {
    SessionType.restDay => l10n.sessionTypeRestDay,
    SessionType.easyRun => l10n.weeklyPlanSessionEasyRun,
    SessionType.longRun => l10n.weeklyPlanSessionLongRun,
    SessionType.progressionRun => l10n.sessionTypeProgressionRun,
    SessionType.intervals => l10n.weeklyPlanSessionIntervals,
    SessionType.hillRepeats => l10n.sessionTypeHillRepeats,
    SessionType.fartlek => l10n.sessionTypeFartlek,
    SessionType.tempoRun => l10n.sessionTypeTempoRun,
    SessionType.thresholdRun => l10n.sessionTypeThresholdRun,
    SessionType.racePaceRun => l10n.sessionTypeRacePaceRun,
    SessionType.recoveryRun => l10n.weeklyPlanSessionRecoveryRun,
    SessionType.crossTraining => l10n.sessionTypeCrossTraining,
  };
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '$minutes:$seconds';
}

String _formatPace(int secondsPerKm) {
  if (secondsPerKm <= 0) return '--:--';
  final minutes = secondsPerKm ~/ 60;
  final remainder = (secondsPerKm % 60).toString().padLeft(2, '0');
  return '$minutes:$remainder';
}

String _formatPaceWithUnit(int secondsPerKm, String paceUnit) {
  return '${_formatPace(secondsPerKm)} $paceUnit';
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

double _blockProgressFraction(ActiveRunState state) {
  final block = state.currentBlock;
  if (block == null) return 0.0;

  if (block.isDistanceBased && block.distanceMeters != null) {
    final targetMeters = block.distanceMeters!;
    if (targetMeters <= 0) return 0.0;
    final currentMeters = (state.blockDistanceKm * 1000).round();
    return (currentMeters / targetMeters).clamp(0.0, 1.0);
  }

  if (block.isDurationBased && block.duration != null) {
    final targetDuration = block.duration!;
    if (targetDuration.inSeconds <= 0) return 0.0;
    return (state.blockElapsed.inSeconds / targetDuration.inSeconds).clamp(
      0.0,
      1.0,
    );
  }

  return 0.0;
}

String _blockRemainingLabel(
  ActiveRunState state,
  UnitSystem unitSystem,
  AppLocalizations l10n,
) {
  final block = state.currentBlock;
  if (block == null) return '';

  if (block.isDistanceBased && block.distanceMeters != null) {
    final remainingMeters =
        block.distanceMeters! - (state.blockDistanceKm * 1000).round();
    if (remainingMeters <= 0) return '';
    final value = UnitFormatter.formatWorkoutRepDistance(
      remainingMeters.clamp(0, block.distanceMeters!),
      unitSystem,
      l10n,
    );
    return l10n.activeRunBlockRemaining(value);
  }

  if (block.isDurationBased && block.duration != null) {
    final remaining = block.duration! - state.blockElapsed;
    if (remaining.isNegative) return '';
    return l10n.activeRunBlockRemaining(_formatDuration(remaining));
  }

  return '';
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

String _plannedPaceLabel(
  RunFlowSessionContext? session,
  UnitSystem unitSystem,
  AppLocalizations l10n,
) {
  if (session == null) return '';
  final distanceKm = session.distanceKm;
  final durationMinutes = session.durationMinutes;
  if (distanceKm == null || distanceKm <= 0) return '';
  if (durationMinutes == null) return '';
  final totalSeconds = durationMinutes * 60;
  final paceSecondsPerKm = totalSeconds / distanceKm;
  final displaySeconds = unitSystem == UnitSystem.km
      ? paceSecondsPerKm.round()
      : (paceSecondsPerKm * 1.609344).round();
  final paceStr = _formatPace(displaySeconds);
  final unit = UnitFormatter.paceLabel(unitSystem, l10n);
  return '$paceStr $unit';
}

List<RunLiveActivityTimelineBlock> _buildTimeline(
  RunFlowSessionContext? session,
  int currentIndex,
  AppLocalizations l10n,
) {
  if (session == null) return [];

  final timeline = ActiveRunTimeline.fromSession(session);
  final type = session.sessionType;

  return timeline.blocks.asMap().entries.map((entry) {
    final block = entry.value;
    final blockLabel = _currentBlockLabel(block, type, l10n);
    final nextBlock = entry.key + 1 < timeline.blocks.length
        ? timeline.blocks[entry.key + 1]
        : null;
    final nextLabel = nextBlock != null
        ? _currentBlockLabel(nextBlock, type, l10n)
        : null;
    final repLabel = block.isRepBlock ? l10n.activeRunRep : null;

    return RunLiveActivityTimelineBlock(
      durationMs: block.duration?.inMilliseconds,
      distanceMeters: block.distanceMeters,
      blockLabel: blockLabel,
      nextLabel: nextLabel,
      repLabel: repLabel,
    );
  }).toList();
}
