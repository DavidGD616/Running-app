import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../l10n/app_localizations.dart';

enum SettingsAccountSecurityInfoMode { email, password }

class SettingsAccountSecurityInfoScreen extends StatelessWidget {
  const SettingsAccountSecurityInfoScreen({super.key, required this.mode});

  final SettingsAccountSecurityInfoMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = switch (mode) {
      SettingsAccountSecurityInfoMode.email => l10n.emailLabel,
      SettingsAccountSecurityInfoMode.password => l10n.passwordLabel,
    };
    final subtitle = switch (mode) {
      SettingsAccountSecurityInfoMode.email =>
        l10n.settingsAccountEmailUnavailableSubtitle,
      SettingsAccountSecurityInfoMode.password =>
        l10n.settingsAccountPasswordUnavailableSubtitle,
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: title),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.xl,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: AppRadius.borderLg,
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsAccountSecurityUnavailableTitle,
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
