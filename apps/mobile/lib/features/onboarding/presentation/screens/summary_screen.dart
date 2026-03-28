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
import '../onboarding_provider.dart';
import '../../../../l10n/app_localizations.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  // ── Helper: format DateTime as "Month DD, YYYY" ──────────────────────────
  String _formatDate(DateTime d, AppLocalizations l10n) {
    final months = [
      l10n.monthJanuary, l10n.monthFebruary, l10n.monthMarch, l10n.monthApril,
      l10n.monthMay, l10n.monthJune, l10n.monthJuly, l10n.monthAugust,
      l10n.monthSeptember, l10n.monthOctober, l10n.monthNovember, l10n.monthDecember,
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  // ── Canonical → localized mappers ─────────────────────────────────────────

  String _localizedRace(String canonical, AppLocalizations l10n) {
    switch (canonical) {
      case '5K': return l10n.race5K;
      case '10K': return l10n.race10K;
      case 'Half Marathon': return l10n.raceHalfMarathon;
      case 'Marathon': return l10n.raceMarathon;
      case 'Other': return l10n.raceOther;
      default: return canonical;
    }
  }

  String _localizedPriority(String canonical, AppLocalizations l10n) {
    switch (canonical) {
      case 'Just finish': return l10n.priorityJustFinish;
      case 'Finish feeling strong': return l10n.priorityFinishStrong;
      case 'Improve my time': return l10n.priorityImproveTime;
      case 'Build consistency': return l10n.priorityConsistency;
      case 'General fitness': return l10n.priorityGeneralFitness;
      default: return canonical;
    }
  }

  String _localizedExperience(String canonical, AppLocalizations l10n) {
    switch (canonical) {
      case 'Brand new': return l10n.experienceBrandNew;
      case 'Beginner': return l10n.experienceBeginner;
      case 'Intermediate': return l10n.experienceIntermediate;
      case 'Experienced': return l10n.experienceExperienced;
      default: return canonical;
    }
  }

  String _localizedGuidanceMode(String canonical, AppLocalizations l10n) {
    switch (canonical) {
      case 'Effort': return l10n.guidanceEffort;
      case 'Pace': return l10n.guidancePace;
      case 'Heart rate': return l10n.guidanceHeartRate;
      case 'Decide for me': return l10n.guidanceDecideForMe;
      default: return canonical;
    }
  }

  String _localizedPlanPref(String canonical, AppLocalizations l10n) {
    switch (canonical) {
      case 'Safest possible': return l10n.planSafest;
      case 'Balanced': return l10n.planBalanced;
      case 'Performance-focused': return l10n.planPerformance;
      default: return canonical;
    }
  }

  String _localizedNoWatchGuidance(String canonical, AppLocalizations l10n) {
    switch (canonical) {
      case 'Effort only': return l10n.noWatchEffortOnly;
      case 'Time-based runs': return l10n.noWatchTimeBased;
      case 'Simple beginner guidance': return l10n.noWatchBeginner;
      case 'Decide for me': return l10n.noWatchDecideForMe;
      default: return canonical;
    }
  }

  String _localizedCoachingTone(String canonical, AppLocalizations l10n) {
    switch (canonical) {
      case 'Simple and direct': return l10n.toneSimple;
      case 'Encouraging': return l10n.toneEncouraging;
      case 'Detailed and data-driven': return l10n.toneDetailed;
      case 'Strict and performance-focused': return l10n.toneStrict;
      default: return canonical;
    }
  }

  // ── Build display values from provider data ───────────────────────────────

  String _goalValue(Map<String, dynamic> a, AppLocalizations l10n) {
    final race = a['race'] as String?;
    if (race == null) return '—';
    return _localizedRace(race, l10n);
  }

  String _goalDetail(Map<String, dynamic> a, AppLocalizations l10n) {
    final date = a['raceDate'] as DateTime?;
    final priority = a['priority'] as String?;
    final localizedPriority = priority != null ? _localizedPriority(priority, l10n) : '—';
    if (date != null) return '${_formatDate(date, l10n)} · $localizedPriority';
    return localizedPriority;
  }

  String _fitnessValue(Map<String, dynamic> a, AppLocalizations l10n) {
    final exp = a['experience'] as String?;
    if (exp == null) return '—';
    return _localizedExperience(exp, l10n);
  }

  String _fitnessDetail(Map<String, dynamic> a, AppLocalizations l10n) {
    final experience = a['experience'] as String?;
    if (experience == 'Brand new') {
      final can = a['canRun10Min'] as bool?;
      if (can == null) return '—';
      return l10n.summaryCanRun10Min(can ? l10n.yes : l10n.no);
    }
    final days = (a['runningDays'] as String?) ?? '—';
    final volume = (a['weeklyVolume'] as String?) ?? '—';
    return l10n.summaryFitnessDetail(days, volume);
  }

  String _scheduleValue(Map<String, dynamic> a, AppLocalizations l10n) {
    final days = a['trainingDays'] as String?;
    return days != null ? l10n.summaryDaysPerWeek(days) : '—';
  }

  String _scheduleDetail(Map<String, dynamic> a, AppLocalizations l10n) {
    final longRun = (a['longRunDay'] as String?) ?? '—';
    final time = (a['preferredTimeOfDay'] as String?) ?? '—';
    final weekday = (a['weekdayTime'] as String?) ?? '—';
    return l10n.summaryScheduleDetail(longRun, time, weekday);
  }

  String _healthValue(Map<String, dynamic> a, AppLocalizations l10n) {
    final pain = a['painLevel'] as String?;
    if (pain == null) return '—';
    return pain == 'No' ? l10n.summaryNoPain : l10n.summaryWithPain(pain);
  }

  String _healthDetail(Map<String, dynamic> a, AppLocalizations l10n) {
    final pref = (a['planPreference'] as String?) ?? '—';
    return l10n.summaryPlanPref(_localizedPlanPref(pref, l10n));
  }

  String _trainingValue(Map<String, dynamic> a, AppLocalizations l10n) {
    final mode = a['guidanceMode'] as String?;
    return mode != null ? l10n.summaryGuidanceBased(_localizedGuidanceMode(mode, l10n)) : '—';
  }

  String _trainingDetail(Map<String, dynamic> a, AppLocalizations l10n) {
    final speed = (a['speedWorkouts'] as String?) ?? '—';
    final strength = (a['strengthTraining'] as String?) ?? '—';
    final surface = (a['runSurface'] as String?) ?? '—';
    final terrain = (a['terrain'] as String?) ?? '—';
    return l10n.summaryTrainingDetail(speed, strength, surface, terrain);
  }

  String _deviceValue(Map<String, dynamic> a, AppLocalizations l10n) {
    final hasWatch = a['hasWatch'] as String?;
    if (hasWatch == 'Yes') {
      final device = (a['device'] as String?) ?? 'Watch';
      return l10n.summaryDeviceConnected(device);
    }
    if (hasWatch == 'No') return l10n.summaryNoWatch;
    return '—';
  }

  String _deviceDetail(Map<String, dynamic> a, AppLocalizations l10n) {
    final hasWatch = a['hasWatch'] as String?;
    if (hasWatch == 'Yes') {
      final usage = (a['dataUsage'] as String?) ?? '—';
      final hr = (a['hrZones'] as String?) ?? '—';
      final auto = (a['autoAdjust'] as String?) ?? '—';
      return l10n.summaryDeviceDetail(usage, hr, auto);
    }
    final guidance = a['noWatchGuidance'] as String?;
    return guidance != null ? _localizedNoWatchGuidance(guidance, l10n) : '—';
  }

  String _recoveryValue(Map<String, dynamic> a, AppLocalizations l10n) {
    final sleep = a['sleep'] as String?;
    return sleep != null ? l10n.summarySleepHours(sleep) : '—';
  }

  String _recoveryDetail(Map<String, dynamic> a, AppLocalizations l10n) {
    final work = (a['workLevel'] as String?) ?? '—';
    final stress = (a['stressLevel'] as String?) ?? '—';
    final feel = (a['dayFeeling'] as String?) ?? '—';
    return l10n.summaryRecoveryDetail(work, stress, feel);
  }

  String _motivationValue(Map<String, dynamic> a) {
    final list = a['motivations'] as List?;
    if (list == null || list.isEmpty) return '—';
    return list.join(', ');
  }

  String _motivationDetail(Map<String, dynamic> a, AppLocalizations l10n) {
    final tone = (a['coachingTone'] as String?) ?? '—';
    final conf = (a['confidence'] as int?) ?? 5;
    return l10n.summaryMotivationDetail(_localizedCoachingTone(tone, l10n), conf.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final answers = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top nav ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.xs, AppSpacing.screen, 0,
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
                        l10n.onboardingStep(9, 9),
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
                    child: AppProgressBar(current: 9, total: 9),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen, AppSpacing.lg,
                  AppSpacing.screen, AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.summaryTitle,
                        style: AppTypography.headlineMedium),
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
                      value: _goalValue(answers, l10n),
                      detail: _goalDetail(answers, l10n),
                      onEdit: () => context.go(RouteNames.goal),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/trending_up.svg',
                      category: l10n.summaryCurrentLevel,
                      value: _fitnessValue(answers, l10n),
                      detail: _fitnessDetail(answers, l10n),
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
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/moon.svg',
                      category: l10n.summaryRecovery,
                      value: _recoveryValue(answers, l10n),
                      detail: _recoveryDetail(answers, l10n),
                      onEdit: () => context.go(RouteNames.recovery),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/motivation.svg',
                      category: l10n.summaryMotivation,
                      value: _motivationValue(answers),
                      detail: _motivationDetail(answers, l10n),
                      onEdit: () => context.go(RouteNames.motivation),
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
                AppSpacing.screen, AppSpacing.sm,
                AppSpacing.screen, AppSpacing.xl,
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
        AppSpacing.base, AppSpacing.base, 0, AppSpacing.base,
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
