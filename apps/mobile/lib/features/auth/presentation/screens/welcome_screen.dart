import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../features/localization/presentation/locale_provider.dart';
import '../../../../l10n/app_localizations.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Derive selected language from the locale provider — no local state needed
    final locale = ref.watch(localeProvider).value ?? const Locale('en');
    final selectedLanguage = locale.languageCode.toUpperCase(); // 'EN' or 'ES'

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const _AppLogo(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.welcomeTitle,
                style: AppTypography.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.welcomeSubtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              _FeatureItem(
                iconAsset: 'assets/icons/target.svg',
                label: l10n.welcomeFeature1,
              ),
              const SizedBox(height: AppSpacing.lg),
              _FeatureItem(
                iconAsset: 'assets/icons/trending_up.svg',
                label: l10n.welcomeFeature2,
              ),
              const SizedBox(height: AppSpacing.lg),
              _FeatureItem(
                iconAsset: 'assets/icons/calendar.svg',
                label: l10n.welcomeFeature3,
              ),
              const Spacer(flex: 3),
              AppButton(
                label: l10n.createAccount,
                onPressed: () => context.push(RouteNames.signUp),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: l10n.logIn,
                onPressed: () => context.push(RouteNames.logIn),
                variant: AppButtonVariant.secondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              _LanguageSwitcher(
                selected: selectedLanguage,
                onChanged: (lang) {
                  final newLocale = lang == 'EN'
                      ? const Locale('en')
                      : const Locale('es');
                  ref.read(localeProvider.notifier).setLocale(newLocale);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.accentPrimary,
        borderRadius: AppRadius.borderLg,
      ),
      padding: const EdgeInsets.all(16),
      child: SvgPicture.asset(
        'assets/icons/zap.svg',
        colorFilter: const ColorFilter.mode(
          AppColors.backgroundPrimary,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const _languages = ['EN', 'ES'];

  @override
  Widget build(BuildContext context) {
    final next = selected == 'EN' ? 'ES' : 'EN';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(next),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
            ),
            child: const Icon(
              Icons.language,
              size: 18,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
              ),
              padding: const EdgeInsets.all(4),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    alignment: selected == 'EN'
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      heightFactor: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.info,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: _languages.map((lang) {
                      final isActive = lang == selected;
                      return Expanded(
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: isActive
                                  ? AppColors.backgroundPrimary
                                  : AppColors.textDisabled,
                            ),
                            child: Text(lang),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentMuted,
            borderRadius: AppRadius.borderMd,
          ),
          padding: const EdgeInsets.all(10),
          child: SvgPicture.asset(
            iconAsset,
            colorFilter: const ColorFilter.mode(
              AppColors.accentPrimary,
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.base),
        Expanded(
          child: Text(label, style: AppTypography.bodyLarge),
        ),
      ],
    );
  }
}
