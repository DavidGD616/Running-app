import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/settings_card.dart';
import '../../../onboarding/presentation/onboarding_provider.dart';
import '../../../onboarding/presentation/onboarding_values.dart';
import '../../../../l10n/app_localizations.dart';

enum SettingsGoalReviewMode { editGoal, newGoal }

class SettingsGoalReviewScreen extends ConsumerWidget {
  const SettingsGoalReviewScreen({super.key, required this.mode});

  final SettingsGoalReviewMode mode;

  String _formatDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMMd(locale).format(date);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _valueOrDash(String? value) =>
      value == null || value.isEmpty ? '—' : value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final answers = ref.watch(onboardingProvider);
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

    final race = answers['race'] as String?;
    final hasRaceDate = answers['hasRaceDate'] as bool?;
    final raceDate = answers['raceDate'] as DateTime?;
    final priority = answers['priority'] as String?;
    final currentTime = answers['currentTime'] as Duration?;
    final targetTime = answers['targetTime'] as Duration?;

    final trainingDays = answers['trainingDays'] as String?;
    final longRunDay = answers['longRunDay'] as String?;
    final weekdayTime = answers['weekdayTime'] as String?;
    final weekendTime = answers['weekendTime'] as String?;
    final hardDays = (answers['hardDays'] as List?)?.cast<String>() ?? const [];

    final planPreference = answers['planPreference'] as String?;

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
                            value: race != null
                                ? OnboardingValues.localizeRace(race, l10n)
                                : '—',
                          ),
                          _SummaryRow(
                            label: l10n.raceDateLabel,
                            value: hasRaceDate == true && raceDate != null
                                ? _formatDate(context, raceDate)
                                : l10n.no,
                          ),
                          _SummaryRow(
                            label: l10n.priorityLabel,
                            value: priority != null
                                ? OnboardingValues.localizePriority(
                                    priority,
                                    l10n,
                                  )
                                : '—',
                          ),
                          if (currentTime != null)
                            _SummaryRow(
                              label: l10n.currentRaceTime,
                              value: _formatDuration(currentTime),
                            ),
                          if (targetTime != null)
                            _SummaryRow(
                              label: l10n.targetRaceTime,
                              value: _formatDuration(targetTime),
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
