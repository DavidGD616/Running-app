import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_progress_bar.dart';

class OnboardingIntroScreen extends StatelessWidget {
  const OnboardingIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          child: Column(
            children: [
              const AppProgressBar(current: 1, total: 9),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.accentMuted,
                          borderRadius: AppRadius.borderXl,
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/zap.svg',
                            width: 40,
                            height: 40,
                            colorFilter: const ColorFilter.mode(
                              AppColors.accentPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      // Title
                      Text(
                        "Let's build your plan",
                        style: AppTypography.textTheme.headlineMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Subtitle
                      Text(
                        'Answer a few questions so we can create a training plan personalized to you. It takes about 3 minutes.',
                        style: AppTypography.textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      // Feature items
                      _FeatureItem(
                        icon: 'assets/icons/circle_check.svg',
                        label: 'Your race goal and timeline',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _FeatureItem(
                        icon: 'assets/icons/sparkles.svg',
                        label: 'Fitness level and experience',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _FeatureItem(
                        icon: 'assets/icons/clock.svg',
                        label: 'Schedule and preferences',
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom CTA
              AppButton(
                label: "Let's Go",
                onPressed: () => context.push(RouteNames.goal),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                '9 short sections · You can edit answers later',
                style: AppTypography.textTheme.labelSmall?.copyWith(
                  color: AppColors.textDisabled,
                  letterSpacing: 0.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.accentMuted,
            borderRadius: AppRadius.borderMd,
          ),
          child: Center(
            child: SvgPicture.asset(
              icon,
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.accentPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.base),
        Text(
          label,
          style: AppTypography.textTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
