import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/widgets/settings_card.dart';
import '../../../../core/widgets/settings_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../localization/presentation/locale_provider.dart';

class SettingsLanguageScreen extends ConsumerWidget {
  const SettingsLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale =
        ref.watch(localeProvider).value ?? Localizations.localeOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(title: l10n.settingsLanguage),
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
                label: l10n.settingsLanguageEnglish,
                iconAsset: 'assets/icons/globe.svg',
                iconColor: currentLocale.languageCode == 'en'
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
                variant: SettingsRowVariant.selection,
                isSelected: currentLocale.languageCode == 'en',
                onTap: () => ref
                    .read(localeProvider.notifier)
                    .setLocale(const Locale('en')),
              ),
              SettingsRow(
                label: l10n.settingsLanguageSpanish,
                iconAsset: 'assets/icons/globe.svg',
                iconColor: currentLocale.languageCode == 'es'
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
                variant: SettingsRowVariant.selection,
                isSelected: currentLocale.languageCode == 'es',
                onTap: () => ref
                    .read(localeProvider.notifier)
                    .setLocale(const Locale('es')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
