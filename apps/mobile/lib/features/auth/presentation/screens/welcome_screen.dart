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
import '../auth_notifier.dart';
import '../../../../features/localization/presentation/locale_provider.dart';
import '../../../../l10n/app_localizations.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  Future<void> _continueWithGoogle(AppLocalizations l10n) async {
    final feedback = await ref
        .read(authNotifierProvider.notifier)
        .signInWithGoogle(l10n: l10n);

    if (!mounted || feedback == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(feedback.message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    // Derive selected language from the locale provider — no local state needed
    final locale = ref.watch(localeProvider).value ?? const Locale('en');
    final selectedLanguage = locale.languageCode.toUpperCase(); // 'EN' or 'ES'

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
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
                      onPressed: isLoading
                          ? null
                          : () => context.push(RouteNames.signUp),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: l10n.logIn,
                      onPressed: isLoading
                          ? null
                          : () => context.push(RouteNames.logIn),
                      variant: AppButtonVariant.secondary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _GoogleSignInButton(
                      label: isLoading
                          ? l10n.authLoadingGoogleSignIn
                          : l10n.continueWithGoogle,
                      isLoading: isLoading,
                      onPressed: isLoading
                          ? null
                          : () => _continueWithGoogle(l10n),
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
    return SvgPicture.asset(
      'assets/logos/striviq_logo.svg',
      width: 210,
      height: 52,
      fit: BoxFit.contain,
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

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          side: const BorderSide(color: Color(0xFFDADCE0), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderMd,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F1F1F)),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/google.svg',
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F1F1F),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
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
        Expanded(child: Text(label, style: AppTypography.bodyLarge)),
      ],
    );
  }
}
