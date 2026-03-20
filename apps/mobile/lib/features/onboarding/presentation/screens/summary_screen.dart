import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top nav ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.xs, AppSpacing.screen, 0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/chevron_left.svg',
                              width: 24,
                              height: 24,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textPrimary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '9 / 9',
                        style: AppTypography.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: AppProgressBar(current: 9, total: 9),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen, AppSpacing.lg,
                  AppSpacing.screen, AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Plan Summary',
                        style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Review your selections before we build your plan.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Summary cards ─────────────────────────────────────────
                    _SummaryCard(
                      icon: 'assets/icons/target.svg',
                      category: 'Goal Race',
                      value: 'Half Marathon',
                      detail: 'April 12, 2026 · Finish feeling strong',
                      onEdit: () {},
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/trending_up.svg',
                      category: 'Current Level',
                      value: 'Intermediate',
                      detail: '3 days/wk · 11–15 miles weekly',
                      onEdit: () {},
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/calendar.svg',
                      category: 'Schedule',
                      value: '4 days per week',
                      detail: 'Long run Saturday · Morning · 45 min weekdays',
                      onEdit: () {},
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/heart.svg',
                      category: 'Health',
                      value: 'No current pain',
                      detail: 'Balanced plan preference',
                      onEdit: () {},
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/training.svg',
                      category: 'Training',
                      value: 'Pace-based guidance',
                      detail: 'Speed workouts · Strength 2×/wk · Road · Some hills',
                      onEdit: () {},
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/watch.svg',
                      category: 'Device',
                      value: 'Garmin connected',
                      detail: 'All data · HR zones · Auto-adjust',
                      onEdit: () {},
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/moon.svg',
                      category: 'Recovery',
                      value: '7–8h sleep',
                      detail: 'Desk job · Moderate stress · Usually fresh',
                      onEdit: () {},
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(
                      icon: 'assets/icons/motivation.svg',
                      category: 'Motivation',
                      value: 'Personal challenge, Health',
                      detail: 'Encouraging tone · Confidence 7/10',
                      onEdit: () {},
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Ready message ─────────────────────────────────────────
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/circle_check.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                            AppColors.accentPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Everything looks good. Ready to build your plan!',
                            style: AppTypography.bodyMedium.copyWith(
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Buttons ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, AppSpacing.sm,
                AppSpacing.screen, AppSpacing.xl,
              ),
              child: Column(
                children: [
                  AppButton(
                    label: 'Build My Plan',
                    onPressed: () {},
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Edit Answers',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.go('/onboarding/goal'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.category,
    required this.value,
    required this.detail,
    required this.onEdit,
  });

  final String icon;
  final String category;
  final String value;
  final String detail;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base, AppSpacing.base, 0, AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container
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

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Edit button
          GestureDetector(
            onTap: onEdit,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/edit.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

