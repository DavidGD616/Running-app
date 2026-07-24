import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/new_goal_models.dart';
import '../../../onboarding/presentation/onboarding_values.dart';
import '../../../profile/domain/models/runner_profile.dart';
import '../new_goal_provider.dart';

class NewGoalPreferencesScreen extends ConsumerStatefulWidget {
  const NewGoalPreferencesScreen({super.key});

  @override
  ConsumerState<NewGoalPreferencesScreen> createState() =>
      _NewGoalPreferencesScreenState();
}

class _NewGoalPreferencesScreenState
    extends ConsumerState<NewGoalPreferencesScreen> {
  bool _initialized = false;
  String? _planPreference;
  bool _isSubmitting = false;

  NewGoalDraft? _draftFromState(NewGoalState state) => switch (state) {
    NewGoalEditing(:final draft) => draft,
    NewGoalRecommendationLoading(:final draft) => draft,
    NewGoalProposalLoading(:final draft) => draft,
    NewGoalProposalReady(:final draft) => draft,
    NewGoalFitnessCheckRequired(:final draft) => draft,
    NewGoalAssessmentPending(:final draft) => draft,
    NewGoalRecommendationReady(:final draft) => draft,
    NewGoalApplying(:final draft) => draft,
    NewGoalFailure(:final draft) => draft,
    NewGoalLoading() => null,
    NewGoalSuccess() => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(newGoalProvider);
    final draft = _draftFromState(state);

    if (!_initialized && draft != null) {
      _planPreference = draft.planPreference.key;
      _initialized = true;
    }
    if (draft == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final preferenceOptions = [
      (
        key: PlanPreferenceChoice.safest.key,
        label: OnboardingValues.localizePlanPreference(
          PlanPreferenceChoice.safest.key,
          l10n,
        ),
        subtitle: OnboardingValues.localizePlanPreferenceSubtitle(
          PlanPreferenceChoice.safest.key,
          l10n,
        ),
      ),
      (
        key: PlanPreferenceChoice.balanced.key,
        label: OnboardingValues.localizePlanPreference(
          PlanPreferenceChoice.balanced.key,
          l10n,
        ),
        subtitle: OnboardingValues.localizePlanPreferenceSubtitle(
          PlanPreferenceChoice.balanced.key,
          l10n,
        ),
      ),
      (
        key: PlanPreferenceChoice.performance.key,
        label: OnboardingValues.localizePlanPreference(
          PlanPreferenceChoice.performance.key,
          l10n,
        ),
        subtitle: OnboardingValues.localizePlanPreferenceSubtitle(
          PlanPreferenceChoice.performance.key,
          l10n,
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.trainingPrefsTitle),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionLabel(label: l10n.planPreferenceLabel),
                      const SizedBox(height: AppSpacing.md),
                      ...preferenceOptions.asMap().entries.map((entry) {
                        final option = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key ==
                                    preferenceOptions.length - 1
                                ? 0
                                : AppSpacing.md,
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
              AppButton(
                label: l10n.continueButton,
                isLoading: _isSubmitting,
                onPressed: _planPreference != null && !_isSubmitting
                    ? () async {
                        setState(() => _isSubmitting = true);
                        try {
                          final selected = PlanPreferenceChoice.fromKey(
                            _planPreference,
                          );
                          if (selected == null) return;
                          await ref
                              .read(newGoalProvider.notifier)
                              .setPlanPreference(selected);
                          if (!context.mounted) return;
                          context.push(RouteNames.settingsUpdatePlanNewGoalHealth);
                        } finally {
                          if (mounted) {
                            setState(() => _isSubmitting = false);
                          }
                        }
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
