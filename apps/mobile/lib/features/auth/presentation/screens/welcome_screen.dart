import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                'Welcome to RunFlow',
                style: AppTypography.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your personal running coach. Build a plan tailored to your goals, fitness level, and schedule.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              const _FeatureItem(
                iconAsset: 'assets/icons/target.svg',
                label: 'Personalized training plans',
              ),
              const SizedBox(height: AppSpacing.lg),
              const _FeatureItem(
                iconAsset: 'assets/icons/trending_up.svg',
                label: 'AI-powered progression',
              ),
              const SizedBox(height: AppSpacing.lg),
              const _FeatureItem(
                iconAsset: 'assets/icons/calendar.svg',
                label: 'Flexible scheduling',
              ),
              const Spacer(flex: 3),
              AppButton(
                label: 'Create Account',
                onPressed: () {},
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Log In',
                onPressed: () {},
                variant: AppButtonVariant.secondary,
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
        Text(label, style: AppTypography.bodyLarge),
      ],
    );
  }
}
