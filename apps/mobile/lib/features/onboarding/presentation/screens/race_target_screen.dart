import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/models/runner_profile.dart';
import '../../domain/models/professional_plan_input.dart';
import '../onboarding_provider.dart';

class RaceTargetScreen extends ConsumerStatefulWidget {
  const RaceTargetScreen({super.key});

  @override
  ConsumerState<RaceTargetScreen> createState() => _RaceTargetScreenState();
}

class _RaceTargetScreenState extends ConsumerState<RaceTargetScreen> {
  bool _initialized = false;
  AcceptedRaceTarget? _suggestedTarget;
  Duration? _primaryTarget;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingProvider).value;
    if (draft != null) {
      _initFromDraft(draft);
      _initialized = true;
    }
  }

  void _initFromDraft(RunnerProfileDraft draft) {
    _suggestedTarget = suggestedRaceTargetFromDraft(draft);
    final goalDistance = _goalDistanceKm(draft.goal.race);
    final acceptedTarget = _acceptedTargetForGoal(
      draft.acceptedRaceTarget,
      goalDistance,
    );
    _primaryTarget =
        acceptedTarget?.primaryTime ?? _suggestedTarget?.primaryTime;
    _distanceKm =
        acceptedTarget?.distanceKm ??
        _suggestedTarget?.distanceKm ??
        goalDistance;
  }

  AcceptedRaceTarget? _acceptedTargetForGoal(
    AcceptedRaceTarget? target,
    double? goalDistanceKm,
  ) {
    if (target == null || goalDistanceKm == null) return null;
    const toleranceKm = 0.05;
    return (target.distanceKm - goalDistanceKm).abs() <= toleranceKm
        ? target
        : null;
  }

  double? _goalDistanceKm(RunnerGoalRace? race) {
    return switch (race) {
      RunnerGoalRace.fiveK => 5,
      RunnerGoalRace.tenK => 10,
      RunnerGoalRace.halfMarathon => 21.097,
      RunnerGoalRace.marathon => 42.195,
      RunnerGoalRace.other || null => null,
    };
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _pickTargetTime(AppLocalizations l10n) async {
    await showAppBottomSheet(
      context: context,
      child: _TimePickerSheet(
        title: l10n.raceTargetPrimaryLabel,
        initial: _primaryTarget ?? const Duration(minutes: 50),
        onConfirm: (duration) {
          if (duration <= Duration.zero) return;
          setState(() => _primaryTarget = duration);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _continue(AppLocalizations l10n) {
    final primary = _primaryTarget;
    final distance = _distanceKm;
    if (primary == null || primary <= Duration.zero || distance == null) {
      return;
    }

    ref
        .read(onboardingProvider.notifier)
        .setAcceptedRaceTarget(
          AcceptedRaceTarget(
            distanceKm: distance,
            primaryTime: primary,
            stretchTime: _suggestedTarget?.stretchTime,
            confidence: _suggestedTarget?.confidence,
            evidence: _suggestedTarget?.evidence ?? const [],
          ),
        );
    context.push(RouteNames.schedule);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<RunnerProfileDraft>>(onboardingProvider, (_, next) {
      if (!_initialized && next.hasValue) {
        setState(() {
          _initFromDraft(next.value!);
          _initialized = true;
        });
      }
    });

    final l10n = AppLocalizations.of(context)!;
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasSuggestion = _suggestedTarget != null;
    final canContinue =
        _primaryTarget != null &&
        _primaryTarget! > Duration.zero &&
        _distanceKm != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.screen,
                0,
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
                        l10n.onboardingStep(4, 9),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: AppProgressBar(current: 4, total: 9),
                  ),
                ],
              ),
            ),
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
                      l10n.raceTargetTitle,
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      hasSuggestion
                          ? l10n.raceTargetSuggestedSubtitle
                          : l10n.raceTargetCustomSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (hasSuggestion) ...[
                      _TargetSummaryCard(
                        primary: _suggestedTarget!.primaryTime,
                        stretch: _suggestedTarget!.stretchTime,
                        formatDuration: _formatDuration,
                        l10n: l10n,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    AppPickerField(
                      label: l10n.raceTargetPrimaryLabel,
                      hint: l10n.tapToSetTime,
                      value: _primaryTarget == null
                          ? null
                          : _formatDuration(_primaryTarget!),
                      onTap: () => _pickTargetTime(l10n),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: AppButton(
                label: l10n.continueButton,
                onPressed: canContinue ? () => _continue(l10n) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetSummaryCard extends StatelessWidget {
  const _TargetSummaryCard({
    required this.primary,
    required this.stretch,
    required this.formatDuration,
    required this.l10n,
  });

  final Duration primary;
  final Duration? stretch;
  final String Function(Duration duration) formatDuration;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TargetRow(
            label: l10n.raceTargetSuggestedPrimaryLabel,
            value: formatDuration(primary),
          ),
          if (stretch != null) ...[
            const SizedBox(height: AppSpacing.md),
            _TargetRow(
              label: l10n.raceTargetSuggestedStretchLabel,
              value: formatDuration(stretch!),
            ),
          ],
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({
    required this.title,
    required this.initial,
    required this.onConfirm,
  });

  final String title;
  final Duration initial;
  final ValueChanged<Duration> onConfirm;

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _hours;
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _hours = widget.initial.inHours;
    _minutes = widget.initial.inMinutes.remainder(60);
    _seconds = widget.initial.inSeconds.remainder(60);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedDuration = Duration(
      hours: _hours,
      minutes: _minutes,
      seconds: _seconds,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 180,
          child: Row(
            children: [
              _WheelColumn(
                count: 24,
                initial: _hours,
                label: l10n.timePickerHours,
                onChanged: (v) => setState(() => _hours = v),
              ),
              _WheelColumn(
                count: 60,
                initial: _minutes,
                label: l10n.timePickerMinutes,
                onChanged: (v) => setState(() => _minutes = v),
              ),
              _WheelColumn(
                count: 60,
                initial: _seconds,
                label: l10n.timePickerSeconds,
                onChanged: (v) => setState(() => _seconds = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.confirm,
          onPressed: selectedDuration > Duration.zero
              ? () => widget.onConfirm(selectedDuration)
              : null,
        ),
      ],
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.count,
    required this.initial,
    required this.label,
    required this.onChanged,
  });

  final int count;
  final int initial;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(
                initialItem: initial,
              ),
              itemExtent: 40,
              onSelectedItemChanged: onChanged,
              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                background: AppColors.accentMuted,
              ),
              children: List.generate(
                count,
                (i) => Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
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
