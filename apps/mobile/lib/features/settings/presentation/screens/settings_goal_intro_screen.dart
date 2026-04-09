import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../l10n/app_localizations.dart';

enum SettingsGoalIntroMode { editGoal, newGoal }

class SettingsGoalIntroScreen extends StatelessWidget {
  const SettingsGoalIntroScreen({super.key, required this.mode});

  final SettingsGoalIntroMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = switch (mode) {
      SettingsGoalIntroMode.editGoal => l10n.settingsEditGoal,
      SettingsGoalIntroMode.newGoal => l10n.settingsNewGoal,
    };
    final headline = switch (mode) {
      SettingsGoalIntroMode.editGoal => l10n.settingsEditGoalIntroTitle,
      SettingsGoalIntroMode.newGoal => l10n.settingsNewGoalIntroTitle,
    };
    final subtitle = switch (mode) {
      SettingsGoalIntroMode.editGoal => l10n.settingsEditGoalIntroSubtitle,
      SettingsGoalIntroMode.newGoal => l10n.settingsNewGoalIntroSubtitle,
    };
    final ctaLabel = switch (mode) {
      SettingsGoalIntroMode.editGoal => l10n.settingsEditGoal,
      SettingsGoalIntroMode.newGoal => l10n.setGoalButton,
    };
    final nextRoute = switch (mode) {
      SettingsGoalIntroMode.editGoal =>
        RouteNames.settingsUpdatePlanEditGoalForm,
      SettingsGoalIntroMode.newGoal => RouteNames.settingsUpdatePlanNewGoalForm,
    };
    final items = switch (mode) {
      SettingsGoalIntroMode.editGoal => [
        (
          icon: 'assets/icons/target.svg',
          text: l10n.settingsEditGoalIntroPointRace,
        ),
        (
          icon: 'assets/icons/calendar.svg',
          text: l10n.settingsEditGoalIntroPointDate,
        ),
        (
          icon: 'assets/icons/trophy.svg',
          text: l10n.settingsEditGoalIntroPointPriority,
        ),
        (
          icon: 'assets/icons/sparkles.svg',
          text: l10n.settingsEditGoalIntroPointTraining,
        ),
      ],
      SettingsGoalIntroMode.newGoal => [
        (
          icon: 'assets/icons/target.svg',
          text: l10n.settingsNewGoalIntroPointRace,
        ),
        (
          icon: 'assets/icons/calendar.svg',
          text: l10n.settingsNewGoalIntroPointDate,
        ),
        (
          icon: 'assets/icons/trophy.svg',
          text: l10n.settingsNewGoalIntroPointPlan,
        ),
        (
          icon: 'assets/icons/sparkles.svg',
          text: l10n.settingsNewGoalIntroPointTraining,
        ),
      ],
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: title),
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
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.accentMuted,
                          borderRadius: AppRadius.borderXl,
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/target.svg',
                            width: 32,
                            height: 32,
                            colorFilter: const ColorFilter.mode(
                              AppColors.accentPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      Text(headline, style: AppTypography.headlineMedium),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        subtitle,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      ...items.indexed.map((entry) {
                        final index = entry.$1;
                        final item = entry.$2;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == items.length - 1
                                ? 0
                                : AppSpacing.lg,
                          ),
                          child: _GoalIntroItem(
                            iconAsset: item.icon,
                            text: item.text,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              AppButton(
                label: ctaLabel,
                onPressed: () => context.push(nextRoute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalIntroItem extends StatelessWidget {
  const _GoalIntroItem({required this.iconAsset, required this.text});

  final String iconAsset;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.accentMuted,
            borderRadius: AppRadius.borderMd,
          ),
          child: Center(
            child: SvgPicture.asset(
              iconAsset,
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
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              text,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
