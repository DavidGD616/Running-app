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
import '../onboarding_provider.dart';
import '../../../../l10n/app_localizations.dart';

class PlanReadyScreen extends ConsumerWidget {
  const PlanReadyScreen({super.key});

  // ── Localization mappers (reused from summary pattern) ────────────────────

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

  // ── Plan duration lookup ──────────────────────────────────────────────────

  String _planWeeks(String race) {
    switch (race) {
      case '5K': return '8';
      case '10K': return '10';
      case 'Half Marathon': return '12';
      case 'Marathon': return '16';
      default: return '12';
    }
  }

  // ── Build display values ──────────────────────────────────────────────────

  String _planSubtitle(Map<String, dynamic> a, AppLocalizations l10n) {
    final race = (a['race'] as String?) ?? '';
    final experience = (a['experience'] as String?) ?? '';
    final weeks = _planWeeks(race);
    final localizedRace = _localizedRace(race, l10n);
    final localizedExp = _localizedExperience(experience, l10n);
    final planName = l10n.planReadyWeekPlanName(weeks, localizedRace);
    return '$planName • $localizedExp';
  }

  String _goalDescription(Map<String, dynamic> a, AppLocalizations l10n) {
    final race = (a['race'] as String?) ?? '';
    if (race.isEmpty) return '—';
    return l10n.planReadyGoalDescription(_localizedRace(race, l10n));
  }

  String _scheduleValue(Map<String, dynamic> a, AppLocalizations l10n) {
    final race = (a['race'] as String?) ?? '';
    final days = (a['trainingDays'] as String?) ?? '—';
    final weeks = _planWeeks(race);
    return l10n.planReadyScheduleValue(weeks, days);
  }

  String _longRunDay(Map<String, dynamic> a) {
    return (a['longRunDay'] as String?) ?? '—';
  }

  String _guidanceMode(Map<String, dynamic> a, AppLocalizations l10n) {
    final mode = a['guidanceMode'] as String?;
    return mode != null ? _localizedGuidanceMode(mode, l10n) : '—';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final answers = ref.watch(onboardingProvider);

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
                      _planSubtitle(answers, l10n),
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
                            value: _goalDescription(answers, l10n),
                          ),
                          const SizedBox(height: AppSpacing.base),
                          _PlanDetailRow(
                            iconAsset: 'assets/icons/calendar.svg',
                            label: l10n.planReadyScheduleLabel,
                            value: _scheduleValue(answers, l10n),
                          ),
                          const SizedBox(height: AppSpacing.base),
                          _PlanDetailRow(
                            iconAsset: 'assets/icons/mountain.svg',
                            label: l10n.planReadyLongRunsLabel,
                            value: _longRunDay(answers),
                          ),
                          const SizedBox(height: AppSpacing.base),
                          _PlanDetailRow(
                            iconAsset: 'assets/icons/heart_rate.svg',
                            label: l10n.planReadyGuidanceModeLabel,
                            value: _guidanceMode(answers, l10n),
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
                    label: l10n.planReadyStartPlan,
                    onPressed: () async {
                      await ref.read(onboardingProvider.notifier).markCompleted();
                      if (context.mounted) context.go(RouteNames.today);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: l10n.planReadyViewFullWeek,
                    variant: AppButtonVariant.secondary,
                    onPressed: () async {
                      await ref.read(onboardingProvider.notifier).markCompleted();
                      if (context.mounted) context.go(RouteNames.today);
                    },
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
            Text(label, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value, style: AppTypography.titleMedium),
          ],
        ),
      ],
    );
  }
}
