import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../session_detail/presentation/screens/session_detail_screen.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';
import '../../../training_plan/domain/models/week_progress.dart';
import '../../../training_plan/presentation/training_plan_provider.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class WeeklyPlanScreen extends ConsumerWidget {
  const WeeklyPlanScreen({super.key});

  String _sessionTitle(SessionType type, AppLocalizations l10n) {
    switch (type) {
      // Rest
      case SessionType.restDay:
        return l10n.sessionTypeRestDay;
      // Endurance
      case SessionType.easyRun:
        return l10n.weeklyPlanSessionEasyRun;
      case SessionType.longRun:
        return l10n.weeklyPlanSessionLongRun;
      case SessionType.progressionRun:
        return l10n.sessionTypeProgressionRun;
      // Speed Work
      case SessionType.intervals:
        return l10n.weeklyPlanSessionIntervals;
      case SessionType.hillRepeats:
        return l10n.sessionTypeHillRepeats;
      case SessionType.fartlek:
        return l10n.sessionTypeFartlek;
      // Threshold
      case SessionType.tempoRun:
        return l10n.sessionTypeTempoRun;
      case SessionType.thresholdRun:
        return l10n.sessionTypeThresholdRun;
      // Race Specific
      case SessionType.racePaceRun:
        return l10n.sessionTypeRacePaceRun;
      // Recovery
      case SessionType.recoveryRun:
        return l10n.weeklyPlanSessionRecoveryRun;
      case SessionType.crossTraining:
        return l10n.sessionTypeCrossTraining;
    }
  }

  bool _isTodayDate(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Short weekday label for the date badge, e.g. 'MON', 'TUE'.
  /// Uses 'TODAY' when the session date matches today, regardless of status.
  String _dayLabel(TrainingSession s, AppLocalizations l10n) {
    if (_isTodayDate(s.date)) return l10n.weeklyPlanDayToday;
    switch (s.date.weekday) {
      case 1:
        return l10n.weeklyPlanDayMon;
      case 2:
        return l10n.weeklyPlanDayTue;
      case 3:
        return l10n.weeklyPlanDayWed;
      case 4:
        return l10n.weeklyPlanDayThu;
      case 5:
        return l10n.weeklyPlanDayFri;
      case 6:
        return l10n.weeklyPlanDaySat;
      default:
        return l10n.weeklyPlanDaySun;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final plan = ref.watch(trainingPlanProvider);
    final progress = ref.watch(weekProgressProvider);
    final sessions = plan.currentWeekSessions;
    final weekStart = sessions.isNotEmpty
        ? sessions.first.date.day.toString()
        : '';

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
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
              // ── Title ─────────────────────────────────────────────
              Text(
                l10n.weeklyPlanTitle(
                  plan.currentWeekNumber.toString(),
                  weekStart,
                ),
                style: AppTypography.titleLarge,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Week stats card
              _WeekStatsSummary(l10n: l10n, progress: progress),

              const SizedBox(height: AppSpacing.xl),

              // Schedule section label
              SectionLabel(label: l10n.weeklyPlanScheduleLabel),

              const SizedBox(height: AppSpacing.md),

              // Session rows
              ...sessions.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _SessionRow(
                    dayLabel: _dayLabel(s, l10n),
                    dateNumber: s.date.day.toString(),
                    sessionDate: s.date,
                    title: _sessionTitle(s.type, l10n),
                    subtitle: s.type.isRest
                        ? l10n.weeklyPlanRestSubtitle
                        : null,
                    distance: s.distanceKm != null
                        ? UnitFormatter.formatDistanceKm(s.distanceKm!)
                        : null,
                    duration: s.durationMinutes != null
                        ? UnitFormatter.formatDuration(s.durationMinutes!)
                        : null,
                    status: s.status,
                    isRest: s.type.isRest,
                    trailingIcon: s.type.iconAsset,
                    nowLabel: l10n.weeklyPlanNowBadge,
                    onTap: s.type.isRest
                        ? null
                        : () => context.push(
                            RouteNames.sessionDetail,
                            extra: SessionDetailArgs(session: s),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // View Full Plan button
              _ViewFullPlanButton(label: l10n.weeklyPlanViewFullPlan),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Week stats summary card ───────────────────────────────────────────────────

class _WeekStatsSummary extends StatelessWidget {
  const _WeekStatsSummary({required this.l10n, required this.progress});

  final AppLocalizations l10n;
  final WeekProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.backgroundCard),
      ),
      child: Row(
        children: [
          _StatColumn(
            label: l10n.weeklyPlanDistanceLabel,
            value: UnitFormatter.formatDistanceKm(progress.totalVolumeKm),
          ),
          _StatColumn(
            label: l10n.weeklyPlanTimeLabel,
            value: UnitFormatter.formatDuration(progress.totalDurationMinutes),
            hasDivider: true,
          ),
          _StatColumn(
            label: l10n.weeklyPlanRunsLabel,
            value: progress.totalSessions.toString(),
            hasDivider: true,
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    this.hasDivider = false,
  });

  final String label;
  final String value;
  final bool hasDivider;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.textDisabled,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return Expanded(
      child: hasDivider
          ? DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.backgroundCard),
                ),
              ),
              child: content,
            )
          : content,
    );
  }
}

// ── Session row ───────────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.dayLabel,
    required this.dateNumber,
    required this.sessionDate,
    required this.title,
    this.subtitle,
    this.distance,
    this.duration,
    required this.status,
    required this.isRest,
    required this.trailingIcon,
    required this.nowLabel,
    this.onTap,
  });

  final String dayLabel;
  final String dateNumber;
  final DateTime sessionDate;
  final String title;
  final String? subtitle;
  final String? distance;
  final String? duration;
  final SessionStatus status;
  final bool isRest;
  final String trailingIcon;
  final String nowLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bool isToday =
        sessionDate.year == now.year &&
        sessionDate.month == now.month &&
        sessionDate.day == now.day;
    final bool isSkipped = status == SessionStatus.skipped;
    final Color rowBg;
    final Color rowBorder;
    final Color dateBg;
    final Color dayTextColor;
    final Color dateTextColor;
    final Color titleColor;

    if (isToday) {
      rowBg = AppColors.accentPrimary.withValues(alpha: 0.06);
      rowBorder = AppColors.accentPrimary;
      dateBg = const Color(0xFF252525);
      dayTextColor = AppColors.accentPrimary;
      dateTextColor = AppColors.accentPrimary;
      titleColor = AppColors.accentPrimary;
    } else if (isRest) {
      rowBg = Colors.transparent;
      rowBorder = const Color(0xFF222222);
      dateBg = const Color(0xFF1C1C1C);
      dayTextColor = const Color(0xFF444444);
      dateTextColor = AppColors.textDisabled;
      titleColor = const Color(0xFF555555);
    } else if (status == SessionStatus.completed) {
      rowBg = AppColors.backgroundSecondary;
      rowBorder = AppColors.backgroundCard;
      dateBg = const Color(0xFF1C1C1C);
      dayTextColor = AppColors.textDisabled;
      dateTextColor = AppColors.textDisabled;
      titleColor = const Color(0xFF888888);
    } else if (isSkipped) {
      rowBg = Colors.transparent;
      rowBorder = const Color(0xFF222222);
      dateBg = const Color(0xFF1C1C1C);
      dayTextColor = AppColors.textDisabled;
      dateTextColor = AppColors.textDisabled;
      titleColor = AppColors.textDisabled;
    } else {
      // upcoming
      rowBg = AppColors.backgroundSecondary;
      rowBorder = AppColors.backgroundCard;
      dateBg = const Color(0xFF252525);
      dayTextColor = AppColors.textDisabled;
      dateTextColor = AppColors.textPrimary;
      titleColor = AppColors.textPrimary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        decoration: BoxDecoration(
          color: rowBg,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: rowBorder),
        ),
        child: Row(
          children: [
            // ── Date badge ──────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: dateBg,
                borderRadius: AppRadius.borderMd,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayLabel.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: dayTextColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    dateNumber,
                    style: AppTypography.titleMedium.copyWith(
                      color: dateTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // ── Content ─────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.titleMedium.copyWith(
                            color: titleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: isSkipped
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: isSkipped
                                ? AppColors.textDisabled
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.only(right: 8),
                          child: _NowBadge(label: nowLabel),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFF444444),
                      ),
                    )
                  else if (distance != null || duration != null)
                    Row(
                      children: [
                        if (distance != null) ...[
                          SvgPicture.asset(
                            'assets/icons/route.svg',
                            width: 12,
                            height: 12,
                            colorFilter: const ColorFilter.mode(
                              AppColors.textDisabled,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distance!,
                            style: AppTypography.caption.copyWith(
                              color: isSkipped
                                  ? const Color(0xFF555555)
                                  : AppColors.textDisabled,
                              fontSize: 12,
                              letterSpacing: 0.1,
                              decoration: isSkipped
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: isSkipped
                                  ? const Color(0xFF555555)
                                  : null,
                            ),
                          ),
                        ],
                        if (distance != null && duration != null)
                          const SizedBox(width: 10),
                        if (duration != null) ...[
                          SvgPicture.asset(
                            'assets/icons/clock.svg',
                            width: 12,
                            height: 12,
                            colorFilter: const ColorFilter.mode(
                              AppColors.textDisabled,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            duration!,
                            style: AppTypography.caption.copyWith(
                              color: isSkipped
                                  ? const Color(0xFF555555)
                                  : AppColors.textDisabled,
                              fontSize: 12,
                              letterSpacing: 0.1,
                              decoration: isSkipped
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: isSkipped
                                  ? const Color(0xFF555555)
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),

            // ── Trailing icon ────────────────────────────────────
            _TrailingIcon(
              iconAsset: trailingIcon,
              status: status,
              isRest: isRest,
            ),
          ],
        ),
      ),
    );
  }
}

// ── "Now" badge ───────────────────────────────────────────────────────────────

class _NowBadge extends StatelessWidget {
  const _NowBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.accentPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ── Trailing icon container ───────────────────────────────────────────────────

class _TrailingIcon extends StatelessWidget {
  const _TrailingIcon({
    required this.iconAsset,
    required this.status,
    required this.isRest,
  });

  final String iconAsset;
  final SessionStatus status;
  final bool isRest;

  @override
  Widget build(BuildContext context) {
    if (status == SessionStatus.completed) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.accentPrimary.withValues(alpha: 0.1),
          borderRadius: AppRadius.borderMd,
        ),
        child: const Icon(
          Icons.check,
          color: AppColors.accentPrimary,
          size: 18,
        ),
      );
    }

    if (status == SessionStatus.skipped) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: AppRadius.borderMd,
        ),
        child: const Icon(Icons.close, color: AppColors.textDisabled, size: 18),
      );
    }

    final bool isToday = status == SessionStatus.today;
    final Color boxBg;
    final Color iconColor;
    final double opacity;
    final Border? border;

    if (isToday) {
      boxBg = AppColors.accentPrimary.withValues(alpha: 0.15);
      iconColor = AppColors.accentPrimary;
      opacity = 1.0;
      border = Border.all(
        color: AppColors.accentPrimary.withValues(alpha: 0.25),
      );
    } else if (isRest) {
      boxBg = Colors.transparent;
      iconColor = AppColors.textDisabled;
      opacity = 0.4;
      border = null;
    } else {
      boxBg = const Color(0xFF222222);
      iconColor = AppColors.textDisabled;
      opacity = 1.0;
      border = null;
    }

    return Opacity(
      opacity: opacity,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: boxBg,
          borderRadius: AppRadius.borderMd,
          border: border,
        ),
        child: Center(
          child: SvgPicture.asset(
            iconAsset,
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

// ── View Full Plan button ─────────────────────────────────────────────────────

class _ViewFullPlanButton extends StatelessWidget {
  const _ViewFullPlanButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: AppColors.accentPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/calendar.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.accentPrimary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.accentPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
