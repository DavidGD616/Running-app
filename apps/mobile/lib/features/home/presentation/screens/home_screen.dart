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
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/plan_badge_pill.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/up_next_row_card.dart';
import '../../../../core/widgets/week_progress_card.dart';
import '../../../../core/widgets/workout_hero_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../training_plan/domain/models/session_type.dart';
import '../../../training_plan/domain/models/training_session.dart';
import '../../../training_plan/presentation/training_plan_provider.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _sessionTitle(SessionType type, AppLocalizations l10n) {
    switch (type) {
      case SessionType.rest:        return l10n.weeklyPlanRestTitle;
      case SessionType.easyRun:     return l10n.weeklyPlanSessionEasyRun;
      case SessionType.intervals:   return l10n.weeklyPlanSessionIntervals;
      case SessionType.longRun:     return l10n.weeklyPlanSessionLongRun;
      case SessionType.recoveryRun: return l10n.weeklyPlanSessionRecoveryRun;
      case SessionType.tempoRun:    return l10n.progressSessionTempoRun;
    }
  }

  String? _sessionDescription(SessionType type, AppLocalizations l10n) {
    switch (type) {
      case SessionType.rest:        return null;
      case SessionType.easyRun:     return l10n.sessionDescEasyRun;
      case SessionType.intervals:   return l10n.sessionDescIntervals;
      case SessionType.longRun:     return l10n.sessionDescLongRun;
      case SessionType.recoveryRun: return l10n.sessionDescRecoveryRun;
      case SessionType.tempoRun:    return l10n.sessionDescTempoRun;
    }
  }

  String _weekdayName(int weekday) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[(weekday - 1).clamp(0, 6)];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final plan = ref.watch(trainingPlanProvider);
    final progress = ref.watch(weekProgressProvider);
    final profile = ref.watch(userProfileDisplayProvider);
    final todaySession = plan.todaySession;
    final nextSession = plan.nextUpcomingSession;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SingleChildScrollView(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.md,
                  AppSpacing.screen,
                  0,
                ),
                child: AppHomeHeaderBar(
                  title: l10n.homeTitle,
                  planBadge: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlanBadgePill(planName: profile.planName),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        profile.weekShort,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Body ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Today's Workout ────────────────────────────────
                    SectionLabel(label: l10n.homeSectionTodaysWorkout),
                    const SizedBox(height: AppSpacing.md),
                    _buildTodayCard(context, l10n, todaySession),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Up Next ────────────────────────────────────────
                    SectionLabel(label: l10n.homeSectionUpNext),
                    const SizedBox(height: AppSpacing.md),
                    if (nextSession != null)
                      UpNextRowCard(
                        sessionName: _sessionTitle(nextSession.type, l10n),
                        dayLabel: _weekdayName(nextSession.date.weekday),
                        duration: UnitFormatter.formatDuration(
                            nextSession.durationMinutes ?? 0),
                        effortLabel: nextSession.effortLabel ?? '',
                        iconAsset: nextSession.type.iconAsset,
                        onTap: () {},
                      ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── This Week ──────────────────────────────────────
                    SectionLabel(label: l10n.homeSectionThisWeek),
                    const SizedBox(height: AppSpacing.md),
                    WeekProgressCard(
                      sessionsCompleted: progress.completedSessions,
                      totalSessions: progress.totalSessions,
                      volumeCompleted: progress.completedVolumeKm,
                      totalVolume: progress.totalVolumeKm,
                      volumeUnit: l10n.homeVolumeUnit,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Quick Actions ──────────────────────────────────
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCard(
    BuildContext context,
    AppLocalizations l10n,
    TrainingSession? session,
  ) {
    if (session == null) {
      return WorkoutHeroCard(
        sessionType: l10n.weeklyPlanRestTitle,
        sessionName: l10n.weeklyPlanRestTitle,
        duration: '-',
        distance: '-',
        sessionTypeIconAsset: SessionType.rest.iconAsset,
        onViewDetails: () => context.push(RouteNames.sessionDetail),
        onStart: () {},
      );
    }

    return WorkoutHeroCard(
      sessionType: _sessionTitle(session.type, l10n),
      sessionName: _sessionTitle(session.type, l10n),
      duration: session.durationMinutes != null
          ? UnitFormatter.formatDuration(session.durationMinutes!)
          : '-',
      distance: session.distanceKm != null
          ? UnitFormatter.formatDistanceKm(session.distanceKm!)
          : '-',
      targetGuidance: session.description ?? _sessionDescription(session.type, l10n),
      sessionTypeIconAsset: session.type.iconAsset,
      onViewDetails: () => context.push(RouteNames.sessionDetail),
      onStart: () {},
    );
  }
}

// ── Private widgets ─────────────────────────────────────────────────────────────

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
