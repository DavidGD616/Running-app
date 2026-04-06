import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../onboarding_provider.dart';
import '../onboarding_values.dart';
import '../../../../l10n/app_localizations.dart';

enum TrainingPreferencesFlowMode { onboarding, editGoal, newGoal }

class TrainingPreferencesScreen extends ConsumerStatefulWidget {
  const TrainingPreferencesScreen({
    super.key,
    this.mode = TrainingPreferencesFlowMode.onboarding,
  });

  final TrainingPreferencesFlowMode mode;

  @override
  ConsumerState<TrainingPreferencesScreen> createState() =>
      _TrainingPreferencesScreenState();
}

class _TrainingPreferencesScreenState
    extends ConsumerState<TrainingPreferencesScreen> {
  String? _planPreference;

  @override
  void initState() {
    super.initState();
    final answers = ref.read(onboardingProvider);
    _planPreference = answers['planPreference'] as String?;
  }

  bool get _isComplete => _planPreference != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSettingsFlow =
        widget.mode != TrainingPreferencesFlowMode.onboarding;
    final nextRoute = switch (widget.mode) {
      TrainingPreferencesFlowMode.onboarding => RouteNames.device,
      TrainingPreferencesFlowMode.editGoal =>
        RouteNames.settingsUpdatePlanEditGoalSummary,
      TrainingPreferencesFlowMode.newGoal =>
        RouteNames.settingsUpdatePlanNewGoalSummary,
    };
    final planPreferenceOptions = [
      (
        key: OnboardingValues.planSafest,
        label: l10n.planSafest,
        subtitle: l10n.planSafestSub,
      ),
      (
        key: OnboardingValues.planBalanced,
        label: l10n.planBalanced,
        subtitle: l10n.planBalancedSub,
      ),
      (
        key: OnboardingValues.planPerformance,
        label: l10n.planPerformance,
        subtitle: l10n.planPerformanceSub,
      ),
    ];
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: isSettingsFlow
          ? AppDetailHeaderBar(title: l10n.trainingPrefsTitle)
          : null,
      body: SafeArea(
        top: !isSettingsFlow,
        child: Column(
          children: [
            if (!isSettingsFlow)
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
                          l10n.onboardingStep(5, 7),
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
                      child: AppProgressBar(current: 5, total: 7),
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
                    if (!isSettingsFlow) ...[
                      Text(
                        l10n.trainingPrefsTitle,
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.trainingPrefsSubtitle,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    // ── 1. Plan preference ───────────────────────────────────
                    Text(
                      l10n.planPreferenceLabel,
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...planPreferenceOptions.asMap().entries.map((entry) {
                      final option = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == planPreferenceOptions.length - 1
                              ? 0
                              : AppSpacing.sm,
                        ),
                        child: _SelectCard(
                          label: option.label,
                          subtitle: option.subtitle,
                          isSelected: _planPreference == option.key,
                          onTap: () =>
                              setState(() => _planPreference = option.key),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // ── Continue button ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: AppButton(
                label: l10n.continueButton,
                onPressed: _isComplete
                    ? () {
                        ref
                            .read(onboardingProvider.notifier)
                            .setTraining(planPreference: _planPreference!);
                        context.push(nextRoute);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full-width select card ─────────────────────────────────────────────────

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.base,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
