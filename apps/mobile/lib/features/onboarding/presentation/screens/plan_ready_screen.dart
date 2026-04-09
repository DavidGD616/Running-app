import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../goals/domain/models/goal.dart';
import '../../../goals/presentation/goal_presenter.dart';
import '../../../goals/presentation/goal_provider.dart';
import '../../../profile/domain/models/runner_profile.dart';
import '../onboarding_provider.dart';
import '../onboarding_values.dart';
import '../../../../l10n/app_localizations.dart';

enum PlanReadyFlowMode { onboarding, editGoal, newGoal }

class PlanReadyScreen extends ConsumerWidget {
  const PlanReadyScreen({super.key, this.mode = PlanReadyFlowMode.onboarding});

  final PlanReadyFlowMode mode;

  // ── Build display values ──────────────────────────────────────────────────

  String _planSubtitle(
    Goal? goal,
    RunnerProfileDraft a,
    AppLocalizations l10n,
  ) {
    final experience = a.fitness.experienceKey ?? '';
    final weeks = goalPlanWeeks(goal);
    final localizedRace = goalRaceLabel(goal, l10n);
    final localizedExp = OnboardingValues.localizeExperience(experience, l10n);
    final planName = l10n.planReadyWeekPlanName(weeks, localizedRace);
    return '$planName • $localizedExp';
  }

  String _goalDescription(Goal? goal, AppLocalizations l10n) =>
      goalDescription(goal, l10n);

  String _scheduleValue(
    Goal? goal,
    RunnerProfileDraft a,
    AppLocalizations l10n,
  ) {
    final days = a.schedule.trainingDaysKey ?? '—';
    final weeks = goalPlanWeeks(goal);
    return l10n.planReadyScheduleValue(weeks, days);
  }

  String _longRunDay(RunnerProfileDraft a, AppLocalizations l10n) {
    final day = a.schedule.longRunDayKey;
    return day != null ? OnboardingValues.localizeDay(day, l10n) : '—';
  }

  String _planPreference(RunnerProfileDraft a, AppLocalizations l10n) {
    final preference = a.trainingPreferences.planPreferenceKey;
    return preference != null
        ? OnboardingValues.localizePlanPreference(preference, l10n)
        : '—';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final answers = ref.watch(onboardingProvider);
    final goal = ref.watch(onboardingGoalProvider);
    final isSettingsFlow = mode != PlanReadyFlowMode.onboarding;
    final primaryLabel = switch (mode) {
      PlanReadyFlowMode.onboarding => l10n.planReadyStartPlan,
      PlanReadyFlowMode.editGoal => l10n.settingsViewPlan,
      PlanReadyFlowMode.newGoal => l10n.settingsViewPlan,
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.xxxl,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Green check icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/circle_check.svg',
                          width: 32,
                          height: 32,
                          colorFilter: const ColorFilter.mode(
                            AppColors.accentPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Title
                    Text(
                      l10n.planReadyTitle,
                      style: AppTypography.headlineLarge,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Subtitle — plan name + level
                    Text(
                      _planSubtitle(goal, answers, l10n),
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Plan details card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: AppRadius.borderLg,
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Column(
                        children: [
                          _PlanDetailRow(
                            iconAsset: 'assets/icons/target.svg',
                            label: l10n.planReadyGoalLabel,
                            value: _goalDescription(goal, l10n),
                          ),
                          const SizedBox(height: AppSpacing.base),
                          _PlanDetailRow(
                            iconAsset: 'assets/icons/calendar.svg',
                            label: l10n.planReadyScheduleLabel,
                            value: _scheduleValue(goal, answers, l10n),
                          ),
                          const SizedBox(height: AppSpacing.base),
                          _PlanDetailRow(
                            iconAsset: 'assets/icons/mountain.svg',
                            label: l10n.planReadyLongRunsLabel,
                            value: _longRunDay(answers, l10n),
                          ),
                          const SizedBox(height: AppSpacing.base),
                          _PlanDetailRow(
                            iconAsset: 'assets/icons/heart_rate.svg',
                            label: l10n.planPreferenceLabel,
                            value: _planPreference(answers, l10n),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Description paragraph
                    Text(
                      l10n.planReadyDescription,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Pinned bottom buttons ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  AppButton(
                    label: primaryLabel,
                    onPressed: () async {
                      final saved = await ref
                          .read(onboardingProvider.notifier)
                          .saveProfile(markOnboardingComplete: !isSettingsFlow);
                      if (!saved || !context.mounted) return;
                      context.go(
                        isSettingsFlow ? RouteNames.plan : RouteNames.today,
                      );
                    },
                  ),
                  if (!isSettingsFlow) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: l10n.planReadyViewFullWeek,
                      variant: AppButtonVariant.secondary,
                      onPressed: () async {
                        final saved = await ref
                            .read(onboardingProvider.notifier)
                            .markCompleted();
                        if (!saved || !context.mounted) return;
                        context.go(RouteNames.plan);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private widget ────────────────────────────────────────────────────────────

class _PlanDetailRow extends StatelessWidget {
  const _PlanDetailRow({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  final String iconAsset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.backgroundCard,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              iconAsset,
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                AppColors.textSecondary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.base),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(value, style: AppTypography.titleMedium),
          ],
        ),
      ],
    );
  }
}
