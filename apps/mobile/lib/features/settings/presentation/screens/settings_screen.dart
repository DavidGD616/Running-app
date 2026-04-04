import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/profile_card.dart';
import '../../../../core/widgets/settings_card.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/settings_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../localization/presentation/locale_provider.dart';
import '../../../training_plan/presentation/training_plan_localization.dart';
import '../../../user_preferences/domain/user_preferences.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _languageValueLabel(AppLocalizations l10n, Locale locale) {
    return switch (locale.languageCode) {
      'es' => l10n.settingsLanguageSpanish,
      _ => l10n.settingsLanguageEnglish,
    };
  }

  String _unitValueLabel(AppLocalizations l10n, UnitSystem unitSystem) {
    return unitSystem == UnitSystem.miles
        ? l10n.settingsUnitsImperial
        : l10n.settingsUnitsMetric;
  }

  String _shortDistanceValueLabel(
    AppLocalizations l10n,
    ShortDistanceUnit shortDistanceUnit,
  ) {
    return shortDistanceUnit == ShortDistanceUnit.feet
        ? l10n.unitFt
        : l10n.unitM;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.watch(userProfileDisplayProvider);
    final currentLocale =
        ref.watch(localeProvider).value ?? Localizations.localeOf(context);
    final preferences = ref.watch(userPreferencesProvider).value;
    final currentUnitSystem = preferences?.unitSystem ?? UnitSystem.km;
    final currentShortDistanceUnit =
        preferences?.shortDistanceUnit ?? ShortDistanceUnit.meters;
    final planName = localizedTrainingPlanName(
      raceType: profile.raceType,
      totalWeeks: profile.totalWeeks,
      l10n: l10n,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
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
              // ── Title ──────────────────────────────────────────
              Text(l10n.settingsTitle, style: AppTypography.headlineLarge),

              const SizedBox(height: AppSpacing.xl),

              // ── Profile card ───────────────────────────────────
              ProfileCard(
                name: l10n.profileDefaultName,
                planName: planName,
                weekInfo: l10n.profileWeekFull(
                  profile.currentWeekNumber.toString(),
                  profile.totalWeeks.toString(),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Plan & Goals ───────────────────────────────────
              SectionLabel(label: l10n.settingsPlanGoalsSection),
              const SizedBox(height: AppSpacing.md),
              SettingsCard(
                children: [
                  SettingsRow(
                    label: l10n.settingsUpdatePlanInfo,
                    iconAsset: 'assets/icons/target.svg',
                    iconColor: AppColors.accentPrimary,
                    variant: SettingsRowVariant.chevron,
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Preferences ────────────────────────────────────
              SectionLabel(label: l10n.settingsPreferencesSection),
              const SizedBox(height: AppSpacing.md),
              SettingsCard(
                children: [
                  SettingsRow(
                    label: l10n.settingsLanguage,
                    iconAsset: 'assets/icons/globe.svg',
                    variant: SettingsRowVariant.value,
                    valueLabel: _languageValueLabel(l10n, currentLocale),
                    onTap: () => context.push(RouteNames.settingsLanguage),
                  ),
                  SettingsRow(
                    label: l10n.settingsUnits,
                    iconAsset: 'assets/icons/ruler.svg',
                    variant: SettingsRowVariant.value,
                    valueLabel:
                        '${_unitValueLabel(l10n, currentUnitSystem)} · ${_shortDistanceValueLabel(l10n, currentShortDistanceUnit)}',
                    onTap: () => context.push(RouteNames.settingsUnits),
                  ),
                  SettingsRow(
                    label: l10n.settingsNotifications,
                    iconAsset: 'assets/icons/bell.svg',
                    variant: SettingsRowVariant.value,
                    valueLabel: l10n.settingsNotificationsValue,
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Connected Devices ──────────────────────────────
              SectionLabel(label: l10n.settingsConnectedDevicesSection),
              const SizedBox(height: AppSpacing.md),
              SettingsCard(
                children: [
                  SettingsRow(
                    label: l10n.settingsGarminConnect,
                    iconAsset: 'assets/icons/watch.svg',
                    variant: SettingsRowVariant.badge,
                    badgeLabel: l10n.settingsConnected,
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Log Out ────────────────────────────────────────
              _LogOutCard(label: l10n.settingsLogOut),

              const SizedBox(height: AppSpacing.lg),

              // ── Version ────────────────────────────────────────
              Center(
                child: Text(
                  l10n.settingsVersion,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textDisabled,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Log out card ──────────────────────────────────────────────────────────────

class _LogOutCard extends StatelessWidget {
  const _LogOutCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
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
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/logout.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    AppColors.error,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
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
