import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/settings_card.dart';
import '../../../../core/widgets/settings_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class SettingsAccountScreen extends ConsumerWidget {
  const SettingsAccountScreen({super.key});

  String _displayName(AppLocalizations l10n, String? displayName) {
    final normalized = displayName?.trim();
    if (normalized == null || normalized.isEmpty) {
      return l10n.profileDefaultName;
    }
    return normalized;
  }

  String _displayGender(AppLocalizations l10n, ProfileGender? gender) {
    return switch (gender) {
      ProfileGender.male => l10n.genderMale,
      ProfileGender.female => l10n.genderFemale,
      ProfileGender.other => l10n.genderOther,
      null => l10n.settingsAccountNotSet,
    };
  }

  String _displayBirthday(BuildContext context, DateTime? dateOfBirth) {
    if (dateOfBirth == null) {
      return AppLocalizations.of(context)!.settingsAccountNotSet;
    }
    return MaterialLocalizations.of(context).formatMediumDate(dateOfBirth);
  }

  Future<void> _pickDateOfBirth(
    BuildContext context,
    WidgetRef ref,
    DateTime? currentDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentPrimary,
              onPrimary: AppColors.backgroundPrimary,
              surface: AppColors.backgroundSecondary,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await ref.read(userPreferencesProvider.notifier).setDateOfBirth(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final preferences = ref.watch(userPreferencesProvider).value;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.settingsAccount),
      body: SafeArea(
        top: false,
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
              SectionLabel(label: l10n.settingsAccountProfileSection),
              const SizedBox(height: AppSpacing.md),
              SettingsCard(
                children: [
                  SettingsRow(
                    label: l10n.settingsAccountNameLabel,
                    iconAsset: 'assets/icons/person.svg',
                    variant: SettingsRowVariant.value,
                    valueLabel: _displayName(l10n, preferences?.displayName),
                    onTap: () => context.push(RouteNames.settingsAccountName),
                  ),
                  SettingsRow(
                    label: l10n.dateOfBirthLabel,
                    iconAsset: 'assets/icons/calendar.svg',
                    variant: SettingsRowVariant.value,
                    valueLabel: _displayBirthday(
                      context,
                      preferences?.dateOfBirth,
                    ),
                    onTap: () => _pickDateOfBirth(
                      context,
                      ref,
                      preferences?.dateOfBirth,
                    ),
                  ),
                  SettingsRow(
                    label: l10n.settingsAccountSexLabel,
                    iconAsset: 'assets/icons/person.svg',
                    variant: SettingsRowVariant.value,
                    valueLabel: _displayGender(l10n, preferences?.gender),
                    onTap: () => context.push(RouteNames.settingsAccountSex),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionLabel(label: l10n.settingsAccountSecuritySection),
              const SizedBox(height: AppSpacing.md),
              SettingsCard(
                children: [
                  SettingsRow(
                    label: l10n.emailLabel,
                    iconAsset: 'assets/icons/smartphone.svg',
                    variant: SettingsRowVariant.chevron,
                    onTap: () => context.push(RouteNames.settingsAccountEmail),
                  ),
                  SettingsRow(
                    label: l10n.passwordLabel,
                    iconAsset: 'assets/icons/settings.svg',
                    variant: SettingsRowVariant.chevron,
                    onTap: () =>
                        context.push(RouteNames.settingsAccountPassword),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _AccountLogOutCard(label: l10n.settingsLogOut),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountLogOutCard extends ConsumerWidget {
  const _AccountLogOutCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isSigningOut = ref.watch(authNotifierProvider).isLoading;

    return GestureDetector(
      onTap: isSigningOut
          ? null
          : () async {
              final feedback = await ref
                  .read(authNotifierProvider.notifier)
                  .signOut(l10n: l10n);

              if (!context.mounted || feedback == null) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(feedback.message)),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.logout, color: AppColors.error, size: 18),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              isSigningOut ? l10n.authLoadingSignOut : label,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
