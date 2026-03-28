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
import '../../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;

    final motivationOptions = [
      l10n.motivationPersonalChallenge,
      l10n.motivationHealth,
      l10n.motivationWeightLoss,
      l10n.motivationImprovePerformance,
      l10n.motivationRaceFriends,
      l10n.motivationDiscipline,
      l10n.motivationOther,
    ];

    final barrierOptions = [
      l10n.barrierTime,
      l10n.barrierMotivation,
      l10n.barrierFatigue,
      l10n.barrierStress,
      l10n.barrierPain,
      l10n.barrierBoredom,
      l10n.barrierDontKnowHow,
      l10n.barrierOther,
    ];

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
                        l10n.onboardingStep(8, 9),
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
                    Text(l10n.motivationTitle,
                        style: AppTypography.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.motivationSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── 1. Why are you doing this? ────────────────────────────
                    Text(l10n.whyDoingThisLabel,
                        style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.selectAllThatApply,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: motivationOptions
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
                      Text(l10n.barriersLabel,
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.selectAllThatApply,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: barrierOptions
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
                      Text(l10n.confidenceLabel,
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
                      Text(l10n.coachingToneLabel,
                          style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.md),
                      _SelectCard(
                        label: l10n.toneSimple,
                        subtitle: l10n.toneSimpleSub,
                        isSelected: _coachingTone == 'Simple and direct',
                        onTap: () => setState(
                            () => _coachingTone = 'Simple and direct'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectCard(
                        label: l10n.toneEncouraging,
                        subtitle: l10n.toneEncouragingSub,
                        isSelected: _coachingTone == 'Encouraging',
                        onTap: () =>
                            setState(() => _coachingTone = 'Encouraging'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectCard(
                        label: l10n.toneDetailed,
                        subtitle: l10n.toneDetailedSub,
                        isSelected: _coachingTone == 'Detailed and data-driven',
                        onTap: () => setState(
                            () => _coachingTone = 'Detailed and data-driven'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectCard(
                        label: l10n.toneStrict,
                        subtitle: l10n.toneStrictSub,
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
                label: l10n.continueButton,
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
