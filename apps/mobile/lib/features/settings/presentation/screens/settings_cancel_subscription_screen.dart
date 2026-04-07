import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/settings_card.dart';
import '../../../../core/widgets/settings_row.dart';
import '../../../../l10n/app_localizations.dart';

enum _CancellationReason {
  tooExpensive,
  notUsingEnough,
  notHelpingGoals,
  missingFeatures,
  switchingApps,
  takingBreak,
  other,
}

class SettingsCancelSubscriptionScreen extends StatefulWidget {
  const SettingsCancelSubscriptionScreen({super.key});

  @override
  State<SettingsCancelSubscriptionScreen> createState() =>
      _SettingsCancelSubscriptionScreenState();
}

class _SettingsCancelSubscriptionScreenState
    extends State<SettingsCancelSubscriptionScreen> {
  final Set<_CancellationReason> _selectedReasons = <_CancellationReason>{};

  void _toggleReason(_CancellationReason reason) {
    setState(() {
      if (_selectedReasons.contains(reason)) {
        _selectedReasons.remove(reason);
      } else {
        _selectedReasons.add(reason);
      }
    });
  }

  Future<void> _submitFeedback() async {
    final l10n = AppLocalizations.of(context)!;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: Text(
          l10n.settingsSubscriptionCancellationInfoTitle,
          style: AppTypography.titleLarge,
        ),
        content: Text(
          l10n.settingsSubscriptionCancellationInfoBody,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              l10n.settingsSubscriptionDialogButton,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.accentPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    context.pop();
  }

  String _reasonLabel(AppLocalizations l10n, _CancellationReason reason) {
    return switch (reason) {
      _CancellationReason.tooExpensive =>
        l10n.settingsCancelSubscriptionReasonTooExpensive,
      _CancellationReason.notUsingEnough =>
        l10n.settingsCancelSubscriptionReasonNotUsingEnough,
      _CancellationReason.notHelpingGoals =>
        l10n.settingsCancelSubscriptionReasonNotHelpingGoals,
      _CancellationReason.missingFeatures =>
        l10n.settingsCancelSubscriptionReasonMissingFeatures,
      _CancellationReason.switchingApps =>
        l10n.settingsCancelSubscriptionReasonSwitchingApps,
      _CancellationReason.takingBreak =>
        l10n.settingsCancelSubscriptionReasonTakingBreak,
      _CancellationReason.other => l10n.settingsCancelSubscriptionReasonOther,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reasons = _CancellationReason.values;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.settingsCancelSubscription),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.settingsCancelSubscriptionPrompt,
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SettingsCard(
                        children: reasons
                            .map(
                              (reason) => SettingsRow(
                                label: _reasonLabel(l10n, reason),
                                variant: SettingsRowVariant.selection,
                                isSelected: _selectedReasons.contains(reason),
                                onTap: () => _toggleReason(reason),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.continueButton,
                onPressed: _selectedReasons.isEmpty ? null : _submitFeedback,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.settingsNotNow,
                onPressed: () => context.pop(),
                variant: AppButtonVariant.text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
