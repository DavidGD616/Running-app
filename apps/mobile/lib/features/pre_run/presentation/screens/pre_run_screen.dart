import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/router/route_names.dart';
import '../../../../l10n/app_localizations.dart';

class PreRunScreen extends StatefulWidget {
  const PreRunScreen({super.key});

  @override
  State<PreRunScreen> createState() => _PreRunScreenState();
}

class _PreRunScreenState extends State<PreRunScreen> {
  String? _legs;
  String? _pain;
  String? _sleep;
  String? _readiness;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppDetailHeaderBar(
        title: l10n.preRunTitle,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
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
                    // ── Heading ───────────────────────────────────────────
                    Text(
                      l10n.preRunHeading,
                      style: AppTypography.headlineLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.preRunSubtitle,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Legs ──────────────────────────────────────────────
                    _QuestionSection(
                      label: l10n.preRunLegsQuestion,
                      child: Row(
                        children: [
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunFresh,
                              isSelected: _legs == 'fresh',
                              onTap: () => setState(() => _legs = 'fresh'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunNormal,
                              isSelected: _legs == 'normal',
                              onTap: () => setState(() => _legs = 'normal'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunHeavy,
                              isSelected: _legs == 'heavy',
                              onTap: () => setState(() => _legs = 'heavy'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Pain ──────────────────────────────────────────────
                    _QuestionSection(
                      label: l10n.preRunPainQuestion,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _OptionButton(
                                  label: l10n.preRunNone,
                                  isSelected: _pain == 'none',
                                  onTap: () => setState(() => _pain = 'none'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _OptionButton(
                                  label: l10n.preRunMildDiscomfort,
                                  isSelected: _pain == 'mild',
                                  onTap: () => setState(() => _pain = 'mild'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: _OptionButton(
                                  label: l10n.preRunModeratePain,
                                  isSelected: _pain == 'moderate',
                                  onTap: () => setState(() => _pain = 'moderate'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _OptionButton(
                                  label: l10n.preRunSharpPain,
                                  isSelected: _pain == 'sharp',
                                  onTap: () => setState(() => _pain = 'sharp'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Sleep ─────────────────────────────────────────────
                    _QuestionSection(
                      label: l10n.preRunSleepQuestion,
                      child: Row(
                        children: [
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunGreat,
                              isSelected: _sleep == 'great',
                              onTap: () => setState(() => _sleep = 'great'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunOkay,
                              isSelected: _sleep == 'okay',
                              onTap: () => setState(() => _sleep = 'okay'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunPoor,
                              isSelected: _sleep == 'poor',
                              onTap: () => setState(() => _sleep = 'poor'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Readiness ─────────────────────────────────────────
                    _QuestionSection(
                      label: l10n.preRunReadinessQuestion,
                      child: Row(
                        children: [
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunLetsGo,
                              isSelected: _readiness == 'lets_go',
                              onTap: () => setState(() => _readiness = 'lets_go'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunNotFullyReady,
                              isSelected: _readiness == 'not_ready',
                              onTap: () => setState(() => _readiness = 'not_ready'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Continue button ───────────────────────────────────────────
            _ContinueButton(
              label: l10n.preRunContinue,
              onTap: () => context.push(RouteNames.logRun),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Question section wrapper ──────────────────────────────────────────────────

class _QuestionSection extends StatelessWidget {
  const _QuestionSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

// ── Option button ─────────────────────────────────────────────────────────────

class _OptionButton extends StatelessWidget {
  const _OptionButton({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.titleMedium.copyWith(
              color: isSelected ? AppColors.accentPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Continue button ───────────────────────────────────────────────────────────

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4, 1.0],
          colors: [
            AppColors.backgroundPrimary.withValues(alpha: 0),
            AppColors.backgroundPrimary,
            AppColors.backgroundPrimary,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary,
            borderRadius: AppRadius.borderLg,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.backgroundPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
