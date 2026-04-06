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

class SettingsAccountSexScreen extends ConsumerWidget {
  const SettingsAccountSexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentGender = ref.watch(userPreferencesProvider).value?.gender;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.settingsAccountSexLabel),
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
                label: l10n.genderMale,
                variant: SettingsRowVariant.selection,
                isSelected: currentGender == ProfileGender.male,
                onTap: () => ref
                    .read(userPreferencesProvider.notifier)
                    .setGender(ProfileGender.male),
              ),
              SettingsRow(
                label: l10n.genderFemale,
                variant: SettingsRowVariant.selection,
                isSelected: currentGender == ProfileGender.female,
                onTap: () => ref
                    .read(userPreferencesProvider.notifier)
                    .setGender(ProfileGender.female),
              ),
              SettingsRow(
                label: l10n.genderOther,
                variant: SettingsRowVariant.selection,
                isSelected: currentGender == ProfileGender.other,
                onTap: () => ref
                    .read(userPreferencesProvider.notifier)
                    .setGender(ProfileGender.other),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
