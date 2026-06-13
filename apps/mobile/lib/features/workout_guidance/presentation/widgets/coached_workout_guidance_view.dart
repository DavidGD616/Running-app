import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../workout_guidance_presenter.dart';

class CoachedWorkoutGuidanceView extends StatelessWidget {
  const CoachedWorkoutGuidanceView({
    super.key,
    required this.guidance,
    this.compact = false,
  });

  final WorkoutGuidance guidance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: l10n.workoutGuidanceTodaysPrescription,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: guidance.chips
                    .map((chip) => _MetricChip(chip: chip))
                    .toList(growable: false),
              ),
              const SizedBox(height: AppSpacing.lg),
              _PhaseRail(phases: guidance.phases),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _Section(
          title: l10n.workoutGuidancePaceEffort,
          child: Column(
            children: guidance.effortGuideRows
                .map((row) => _EffortGuideCard(entry: row))
                .toList(growable: false),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.xl),
          _Section(
            title: l10n.workoutGuidanceCoachCues,
            child: _CoachNotesCard(
              howLabel: l10n.workoutGuidanceHowToRunIt,
              howValue: guidance.howToRunIt,
              whyLabel: l10n.workoutGuidanceWhyItMatters,
              whyValue: guidance.whyItMatters,
            ),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.titleLarge),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.chip});

  final WorkoutGuidanceChip chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 16, color: AppColors.accentPrimary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            chip.label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            chip.value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseRail extends StatelessWidget {
  const _PhaseRail({required this.phases});

  final List<WorkoutGuidancePhase> phases;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: phases
          .map(
            (phase) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PhaseCard(phase: phase),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.phase});

  final WorkoutGuidancePhase phase;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: AppColors.accentPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        phase.title,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      phase.measure,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  phase.headline,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final detail in phase.details) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EffortGuideCard extends StatelessWidget {
  const _EffortGuideCard({required this.entry});

  final WorkoutGuidanceEffortGuideEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            entry.cue,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (entry.pace != null || entry.feel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (entry.pace != null)
                  _SupportPill(icon: Icons.speed_outlined, label: entry.pace!),
                if (entry.feel != null)
                  _SupportPill(
                    icon: Icons.stacked_line_chart_outlined,
                    label: entry.feel!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SupportPill extends StatelessWidget {
  const _SupportPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachNotesCard extends StatelessWidget {
  const _CoachNotesCard({
    required this.howLabel,
    required this.howValue,
    required this.whyLabel,
    required this.whyValue,
  });

  final String howLabel;
  final String howValue;
  final String whyLabel;
  final String whyValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoachNoteText(label: howLabel, value: howValue),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.borderDefault),
          const SizedBox(height: AppSpacing.md),
          _CoachNoteText(label: whyLabel, value: whyValue),
        ],
      ),
    );
  }
}

class _CoachNoteText extends StatelessWidget {
  const _CoachNoteText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
