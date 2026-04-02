import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/profile_card.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/settings_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../user_preferences/presentation/user_preferences_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.watch(userProfileDisplayProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.lg,
            AppSpacing.screen, AppSpacing.xl,
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
                planName: profile.planName,
                weekInfo: l10n.profileWeekFull(
                  profile.currentWeekNumber.toString(),
                  profile.totalWeeks.toString(),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Plan & Goals ───────────────────────────────────
              SectionLabel(label: l10n.settingsPlanGoalsSection),
              const SizedBox(height: AppSpacing.md),
              _SettingsCard(
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
              _SettingsCard(
                children: [
                  SettingsRow(
                    label: l10n.settingsLanguage,
                    iconAsset: 'assets/icons/globe.svg',
                    variant: SettingsRowVariant.value,
                    valueLabel: l10n.settingsLanguageValue,
                    onTap: () {},
                  ),
                  SettingsRow(
                    label: l10n.settingsUnits,
                    iconAsset: 'assets/icons/ruler.svg',
                    variant: SettingsRowVariant.value,
                    valueLabel: l10n.settingsUnitsValue,
                    onTap: () {},
                  ),
                  SettingsRow(
                    label: l10n.settingsAudioGuidance,
                    iconAsset: 'assets/icons/speaker.svg',
                    variant: SettingsRowVariant.value,
                    valueLabel: l10n.settingsAudioValue,
                    onTap: () {},
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
              _SettingsCard(
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

// ── Settings card (groups rows with dividers) ─────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: children[i],
            ),
            if (i < children.length - 1)
              Divider(
                height: 1,
                color: AppColors.borderDefault.withValues(alpha: 0.5),
              ),
          ],
        ],
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
