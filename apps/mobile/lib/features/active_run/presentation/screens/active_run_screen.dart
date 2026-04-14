import 'dart:async';

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
import '../../../pre_run/presentation/run_flow_context.dart';
import '../../../training_plan/domain/models/session_type.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class ActiveRunScreen extends ConsumerStatefulWidget {
  const ActiveRunScreen({super.key, this.args});

  final ActiveRunArgs? args;

  @override
  ConsumerState<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends ConsumerState<ActiveRunScreen> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  double _distanceKm = 0;
  bool _isPaused = false;
  bool _isSurging = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_isPaused) return;
    setState(() {
      _elapsed += const Duration(seconds: 1);
      _distanceKm += _kmPerSecond * _paceMultiplier;
    });
  }

  double get _kmPerSecond {
    final session = widget.args?.session;
    final plannedKm = session?.distanceKm ?? 6.0;
    final plannedSeconds = (session?.durationMinutes ?? 45) * 60;
    if (plannedSeconds <= 0) return 0.0022;
    return plannedKm / plannedSeconds;
  }

  double get _paceMultiplier {
    final type = widget.args?.session?.sessionType ?? SessionType.easyRun;
    final cycle = _elapsed.inSeconds % 12;
    final drift = cycle < 4
        ? 1.04
        : cycle < 8
        ? 0.96
        : 1.0;

    if (type == SessionType.intervals || type == SessionType.hillRepeats) {
      return _isWorkBlock ? 1.22 : 0.72;
    }
    if (type == SessionType.fartlek && _isSurging) return 1.18;
    if (type == SessionType.recoveryRun) return 0.88;
    if (type == SessionType.racePaceRun) return 1.08;
    return drift;
  }

  bool get _isWorkBlock {
    final block = _elapsed.inSeconds ~/ 90;
    return block.isEven;
  }

  int get _currentRep {
    final reps = widget.args?.session?.intervalReps ?? 6;
    final rep = (_elapsed.inSeconds ~/ 180) + 1;
    return rep > reps ? reps : rep;
  }

  Duration get _blockRemaining {
    final blockLength = _isWorkBlock ? 90 : 90;
    final seconds = blockLength - (_elapsed.inSeconds % blockLength);
    return Duration(seconds: seconds);
  }

  double get _averagePaceSecondsPerKm {
    if (_distanceKm <= 0.01) return _plannedPaceSecondsPerKm;
    return _elapsed.inSeconds / _distanceKm;
  }

  double get _currentPaceSecondsPerKm {
    final pace = _plannedPaceSecondsPerKm / _paceMultiplier;
    return pace.clamp(210, 780).toDouble();
  }

  double get _plannedPaceSecondsPerKm {
    final session = widget.args?.session;
    final plannedKm = session?.distanceKm ?? 6.0;
    final plannedSeconds = (session?.durationMinutes ?? 45) * 60;
    if (plannedKm <= 0 || plannedSeconds <= 0) return 450;
    return plannedSeconds / plannedKm;
  }

  void _finishRun() {
    _timer?.cancel();
    context.push(
      RouteNames.logRun,
      extra: LogRunArgs(
        session: widget.args?.session,
        checkIn: widget.args?.checkIn,
        actualDuration: _elapsed,
        actualDistanceKm: _distanceKm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;
    final session = widget.args?.session;
    final type = session?.sessionType ?? SessionType.easyRun;
    final title = _sessionTitle(type, l10n);
    final plannedSummary = _plannedSummary(session, unitSystem, l10n);
    final status = _targetStatus(type, l10n);

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
                        _StatusPill(label: l10n.activeRunDemoTracking),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _HeroPaceCard(
                      label: l10n.activeRunCurrentPace,
                      value: _formatPace(_currentPaceSecondsPerKm, unitSystem),
                      unit: UnitFormatter.paceLabel(unitSystem, l10n),
                      status: status,
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
                            value: _formatDuration(_elapsed),
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
                            value: _targetValue(type, l10n),
                            unit: _targetUnit(type, l10n),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _WorkoutFocusPanel(
                      type: type,
                      currentRep: _currentRep,
                      totalReps: session?.intervalReps ?? 6,
                      blockRemaining: _blockRemaining,
                      isWorkBlock: _isWorkBlock,
                      isSurging: _isSurging,
                      onToggleSurge: () =>
                          setState(() => _isSurging = !_isSurging),
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
                      onPressed: () => setState(() => _isPaused = !_isPaused),
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
    return l10n.activeRunPlannedFallback;
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

  String _targetStatus(SessionType type, AppLocalizations l10n) {
    if (type == SessionType.recoveryRun && _paceMultiplier > 1.0) {
      return l10n.activeRunEaseOff;
    }
    if (type == SessionType.intervals || type == SessionType.hillRepeats) {
      return _isWorkBlock ? l10n.activeRunPush : l10n.activeRunRecover;
    }
    if (type == SessionType.fartlek) {
      return _isSurging ? l10n.activeRunSurge : l10n.activeRunEasyBlock;
    }
    if (_paceMultiplier > 1.12) return l10n.activeRunEaseOff;
    if (_paceMultiplier < 0.9) return l10n.activeRunPickUp;
    return l10n.activeRunOnTarget;
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

class _HeroPaceCard extends StatelessWidget {
  const _HeroPaceCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.guidance,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final String status;
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
              _StatusPill(label: status, color: color),
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
    required this.blockRemaining,
    required this.isWorkBlock,
    required this.isSurging,
    required this.onToggleSurge,
  });

  final SessionType type;
  final int currentRep;
  final int totalReps;
  final Duration blockRemaining;
  final bool isWorkBlock;
  final bool isSurging;
  final VoidCallback onToggleSurge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
        footer: l10n.activeRunBlockRemaining(_formatCountdown(blockRemaining)),
      );
    }

    if (type == SessionType.progressionRun) {
      return _PhaseCard(
        title: l10n.activeRunProgressionFocusTitle,
        activeIndex: _progressionIndex(blockRemaining),
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

  int _progressionIndex(Duration remaining) {
    final cycle = DateTime.now().second % 45;
    if (cycle < 15) return 0;
    if (cycle < 30) return 1;
    return 2;
  }

  String _formatCountdown(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    this.color = AppColors.accentPrimary,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }
}
