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
import '../../../../core/widgets/session_row.dart';
import '../../../../core/widgets/stat_column.dart';
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
                  child: SessionRow(
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
              _ViewFullPlanButton(
                label: l10n.weeklyPlanViewFullPlan,
                onTap: () => context.push(RouteNames.fullPlan),
              ),
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
          StatColumn(
            label: l10n.weeklyPlanDistanceLabel,
            value: UnitFormatter.formatDistanceKm(progress.totalVolumeKm),
          ),
          StatColumn(
            label: l10n.weeklyPlanTimeLabel,
            value: UnitFormatter.formatDuration(progress.totalDurationMinutes),
            hasDivider: true,
          ),
          StatColumn(
            label: l10n.weeklyPlanRunsLabel,
            value: progress.totalSessions.toString(),
            hasDivider: true,
          ),
        ],
      ),
    );
  }
}

// ── View Full Plan button ─────────────────────────────────────────────────────

class _ViewFullPlanButton extends StatelessWidget {
  const _ViewFullPlanButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
