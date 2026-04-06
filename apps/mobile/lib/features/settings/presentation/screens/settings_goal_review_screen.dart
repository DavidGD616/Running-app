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

    final race = answers['race'] as String?;
    final hasRaceDate = answers['hasRaceDate'] as bool?;
    final raceDate = answers['raceDate'] as DateTime?;
    final priority = answers['priority'] as String?;
    final currentTime = answers['currentTime'] as Duration?;
    final targetTime = answers['targetTime'] as Duration?;

    final guidanceMode = answers['guidanceMode'] as String?;
    final speedWorkouts = answers['speedWorkouts'] as String?;
    final strengthTraining = answers['strengthTraining'] as String?;
    final runSurface = answers['runSurface'] as String?;
    final terrain = answers['terrain'] as String?;
    final walkRunIntervals = answers['walkRunIntervals'] as String?;

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
                      SectionLabel(label: l10n.settingsSummaryTrainingSection),
                      const SizedBox(height: AppSpacing.sm),
                      SettingsCard(
                        children: [
                          _SummaryRow(
                            label: l10n.guidanceModeLabel,
                            value: _valueOrDash(
                              guidanceMode != null
                                  ? OnboardingValues.localizeGuidanceMode(
                                      guidanceMode,
                                      l10n,
                                    )
                                  : null,
                            ),
                          ),
                          _SummaryRow(
                            label: l10n.speedWorkoutsLabel,
                            value: _valueOrDash(
                              speedWorkouts != null
                                  ? OnboardingValues.localizeBinary(
                                      speedWorkouts,
                                      l10n,
                                    )
                                  : null,
                            ),
                          ),
                          _SummaryRow(
                            label: l10n.strengthTrainingLabel,
                            value: _valueOrDash(
                              strengthTraining != null
                                  ? OnboardingValues.localizeStrengthTraining(
                                      strengthTraining,
                                      l10n,
                                    )
                                  : null,
                            ),
                          ),
                          _SummaryRow(
                            label: l10n.runSurfaceLabel,
                            value: _valueOrDash(
                              runSurface != null
                                  ? OnboardingValues.localizeSurface(
                                      runSurface,
                                      l10n,
                                    )
                                  : null,
                            ),
                          ),
                          _SummaryRow(
                            label: l10n.terrainLabel,
                            value: _valueOrDash(
                              terrain != null
                                  ? OnboardingValues.localizeTerrain(
                                      terrain,
                                      l10n,
                                    )
                                  : null,
                            ),
                          ),
                          _SummaryRow(
                            label: l10n.walkRunLabel,
                            value: _valueOrDash(
                              walkRunIntervals != null
                                  ? OnboardingValues.localizeBinary(
                                      walkRunIntervals,
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
                onPressed: () => context.go(RouteNames.settingsUpdatePlan),
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
