import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/widgets/app_slider.dart';
import '../onboarding_provider.dart';

class MotivationScreen extends ConsumerStatefulWidget {
  const MotivationScreen({super.key});

  @override
  ConsumerState<MotivationScreen> createState() => _MotivationScreenState();
}

class _MotivationScreenState extends ConsumerState<MotivationScreen> {
  final Set<String> _motivations = {};
  final Set<String> _barriers = {};
  int _confidence = 5;
  String? _coachingTone;

  final _scrollController = ScrollController();

  bool get _isComplete =>
      _motivations.isNotEmpty &&
      _barriers.isNotEmpty &&
      _coachingTone != null;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  void _toggleMotivation(String val) {
    setState(() {
      if (_motivations.contains(val)) {
        _motivations.remove(val);
      } else {
        _motivations.add(val);
      }
      // reset downstream if motivations become empty
      if (_motivations.isEmpty) {
        _barriers.clear();
        _coachingTone = null;
      }
    });
    if (_motivations.isNotEmpty) _scrollToBottom();
  }

  void _toggleBarrier(String val) {
    setState(() {
      if (_barriers.contains(val)) {
        _barriers.remove(val);
      } else {
        _barriers.add(val);
      }
      if (_barriers.isEmpty) {
        _coachingTone = null;
      }
    });
    if (_barriers.isNotEmpty) _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
                        '8 / 9',
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
                    child: AppProgressBar(current: 8, total: 9),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen, AppSpacing.lg,
                  AppSpacing.screen, AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Motivation & Adherence',
                        style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Help us understand what drives you and what might get in the way.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── 1. Why are you doing this? ────────────────────────────
                    Text('Why are you doing this?',
                        style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Select all that apply',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        'Personal challenge',
                        'Health',
                        'Weight loss',
                        'Improve performance',
                        'Race with friends/family',
                        'Build discipline',
                        'Other',
                      ]
                          .map((label) => _Chip(
                                label: label,
                                isSelected: _motivations.contains(label),
                                onTap: () => _toggleMotivation(label),
                              ))
                          .toList(),
                    ),

                    // ── 2. What gets in the way of consistency? ───────────────
                    if (_motivations.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('What gets in the way of consistency?',
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Select all that apply',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          'Time',
                          'Motivation',
                          'Fatigue',
                          'Stress',
                          'Pain or soreness',
                          'Boredom',
                          "I don't know how to train",
                          'Other',
                        ]
                            .map((label) => _Chip(
                                  label: label,
                                  isSelected: _barriers.contains(label),
                                  onTap: () => _toggleBarrier(label),
                                ))
                            .toList(),
                      ),
                    ],

                    // ── 3. Confidence slider ──────────────────────────────────
                    if (_barriers.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text("Confidence you'll stick with the plan",
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      AppSlider(
                        value: _confidence,
                        min: 1,
                        max: 10,
                        onChanged: (val) => setState(() => _confidence = val),
                      ),
                    ],

                    // ── 4. Preferred coaching tone ────────────────────────────
                    if (_barriers.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Preferred coaching tone',
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SelectCard(
                        label: 'Simple and direct',
                        subtitle: 'Straight to the point',
                        isSelected: _coachingTone == 'Simple and direct',
                        onTap: () => setState(
                            () => _coachingTone = 'Simple and direct'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectCard(
                        label: 'Encouraging',
                        subtitle: 'Supportive and positive',
                        isSelected: _coachingTone == 'Encouraging',
                        onTap: () =>
                            setState(() => _coachingTone = 'Encouraging'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectCard(
                        label: 'Detailed and data-driven',
                        subtitle: 'Numbers and explanations',
                        isSelected: _coachingTone == 'Detailed and data-driven',
                        onTap: () => setState(
                            () => _coachingTone = 'Detailed and data-driven'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectCard(
                        label: 'Strict and performance-focused',
                        subtitle: 'Push me hard',
                        isSelected:
                            _coachingTone == 'Strict and performance-focused',
                        onTap: () => setState(() =>
                            _coachingTone = 'Strict and performance-focused'),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Continue button ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, AppSpacing.sm,
                AppSpacing.screen, AppSpacing.xl,
              ),
              child: AppButton(
                label: 'Continue',
                onPressed: _isComplete
                    ? () {
                        ref.read(onboardingProvider.notifier).setMotivation(
                              motivations: _motivations.toList(),
                              barriers: _barriers.toList(),
                              confidence: _confidence,
                              coachingTone: _coachingTone!,
                            );
                        context.push(RouteNames.summary);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full-width select card ───────────────────────────────────────────────────

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.label,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.base,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
        ),
        child: subtitle != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// ─── Pill chip ────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: IntrinsicWidth(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentPrimary
                  : AppColors.borderDefault,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.backgroundPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
