import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/plan_badge_pill.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/up_next_row_card.dart';
import '../../../../core/widgets/week_progress_card.dart';
import '../../../../core/widgets/workout_hero_card.dart';
import '../../../../l10n/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppHomeHeaderBar(
        title: l10n.homeTitle,
        planBadge: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlanBadgePill(planName: l10n.homePlanName),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.homeWeekInfo,
              style: AppTypography.caption.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
        onProfileTap: () {},
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.lg,
          AppSpacing.screen,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Today's Workout ───────────────────────────────
            SectionLabel(label: l10n.homeSectionTodaysWorkout),
            const SizedBox(height: AppSpacing.md),
            WorkoutHeroCard(
              sessionType: l10n.homeWorkoutSessionType,
              sessionName: l10n.homeWorkoutSessionName,
              duration: l10n.homeWorkoutDuration,
              distance: l10n.homeWorkoutDistance,
              targetGuidance: l10n.homeWorkoutTargetGuidance,
              sessionTypeIconAsset: 'assets/icons/zap.svg',
              onViewDetails: () {},
              onStart: () {},
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Up Next ───────────────────────────────────────
            SectionLabel(label: l10n.homeSectionUpNext),
            const SizedBox(height: AppSpacing.md),
            UpNextRowCard(
              sessionName: l10n.homeUpNextSessionName,
              dayLabel: l10n.homeUpNextDayLabel,
              duration: l10n.homeUpNextDuration,
              effortLabel: l10n.homeUpNextEffortLabel,
              iconAsset: 'assets/icons/calendar.svg',
              onTap: () {},
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── This Week ─────────────────────────────────────
            SectionLabel(label: l10n.homeSectionThisWeek),
            const SizedBox(height: AppSpacing.md),
            WeekProgressCard(
              sessionsCompleted: 2,
              totalSessions: 4,
              volumeCompleted: 12.5,
              totalVolume: 25.0,
              volumeUnit: l10n.homeVolumeUnit,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Quick Actions ─────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    label: l10n.homeLogPastRun,
                    iconAsset: 'assets/icons/circle_check.svg',
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _QuickActionButton(
                    label: l10n.homeFullWeek,
                    iconAsset: 'assets/icons/calendar.svg',
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private widgets ────────────────────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.iconAsset,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                AppColors.textSecondary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
