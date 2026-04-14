import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/router/route_names.dart';
import '../../../../l10n/app_localizations.dart';
import '../run_flow_context.dart';

class PreRunScreen extends StatefulWidget {
  const PreRunScreen({super.key, this.args});

  final PreRunArgs? args;

  @override
  State<PreRunScreen> createState() => _PreRunScreenState();
}

class _PreRunScreenState extends State<PreRunScreen> {
  PreRunLegCondition? _legs;
  PreRunPainLevel? _pain;
  PreRunSleepLevel? _sleep;
  PreRunReadinessLevel? _readiness;

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

                    _QuestionSection(
                      label: l10n.preRunLegsQuestion,
                      child: Row(
                        children: [
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunFresh,
                              isSelected: _legs == PreRunLegCondition.fresh,
                              onTap: () => setState(
                                () => _legs = PreRunLegCondition.fresh,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunNormal,
                              isSelected: _legs == PreRunLegCondition.normal,
                              onTap: () => setState(
                                () => _legs = PreRunLegCondition.normal,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunHeavy,
                              isSelected: _legs == PreRunLegCondition.heavy,
                              onTap: () => setState(
                                () => _legs = PreRunLegCondition.heavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    _QuestionSection(
                      label: l10n.preRunPainQuestion,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _OptionButton(
                                  label: l10n.preRunNone,
                                  isSelected: _pain == PreRunPainLevel.none,
                                  onTap: () => setState(
                                    () => _pain = PreRunPainLevel.none,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _OptionButton(
                                  label: l10n.preRunMildDiscomfort,
                                  isSelected: _pain == PreRunPainLevel.mild,
                                  onTap: () => setState(
                                    () => _pain = PreRunPainLevel.mild,
                                  ),
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
                                  isSelected: _pain == PreRunPainLevel.moderate,
                                  onTap: () => setState(
                                    () => _pain = PreRunPainLevel.moderate,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _OptionButton(
                                  label: l10n.preRunSharpPain,
                                  isSelected: _pain == PreRunPainLevel.sharp,
                                  onTap: () => setState(
                                    () => _pain = PreRunPainLevel.sharp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    _QuestionSection(
                      label: l10n.preRunSleepQuestion,
                      child: Row(
                        children: [
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunGreat,
                              isSelected: _sleep == PreRunSleepLevel.great,
                              onTap: () => setState(
                                () => _sleep = PreRunSleepLevel.great,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunOkay,
                              isSelected: _sleep == PreRunSleepLevel.okay,
                              onTap: () => setState(
                                () => _sleep = PreRunSleepLevel.okay,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunPoor,
                              isSelected: _sleep == PreRunSleepLevel.poor,
                              onTap: () => setState(
                                () => _sleep = PreRunSleepLevel.poor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    _QuestionSection(
                      label: l10n.preRunReadinessQuestion,
                      child: Row(
                        children: [
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunLetsGo,
                              isSelected:
                                  _readiness == PreRunReadinessLevel.letsGo,
                              onTap: () => setState(
                                () => _readiness = PreRunReadinessLevel.letsGo,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _OptionButton(
                              label: l10n.preRunNotFullyReady,
                              isSelected:
                                  _readiness ==
                                  PreRunReadinessLevel.notFullyReady,
                              onTap: () => setState(
                                () => _readiness =
                                    PreRunReadinessLevel.notFullyReady,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _ContinueButton(
              label: l10n.preRunContinue,
              onTap: () => context.push(
                RouteNames.activeRun,
                extra: ActiveRunArgs(
                  session: widget.args?.session,
                  checkIn: PreRunCheckIn(
                    legs: _legs,
                    pain: _pain,
                    sleep: _sleep,
                    readiness: _readiness,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.titleMedium.copyWith(
              color: isSelected
                  ? AppColors.accentPrimary
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

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
