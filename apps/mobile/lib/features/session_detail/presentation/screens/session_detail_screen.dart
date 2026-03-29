import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/skip_workout_bottom_sheet.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';

// ── Navigation args ───────────────────────────────────────────────────────────

class SessionDetailArgs {
  const SessionDetailArgs({
    required this.session,
    this.status,
    this.showStartWorkout = true,
  });

  final TrainingSession session;
  final SessionStatus? status;
  final bool showStartWorkout;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({
    super.key,
    required this.session,
    this.status,
    this.showStartWorkout = true,
  });

  final TrainingSession session;
  final SessionStatus? status;
  final bool showStartWorkout;

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _sessionTitle(SessionType type, AppLocalizations l10n) {
    switch (type) {
      case SessionType.rest:
        return l10n.weeklyPlanRestTitle;
      case SessionType.easyRun:
        return l10n.weeklyPlanSessionEasyRun;
      case SessionType.intervals:
        return l10n.weeklyPlanSessionIntervals;
      case SessionType.longRun:
        return l10n.weeklyPlanSessionLongRun;
      case SessionType.recoveryRun:
        return l10n.weeklyPlanSessionRecoveryRun;
      case SessionType.tempoRun:
        return l10n.progressSessionTempoRun;
    }
  }

  String _sessionDescription(SessionType type, AppLocalizations l10n) {
    switch (type) {
      case SessionType.rest:
        return '';
      case SessionType.easyRun:
        return l10n.sessionDescEasyRun;
      case SessionType.intervals:
        return l10n.sessionDescIntervals(
          session.intervalReps ?? 0,
          session.intervalRepDistance ?? '—',
          session.intervalRecoverySeconds ?? 0,
        );
      case SessionType.longRun:
        return l10n.sessionDescLongRun;
      case SessionType.recoveryRun:
        return l10n.sessionDescRecoveryRun;
      case SessionType.tempoRun:
        return l10n.sessionDescTempoRun;
    }
  }

  bool get _isHardSession =>
      session.type == SessionType.intervals ||
      session.type == SessionType.tempoRun;

  bool get _canStartWorkout {
    if (!showStartWorkout) return false;
    if (status != SessionStatus.today) return false;
    return true;
  }

  List<_PhaseData> _phasesFor(AppLocalizations l10n) {
    final mainTitle = _sessionTitle(session.type, l10n);
    final warm = l10n.sessionDetailWarmUp;
    final cool = l10n.sessionDetailCoolDown;
    switch (session.type) {
      case SessionType.easyRun:
        return [
          _PhaseData(
            _PT.warmUp,
            'assets/icons/flame.svg',
            warm,
            l10n.sessionPhaseEasyRunWarmDuration(session.warmUpMinutes ?? 0),
            l10n.sessionPhaseEasyRunWarmNote,
          ),
          _PhaseData(
            _PT.main,
            'assets/icons/route.svg',
            mainTitle,
            l10n.sessionPhaseEasyRunMainDuration(session.durationMinutes ?? 0),
            l10n.sessionPhaseEasyRunMainNote,
          ),
          _PhaseData(
            _PT.cool,
            'assets/icons/heart_rate.svg',
            cool,
            l10n.sessionPhaseEasyRunCoolDuration(session.coolDownMinutes ?? 0),
            l10n.sessionPhaseEasyRunCoolNote,
          ),
        ];
      case SessionType.intervals:
        return [
          _PhaseData(
            _PT.warmUp,
            'assets/icons/flame.svg',
            warm,
            l10n.sessionPhaseIntervalsWarmDuration(session.warmUpMinutes ?? 0),
            l10n.sessionPhaseIntervalsWarmNote,
          ),
          _PhaseData(
            _PT.main,
            'assets/icons/activity.svg',
            mainTitle,
            l10n.sessionPhaseIntervalsMainDuration(
              session.durationMinutes ?? 0,
            ),
            l10n.sessionPhaseIntervalsMainNote(
              session.intervalReps ?? 0,
              session.intervalRepDistance ?? '—',
            ),
            recoveryNote: l10n.sessionPhaseIntervalsMainRecovery(
              session.intervalRecoverySeconds ?? 0,
            ),
          ),
          _PhaseData(
            _PT.cool,
            'assets/icons/heart_rate.svg',
            cool,
            l10n.sessionPhaseIntervalsCoolDuration(
              session.coolDownMinutes ?? 0,
            ),
            l10n.sessionPhaseIntervalsCoolNote,
          ),
        ];
      case SessionType.longRun:
        return [
          _PhaseData(
            _PT.warmUp,
            'assets/icons/flame.svg',
            warm,
            l10n.sessionPhaseLongRunWarmDuration(session.warmUpMinutes ?? 0),
            l10n.sessionPhaseLongRunWarmNote,
          ),
          _PhaseData(
            _PT.main,
            'assets/icons/target.svg',
            mainTitle,
            l10n.sessionPhaseLongRunMainDuration(session.durationMinutes ?? 0),
            l10n.sessionPhaseLongRunMainNote,
          ),
          _PhaseData(
            _PT.cool,
            'assets/icons/heart_rate.svg',
            cool,
            l10n.sessionPhaseLongRunCoolDuration(session.coolDownMinutes ?? 0),
            l10n.sessionPhaseLongRunCoolNote,
          ),
        ];
      case SessionType.recoveryRun:
        return [
          _PhaseData(
            _PT.warmUp,
            'assets/icons/flame.svg',
            warm,
            l10n.sessionPhaseRecoveryRunWarmDuration(
              session.warmUpMinutes ?? 0,
            ),
            l10n.sessionPhaseRecoveryRunWarmNote,
          ),
          _PhaseData(
            _PT.main,
            'assets/icons/stopwatch.svg',
            mainTitle,
            l10n.sessionPhaseRecoveryRunMainDuration(
              session.durationMinutes ?? 0,
            ),
            l10n.sessionPhaseRecoveryRunMainNote,
          ),
          _PhaseData(
            _PT.cool,
            'assets/icons/heart_rate.svg',
            cool,
            l10n.sessionPhaseRecoveryRunCoolDuration(
              session.coolDownMinutes ?? 0,
            ),
            l10n.sessionPhaseRecoveryRunCoolNote,
          ),
        ];
      case SessionType.tempoRun:
        return [
          _PhaseData(
            _PT.warmUp,
            'assets/icons/flame.svg',
            warm,
            l10n.sessionPhaseTempoRunWarmDuration(session.warmUpMinutes ?? 0),
            l10n.sessionPhaseTempoRunWarmNote,
          ),
          _PhaseData(
            _PT.main,
            'assets/icons/activity.svg',
            mainTitle,
            l10n.sessionPhaseTempoRunMainDuration(session.durationMinutes ?? 0),
            l10n.sessionPhaseTempoRunMainNote,
          ),
          _PhaseData(
            _PT.cool,
            'assets/icons/heart_rate.svg',
            cool,
            l10n.sessionPhaseTempoRunCoolDuration(session.coolDownMinutes ?? 0),
            l10n.sessionPhaseTempoRunCoolNote,
          ),
        ];
      case SessionType.rest:
        return [];
    }
  }

  Color _phaseIconColor(_PT type) {
    switch (type) {
      case _PT.warmUp:
        return AppColors.warning;
      case _PT.main:
        return _isHardSession ? AppColors.error : AppColors.accentPrimary;
      case _PT.cool:
        return AppColors.info;
    }
  }

  Color? _phaseCardBorder(_PT type) {
    if (type == _PT.main && _isHardSession) {
      return AppColors.error.withValues(alpha: 0.5);
    }
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _sessionTitle(session.type, l10n);
    final description = session.description?.isNotEmpty == true
        ? session.description!
        : _sessionDescription(session.type, l10n);
    final phases = _phasesFor(l10n);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.sessionDetailTitle,
        onBack: () => context.pop(),
        onMore: () => showSkipWorkoutBottomSheet(
          context: context,
          sessionName: title,
          onSkip: () {},
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Session type badge ─────────────────────────
                  _TypeBadge(label: title.toUpperCase(), status: status),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Session name ───────────────────────────────
                  Text(title, style: AppTypography.headlineLarge),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Description ────────────────────────────────
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Stat tiles ─────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          iconAsset: 'assets/icons/route.svg',
                          label: l10n.sessionDetailTotalDistanceLabel,
                          value: session.distanceKm != null
                              ? UnitFormatter.formatDistanceKm(
                                  session.distanceKm!,
                                )
                              : '—',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _StatTile(
                          iconAsset: 'assets/icons/stopwatch.svg',
                          label: l10n.sessionDetailEstDurationLabel,
                          value: session.durationMinutes != null
                              ? UnitFormatter.formatDuration(
                                  session.durationMinutes!,
                                )
                              : '—',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Workout Structure ──────────────────────────
                  if (phases.isNotEmpty) ...[
                    Text(
                      l10n.sessionDetailWorkoutStructure,
                      style: AppTypography.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...phases.asMap().entries.map((entry) {
                      final index = entry.key;
                      final phase = entry.value;
                      final isLast = index == phases.length - 1;
                      final iconColor = _phaseIconColor(phase.type);
                      return _PhaseItem(
                        iconAsset: phase.iconAsset,
                        iconBgColor: iconColor.withValues(alpha: 0.08),
                        iconColor: iconColor,
                        title: phase.title,
                        duration: phase.duration,
                        note: phase.note,
                        recoveryNote: phase.recoveryNote,
                        cardBorderColor: _phaseCardBorder(phase.type),
                        isLast: isLast,
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),

          // ── Start Workout button ───────────────────────────────
          if (_canStartWorkout)
            _StartButton(
              label: l10n.sessionDetailStartWorkout,
              onTap: () => context.push(RouteNames.preRun),
            ),
        ],
      ),
    );
  }
}

// ── Private types ─────────────────────────────────────────────────────────────

enum _PT { warmUp, main, cool }

class _PhaseData {
  const _PhaseData(
    this.type,
    this.iconAsset,
    this.title,
    this.duration,
    this.note, {
    this.recoveryNote,
  });

  final _PT type;
  final String iconAsset;
  final String title;
  final String duration;
  final String note;
  final String? recoveryNote;
}

// ── Session type badge ────────────────────────────────────────────────────────

class _TypeBadge extends StatefulWidget {
  const _TypeBadge({required this.label, this.status});

  final String label;
  final SessionStatus? status;

  @override
  State<_TypeBadge> createState() => _TypeBadgeState();
}

class _TypeBadgeState extends State<_TypeBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.status == SessionStatus.today) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_TypeBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == SessionStatus.today) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    switch (widget.status) {
      case SessionStatus.today:
        return AppColors.accentPrimary.withValues(alpha: 0.1);
      case SessionStatus.upcoming:
        return AppColors.accentPrimary.withValues(alpha: 0.1);
      case SessionStatus.completed:
        return AppColors.success.withValues(alpha: 0.1);
      case SessionStatus.skipped:
        return AppColors.textDisabled.withValues(alpha: 0.1);
      case null:
        return AppColors.accentPrimary.withValues(alpha: 0.1);
    }
  }

  Color get _textColor {
    switch (widget.status) {
      case SessionStatus.today:
        return AppColors.accentPrimary;
      case SessionStatus.upcoming:
        return AppColors.accentPrimary;
      case SessionStatus.completed:
        return AppColors.success;
      case SessionStatus.skipped:
        return AppColors.textDisabled;
      case null:
        return AppColors.accentPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.status == SessionStatus.today) ...[
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _textColor.withValues(alpha: _animation.value),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
          ],
          Text(
            widget.label,
            style: AppTypography.labelMedium.copyWith(
              color: _textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  final String iconAsset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              AppColors.textSecondary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textDisabled,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.headlineMedium),
        ],
      ),
    );
  }
}

// ── Timeline phase item ───────────────────────────────────────────────────────

class _PhaseItem extends StatelessWidget {
  const _PhaseItem({
    required this.iconAsset,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.duration,
    required this.note,
    this.recoveryNote,
    this.cardBorderColor,
    this.isLast = false,
  });

  final String iconAsset;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String duration;
  final String note;
  final String? recoveryNote;
  final Color? cardBorderColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      iconAsset,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: AppColors.surfaceElevated,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.base),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: AppRadius.borderLg,
                  border: Border.all(
                    color: cardBorderColor ?? AppColors.borderDefault,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      duration,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textDisabled,
                      ),
                    ),
                    if (recoveryNote != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(height: 1, color: AppColors.surfaceElevated),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        recoveryNote!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textDisabled,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Start Workout button ──────────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundPrimary.withValues(alpha: 0),
            AppColors.backgroundPrimary,
          ],
          stops: const [0.0, 0.5],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary,
            borderRadius: AppRadius.borderLg,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/play.svg',
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppColors.backgroundPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.backgroundPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
