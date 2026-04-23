import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_header_bar.dart';
import '../../../../core/router/route_names.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../active_run/presentation/active_run_session_provider.dart';
import '../../../training_plan/domain/models/workout_step.dart';
import '../run_flow_context.dart';

class PreRunScreen extends ConsumerStatefulWidget {
  const PreRunScreen({super.key, this.args});

  final PreRunArgs? args;

  @override
  ConsumerState<PreRunScreen> createState() => _PreRunScreenState();
}

class _PreRunScreenState extends ConsumerState<PreRunScreen> {
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

                    if (widget.args?.session.workoutSteps.isNotEmpty ??
                        false) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _WorkoutPreview(
                        steps: widget.args!.session.workoutSteps,
                        l10n: l10n,
                      ),
                    ],

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
              onTap: () async {
                final session = widget.args?.session;
                final checkIn = PreRunCheckIn(
                  legs: _legs,
                  pain: _pain,
                  sleep: _sleep,
                  readiness: _readiness,
                );
                final router = GoRouter.of(context);
                if (router.routerDelegate.currentConfiguration.uri.path ==
                    RouteNames.activeRun) {
                  return;
                }
                if (session != null) {
                  await ref
                      .read(activeRunSessionProvider.notifier)
                      .save(session, checkIn);
                }
                router.push(
                  RouteNames.activeRun,
                  extra: ActiveRunArgs(session: session, checkIn: checkIn),
                );
              },
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

class _WorkoutPreview extends StatelessWidget {
  const _WorkoutPreview({required this.steps, required this.l10n});

  final List<WorkoutStep> steps;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.preRunWorkoutPreviewTitle.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textDisabled,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._buildPreviewItems(),
        ],
      ),
    );
  }

  List<Widget> _buildPreviewItems() {
    final items = <Widget>[];

    for (final step in steps) {
      if (step.kind == WorkoutStepKind.warmUp) {
        items.add(
          _PreviewItem(
            iconAsset: 'assets/icons/flame.svg',
            label: l10n.preRunWorkoutPreviewWarmUp(_formatStepMeasure(step)),
          ),
        );
      } else if (step.kind == WorkoutStepKind.coolDown) {
        items.add(
          _PreviewItem(
            iconAsset: 'assets/icons/heart_rate.svg',
            label: l10n.preRunWorkoutPreviewCoolDown(_formatStepMeasure(step)),
          ),
        );
      } else if (step.kind == WorkoutStepKind.work) {
        items.add(
          _PreviewItem(
            iconAsset: 'assets/icons/activity.svg',
            label: l10n.preRunWorkoutPreviewMain(_formatStepMeasure(step)),
          ),
        );
      } else if (step.kind == WorkoutStepKind.repeat) {
        final strideStep = _childStep(step, WorkoutStepKind.stride);
        final recoveryStep = _childStep(step, WorkoutStepKind.recovery);
        if (strideStep != null) {
          final reps = step.repetitions ?? 1;
          final seconds = strideStep.duration?.inSeconds ?? 20;
          final recoverySeconds = recoveryStep?.duration?.inSeconds ?? 60;
          items.add(
            _PreviewItem(
              iconAsset: 'assets/icons/zap.svg',
              label: l10n.preRunWorkoutPreviewStrides(
                reps,
                seconds,
                recoverySeconds,
              ),
            ),
          );
          continue;
        }

        final workStep = _childStep(step, WorkoutStepKind.work);
        if (workStep != null) {
          final reps = step.repetitions ?? 1;
          items.add(
            _PreviewItem(
              iconAsset: 'assets/icons/activity.svg',
              label: l10n.preRunWorkoutPreviewRepeat(
                reps,
                _formatStepMeasure(workStep),
                recoveryStep != null
                    ? _formatStepMeasure(recoveryStep)
                    : l10n.preRunWorkoutPreviewOpenDuration,
              ),
            ),
          );
        }
      }
    }

    return items;
  }

  WorkoutStep? _childStep(WorkoutStep parent, WorkoutStepKind kind) {
    for (final child in parent.steps) {
      if (child.kind == kind) return child;
    }
    return null;
  }

  String _formatStepMeasure(WorkoutStep step) {
    if (step.distanceMeters != null && step.distanceMeters! > 0) {
      return l10n.preRunWorkoutPreviewDistanceMeters(step.distanceMeters!);
    }
    return _formatDuration(step.duration);
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return l10n.preRunWorkoutPreviewOpenDuration;
    final seconds = duration.inSeconds;
    if (seconds < 120) {
      return l10n.preRunWorkoutPreviewDurationSeconds(seconds);
    }
    final minutes = duration.inMinutes;
    if (minutes > 0) return l10n.preRunWorkoutPreviewDurationMinutes(minutes);
    return l10n.preRunWorkoutPreviewDurationSeconds(seconds);
  }
}

class _PreviewItem extends StatelessWidget {
  const _PreviewItem({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accentMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: SvgPicture.asset(
                iconAsset,
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                  AppColors.accentPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
