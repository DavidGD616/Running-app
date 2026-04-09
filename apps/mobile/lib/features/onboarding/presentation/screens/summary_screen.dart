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
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../goals/domain/models/goal.dart';
import '../../../goals/presentation/goal_presenter.dart';
import '../../../goals/presentation/goal_provider.dart';
import '../../../profile/domain/models/runner_profile.dart';
import '../onboarding_provider.dart';
import '../onboarding_values.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  // ── Helper: format DateTime as "Month DD, YYYY" ──────────────────────────
  String _formatDate(DateTime d, AppLocalizations l10n) {
    final months = [
      l10n.monthJanuary,
      l10n.monthFebruary,
      l10n.monthMarch,
      l10n.monthApril,
      l10n.monthMay,
      l10n.monthJune,
      l10n.monthJuly,
      l10n.monthAugust,
      l10n.monthSeptember,
      l10n.monthOctober,
      l10n.monthNovember,
      l10n.monthDecember,
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  // ── Build display values from provider data ───────────────────────────────

  String _goalValue(Goal? goal, AppLocalizations l10n) =>
      goalRaceLabel(goal, l10n);

  String _goalDetail(Goal? goal, BuildContext context, AppLocalizations l10n) {
    final eventDate = goal?.raceEvent?.eventDate;
    final localizedPriority = goalPriorityLabel(goal, l10n);
    if (eventDate != null) {
      return '${_formatDate(eventDate, l10n)} · $localizedPriority';
    }
    return localizedPriority;
  }

  String _fitnessValue(RunnerProfileDraft a, AppLocalizations l10n) {
    final exp = a.fitness.experienceKey;
    if (exp == null) return '—';
    return OnboardingValues.localizeExperience(exp, l10n);
  }

  String _fitnessDetail(
    RunnerProfileDraft a,
    UnitSystem unitSystem,
    AppLocalizations l10n,
  ) {
    final experience = a.fitness.experienceKey;
    if (experience == OnboardingValues.experienceBrandNew) {
      final can = a.fitness.canRun10Min;
      if (can == null) return '—';
      return l10n.summaryCanRun10Min(can ? l10n.yes : l10n.no);
    }
    final days = a.fitness.runningDaysKey ?? '—';
    final weeklyVolume = a.fitness.weeklyVolumeKey;
    final volume = weeklyVolume != null
        ? OnboardingValues.localizeWeeklyVolume(weeklyVolume, unitSystem, l10n)
        : '—';
    return l10n.summaryFitnessDetail(days, volume);
  }

  String _scheduleValue(RunnerProfileDraft a, AppLocalizations l10n) {
    final days = a.schedule.trainingDaysKey;
    return days != null ? l10n.summaryDaysPerWeek(days) : '—';
  }

  String _scheduleDetail(RunnerProfileDraft a, AppLocalizations l10n) {
    final longRun = a.schedule.longRunDayKey;
    final weekday = a.schedule.weekdayTimeKey;
    return l10n.summaryScheduleDetail(
      longRun != null ? OnboardingValues.localizeDay(longRun, l10n) : '—',
      weekday != null ? OnboardingValues.localizeTimeSlot(weekday, l10n) : '—',
    );
  }

  String _healthValue(RunnerProfileDraft a, AppLocalizations l10n) {
    final pain = a.health.painLevelKey;
    if (pain == null) return '—';
    return pain == OnboardingValues.painNo
        ? l10n.summaryNoPain
        : l10n.summaryWithPain(OnboardingValues.localizePainLevel(pain, l10n));
  }

  String _healthDetail(RunnerProfileDraft a, AppLocalizations l10n) {
    final injury = a.health.injuryHistoryKey;
    final conditions = a.health.healthConditionsKey;
    return l10n.summaryHealthDetail(
      injury != null
          ? OnboardingValues.localizeInjuryHistory(injury, l10n)
          : '—',
      conditions != null
          ? OnboardingValues.localizeBinary(conditions, l10n)
          : '—',
    );
  }

  String _trainingValue(RunnerProfileDraft a, AppLocalizations l10n) {
    final preference = a.trainingPreferences.planPreferenceKey;
    return preference != null
        ? OnboardingValues.localizePlanPreference(preference, l10n)
        : '—';
  }

  String _trainingDetail(RunnerProfileDraft a, AppLocalizations l10n) {
    final preference = a.trainingPreferences.planPreferenceKey;
    if (preference == null) return '—';
    return OnboardingValues.localizePlanPreferenceSubtitle(preference, l10n);
  }

  String _deviceValue(RunnerProfileDraft a, AppLocalizations l10n) {
    final hasWatch = a.device.hasWatchKey;
    if (hasWatch == OnboardingValues.yes) {
      final device = a.device.deviceKey ?? OnboardingValues.deviceOther;
      return OnboardingValues.localizeDevice(device, l10n);
    }
    if (hasWatch == OnboardingValues.no) return l10n.summaryNoWatch;
    return '—';
  }

  String _deviceDetail(RunnerProfileDraft a, AppLocalizations l10n) => '—';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final answers = ref.watch(onboardingProvider);
    final goal = ref.watch(onboardingGoalProvider);
    final unitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top nav ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.screen,
                0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/chevron_left.svg',
                              width: 24,
                              height: 24,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textPrimary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        l10n.onboardingStep(7, 7),
                        style: AppTypography.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: AppProgressBar(current: 7, total: 7),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────────────────────
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
                    Text(
                      l10n.summaryTitle,
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.summarySubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Summary cards ─────────────────────────────────────────
                    _SummaryCard(
                      icon: 'assets/icons/target.svg',
                      category: l10n.summaryGoalRace,
                      value: _goalValue(goal, l10n),
                      detail: _goalDetail(goal, context, l10n),
                      onEdit: () => context.go(RouteNames.goal),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/trending_up.svg',
                      category: l10n.summaryCurrentLevel,
                      value: _fitnessValue(answers, l10n),
                      detail: _fitnessDetail(answers, unitSystem, l10n),
                      onEdit: () => context.go(RouteNames.fitness),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/calendar.svg',
                      category: l10n.summarySchedule,
                      value: _scheduleValue(answers, l10n),
                      detail: _scheduleDetail(answers, l10n),
                      onEdit: () => context.go(RouteNames.schedule),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/heart.svg',
                      category: l10n.summaryHealth,
                      value: _healthValue(answers, l10n),
                      detail: _healthDetail(answers, l10n),
                      onEdit: () => context.go(RouteNames.health),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/training.svg',
                      category: l10n.summaryTraining,
                      value: _trainingValue(answers, l10n),
                      detail: _trainingDetail(answers, l10n),
                      onEdit: () => context.go(RouteNames.training),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/watch.svg',
                      category: l10n.summaryDevice,
                      value: _deviceValue(answers, l10n),
                      detail: _deviceDetail(answers, l10n),
                      onEdit: () => context.go(RouteNames.device),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Ready message ─────────────────────────────────────────
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/circle_check.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                            AppColors.accentPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            l10n.summaryEverythingReady,
                            style: AppTypography.bodyMedium.copyWith(
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Buttons ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  AppButton(
                    label: l10n.buildMyPlan,
                    onPressed: () => context.go(RouteNames.planGeneration),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: l10n.editAnswers,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.go(RouteNames.goal),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.category,
    required this.value,
    required this.detail,
    required this.onEdit,
  });

  final String icon;
  final String category;
  final String value;
  final String detail;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.base,
        0,
        AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentMuted,
              borderRadius: AppRadius.borderMd,
            ),
            child: Center(
              child: SvgPicture.asset(
                icon,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppColors.accentPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.base),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Edit button
          GestureDetector(
            onTap: onEdit,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/edit.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
