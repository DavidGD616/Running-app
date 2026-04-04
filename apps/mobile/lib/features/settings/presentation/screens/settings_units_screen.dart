import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/settings_card.dart';
import '../../../../core/widgets/settings_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class SettingsUnitsScreen extends ConsumerWidget {
  const SettingsUnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUnitSystem =
        ref.watch(userPreferencesProvider).value?.unitSystem ?? UnitSystem.km;

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
          child: SettingsCard(
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
        ),
      ),
    );
  }
}
