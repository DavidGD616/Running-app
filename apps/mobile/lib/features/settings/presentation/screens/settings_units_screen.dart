import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/settings_card.dart';
import '../../../../core/widgets/settings_row.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class SettingsUnitsScreen extends ConsumerWidget {
  const SettingsUnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final preferences = ref.watch(userPreferencesProvider).value;
    final currentUnitSystem = preferences?.unitSystem ?? UnitSystem.km;
    final currentShortDistanceUnit =
        preferences?.shortDistanceUnit ?? ShortDistanceUnit.meters;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.settingsUnits),
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
              SectionLabel(label: l10n.settingsUnitsDistanceSection),
              const SizedBox(height: AppSpacing.md),
              SettingsCard(
                children: [
                  SettingsRow(
                    label: l10n.settingsUnitsMetric,
                    iconAsset: 'assets/icons/ruler.svg',
                    iconColor: currentUnitSystem == UnitSystem.km
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                    variant: SettingsRowVariant.selection,
                    isSelected: currentUnitSystem == UnitSystem.km,
                    onTap: () => ref
                        .read(userPreferencesProvider.notifier)
                        .setUnitSystem(UnitSystem.km),
                  ),
                  SettingsRow(
                    label: l10n.settingsUnitsImperial,
                    iconAsset: 'assets/icons/ruler.svg',
                    iconColor: currentUnitSystem == UnitSystem.miles
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                    variant: SettingsRowVariant.selection,
                    isSelected: currentUnitSystem == UnitSystem.miles,
                    onTap: () => ref
                        .read(userPreferencesProvider.notifier)
                        .setUnitSystem(UnitSystem.miles),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionLabel(label: l10n.settingsUnitsElevationSection),
              const SizedBox(height: AppSpacing.md),
              SettingsCard(
                children: [
                  SettingsRow(
                    label: l10n.settingsUnitsMeters,
                    iconAsset: 'assets/icons/mountain.svg',
                    iconColor:
                        currentShortDistanceUnit == ShortDistanceUnit.meters
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                    variant: SettingsRowVariant.selection,
                    isSelected:
                        currentShortDistanceUnit == ShortDistanceUnit.meters,
                    onTap: () => ref
                        .read(userPreferencesProvider.notifier)
                        .setShortDistanceUnit(ShortDistanceUnit.meters),
                  ),
                  SettingsRow(
                    label: l10n.settingsUnitsFeet,
                    iconAsset: 'assets/icons/mountain.svg',
                    iconColor:
                        currentShortDistanceUnit == ShortDistanceUnit.feet
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                    variant: SettingsRowVariant.selection,
                    isSelected:
                        currentShortDistanceUnit == ShortDistanceUnit.feet,
                    onTap: () => ref
                        .read(userPreferencesProvider.notifier)
                        .setShortDistanceUnit(ShortDistanceUnit.feet),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
