import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../l10n/app_localizations.dart';

class SettingsSubscriptionScreen extends StatelessWidget {
  const SettingsSubscriptionScreen({super.key});

  static final DateTime _nextBillingDate = DateTime(2026, 6, 16);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final nextBillingDate = DateFormat(
      'MMMM d, y',
      locale,
    ).format(_nextBillingDate);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.settingsSubscription),
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
              _SubscriptionSummaryCard(
                activePlanLabel: l10n.settingsSubscriptionActivePlan,
                planName: l10n.settingsSubscriptionPlanName,
                nextBillingDateLabel: l10n.settingsSubscriptionNextBillingDate,
                nextBillingDate: nextBillingDate,
                helperText: l10n.settingsSubscriptionAutoRenewNotice,
              ),
              const Spacer(),
              _DangerButton(
                label: l10n.settingsCancelSubscription,
                onPressed: () =>
                    context.push(RouteNames.settingsSubscriptionCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionSummaryCard extends StatelessWidget {
  const _SubscriptionSummaryCard({
    required this.activePlanLabel,
    required this.planName,
    required this.nextBillingDateLabel,
    required this.nextBillingDate,
    required this.helperText,
  });

  final String activePlanLabel;
  final String planName;
  final String nextBillingDateLabel;
  final String nextBillingDate;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _SubscriptionField(label: activePlanLabel, value: planName),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: AppColors.borderDefault.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.lg),
          _SubscriptionField(
            label: nextBillingDateLabel,
            value: nextBillingDate,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            helperText,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionField extends StatelessWidget {
  const _SubscriptionField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTypography.titleLarge),
      ],
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(color: AppColors.error),
        ),
      ),
    );
  }
}
