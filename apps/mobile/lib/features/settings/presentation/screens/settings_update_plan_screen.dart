import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/settings_card.dart';
import '../../../../core/widgets/settings_row.dart';
import '../../../../l10n/app_localizations.dart';

class SettingsUpdatePlanScreen extends StatelessWidget {
  const SettingsUpdatePlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.settingsUpdatePlanInfo),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.xl,
          ),
          child: SettingsCard(
            children: [
              SettingsRow(
                label: l10n.settingsEditGoal,
                iconAsset: 'assets/icons/target.svg',
                variant: SettingsRowVariant.chevron,
                onTap: () =>
                    context.push(RouteNames.settingsUpdatePlanEditGoal),
              ),
              SettingsRow(
                label: l10n.settingsNewGoal,
                iconAsset: 'assets/icons/target.svg',
                variant: SettingsRowVariant.chevron,
                onTap: () => context.push(RouteNames.settingsUpdatePlanNewGoal),
              ),
              SettingsRow(
                label: l10n.settingsChangeSchedule,
                iconAsset: 'assets/icons/calendar.svg',
                variant: SettingsRowVariant.chevron,
                onTap: () =>
                    context.push(RouteNames.settingsUpdatePlanSchedule),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
