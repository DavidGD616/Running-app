import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../session_detail/presentation/screens/session_detail_screen.dart';
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

  String? _sessionDescription(TrainingSession session, AppLocalizations l10n) {
    switch (session.type) {
      case SessionType.rest:
        return null;
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

  String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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
                          nextSession.durationMinutes ?? 0,
                        ),
                        effortLabel: nextSession.effortLabel ?? '',
                        iconAsset: nextSession.type.iconAsset,
                        onTap: () => context.push(
                          RouteNames.sessionDetail,
                          extra: SessionDetailArgs(
                            session: nextSession,
                            showStartWorkout: false,
                          ),
                        ),
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
                      onTap: () => context.go(RouteNames.plan),
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
      return const SizedBox.shrink();
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
      targetGuidance: session.description ?? _sessionDescription(session, l10n),
      sessionTypeIconAsset: session.type.iconAsset,
      onViewDetails: () => context.push(
        RouteNames.sessionDetail,
        extra: SessionDetailArgs(session: session),
      ),
    );
  }
}

// ── Private widgets ─────────────────────────────────────────────────────────────
