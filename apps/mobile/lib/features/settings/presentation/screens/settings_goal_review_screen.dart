import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/settings_card.dart';
import '../../../goals/presentation/goal_presenter.dart';
import '../../../goals/presentation/goal_provider.dart';
import '../../../onboarding/presentation/onboarding_provider.dart';
import '../../../profile/domain/models/runner_profile.dart';
import '../../../onboarding/presentation/onboarding_values.dart';
import '../../../../l10n/app_localizations.dart';

enum SettingsGoalReviewMode { editGoal, newGoal }

class SettingsGoalReviewScreen extends ConsumerWidget {
  const SettingsGoalReviewScreen({super.key, required this.mode});

  final SettingsGoalReviewMode mode;

  String _valueOrDash(String? value) =>
      value == null || value.isEmpty ? '—' : value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final onboardingAsync = ref.watch(onboardingProvider);
    if (onboardingAsync.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (onboardingAsync.hasError) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(
          child: Text(
            l10n.errorGeneric,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    final answers = onboardingAsync.value ?? const RunnerProfileDraft();
    final goal = ref.watch(onboardingGoalProvider);
    final goalTitle = switch (mode) {
      SettingsGoalReviewMode.editGoal => l10n.settingsEditGoal,
      SettingsGoalReviewMode.newGoal => l10n.settingsNewGoal,
    };
    final nextRoute = switch (mode) {
      SettingsGoalReviewMode.editGoal =>
        RouteNames.settingsUpdatePlanEditGoalGenerating,
      SettingsGoalReviewMode.newGoal =>
        RouteNames.settingsUpdatePlanNewGoalGenerating,
    };

    final trainingDays = answers.schedule.trainingDaysKey;
    final longRunDay = answers.schedule.longRunDayKey;
    final weekdayTime = answers.schedule.weekdayTimeKey;
    final weekendTime = answers.schedule.weekendTimeKey;
    final hardDays = answers.schedule.hardDayKeys;

    final planPreference = answers.trainingPreferences.planPreferenceKey;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.settingsReviewChangesTitle),
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
                      Text(
                        l10n.settingsReviewChangesSubtitle(goalTitle),
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SectionLabel(label: l10n.settingsSummaryGoalSection),
                      const SizedBox(height: AppSpacing.sm),
                      SettingsCard(
                        children: [
                          _SummaryRow(
                            label: l10n.goalRaceLabel,
                            value: goalRaceLabel(goal, l10n),
                          ),
                          _SummaryRow(
                            label: l10n.raceDateLabel,
                            value: formatGoalDate(context, goal),
                          ),
                          _SummaryRow(
                            label: l10n.priorityLabel,
                            value: goalPriorityLabel(goal, l10n),
                          ),
                          if (goal?.currentTime != null)
                            _SummaryRow(
                              label: l10n.currentRaceTime,
                              value: formatGoalDuration(goal!.currentTime!),
                            ),
                          if (goal?.targetTime != null)
                            _SummaryRow(
                              label: l10n.targetRaceTime,
                              value: formatGoalDuration(goal!.targetTime!),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SectionLabel(label: l10n.scheduleTitle),
                      const SizedBox(height: AppSpacing.sm),
                      SettingsCard(
                        children: [
                          _SummaryRow(
                            label: l10n.trainingDaysLabel,
                            value: _valueOrDash(trainingDays),
                          ),
                          _SummaryRow(
                            label: l10n.longRunDayLabel,
                            value: _valueOrDash(
                              longRunDay != null
                                  ? OnboardingValues.localizeDay(
                                      longRunDay,
                                      l10n,
                                    )
                                  : null,
                            ),
                          ),
                          _SummaryRow(
                            label: l10n.weekdayTimeLabel,
                            value: _valueOrDash(
                              weekdayTime != null
                                  ? OnboardingValues.localizeTimeSlot(
                                      weekdayTime,
                                      l10n,
                                    )
                                  : null,
                            ),
                          ),
                          _SummaryRow(
                            label: l10n.weekendTimeLabel,
                            value: _valueOrDash(
                              weekendTime != null
                                  ? OnboardingValues.localizeTimeSlot(
                                      weekendTime,
                                      l10n,
                                    )
                                  : null,
                            ),
                          ),
                          _SummaryRow(
                            label: l10n.hardDaysLabel,
                            value: hardDays.isEmpty
                                ? '—'
                                : hardDays
                                      .map(
                                        (day) => OnboardingValues.localizeDay(
                                          day,
                                          l10n,
                                        ),
                                      )
                                      .join(', '),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SectionLabel(label: l10n.settingsSummaryTrainingSection),
                      const SizedBox(height: AppSpacing.sm),
                      SettingsCard(
                        children: [
                          _SummaryRow(
                            label: l10n.planPreferenceLabel,
                            value: _valueOrDash(
                              planPreference != null
                                  ? OnboardingValues.localizePlanPreference(
                                      planPreference,
                                      l10n,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.settingsAcceptChanges,
                onPressed: () => context.push(nextRoute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTypography.bodyLarge)),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
