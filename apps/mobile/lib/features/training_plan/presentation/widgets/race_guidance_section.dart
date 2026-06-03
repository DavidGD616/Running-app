import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/race_guidance.dart';

class RaceGuidanceSection extends StatelessWidget {
  const RaceGuidanceSection({
    super.key,
    required this.guidance,
    required this.l10n,
  });

  final RaceGuidance guidance;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.backgroundCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: SectionLabel(label: l10n.planGuidanceRaceGuidanceTitle),
          ),
          const Divider(height: 1, color: AppColors.backgroundCard),
          _GuidanceField(
            label: l10n.planGuidanceRaceDayExecutionLabel,
            value: guidance.raceDayExecution,
            l10n: l10n,
          ),
          if (guidance.warmup != null) ...[
            const Divider(height: 1, color: AppColors.backgroundCard),
            _GuidanceField(
              label: l10n.planGuidanceWarmupLabel,
              value: guidance.warmup!,
              l10n: l10n,
            ),
          ],
          if (guidance.primaryTarget != null) ...[
            const Divider(height: 1, color: AppColors.backgroundCard),
            _GuidanceField(
              label: l10n.planGuidancePrimaryTargetLabel,
              value: _formatDuration(guidance.primaryTarget!, l10n),
              l10n: l10n,
            ),
          ],
          if (guidance.stretchTarget != null) ...[
            const Divider(height: 1, color: AppColors.backgroundCard),
            _GuidanceField(
              label: l10n.planGuidanceStretchTargetLabel,
              value: _formatDuration(guidance.stretchTarget!, l10n),
              l10n: l10n,
            ),
          ],
          if (guidance.splitPlan != null) ...[
            const Divider(height: 1, color: AppColors.backgroundCard),
            _GuidanceField(
              label: l10n.planGuidanceSplitPlanLabel,
              value: guidance.splitPlan!,
              l10n: l10n,
            ),
          ],
          if (guidance.whenToPress != null) ...[
            const Divider(height: 1, color: AppColors.backgroundCard),
            _GuidanceField(
              label: l10n.planGuidanceWhenToPressLabel,
              value: guidance.whenToPress!,
              l10n: l10n,
            ),
          ],
          if (guidance.whatToAvoid != null) ...[
            const Divider(height: 1, color: AppColors.backgroundCard),
            _GuidanceField(
              label: l10n.planGuidanceWhatToAvoidLabel,
              value: guidance.whatToAvoid!,
              l10n: l10n,
            ),
          ],
          if (guidance.coachingNotes != null) ...[
            const Divider(height: 1, color: AppColors.backgroundCard),
            _GuidanceField(
              label: l10n.planGuidanceCoachingNotesLabel,
              value: guidance.coachingNotes!,
              l10n: l10n,
            ),
          ],
          if (guidance.sleepNotes != null) ...[
            const Divider(height: 1, color: AppColors.backgroundCard),
            _GuidanceField(
              label: l10n.planGuidanceSleepNotesLabel,
              value: guidance.sleepNotes!,
              l10n: l10n,
            ),
          ],
          if (guidance.fuelingNotes != null) ...[
            const Divider(height: 1, color: AppColors.backgroundCard),
            _GuidanceField(
              label: l10n.planGuidanceFuelingNotesLabel,
              value: guidance.fuelingNotes!,
              l10n: l10n,
            ),
          ],
          if (guidance.hydrationNotes != null) ...[
            const Divider(height: 1, color: AppColors.backgroundCard),
            _GuidanceField(
              label: l10n.planGuidanceHydrationNotesLabel,
              value: guidance.hydrationNotes!,
              l10n: l10n,
            ),
          ],
          if (guidance.taperReminders != null) ...[
            const Divider(height: 1, color: AppColors.backgroundCard),
            _GuidanceField(
              label: l10n.planGuidanceTaperRemindersLabel,
              value: guidance.taperReminders!,
              l10n: l10n,
            ),
          ],
          if (guidance.weatherCourseNotes != null) ...[
            const Divider(height: 1, color: AppColors.backgroundCard),
            _GuidanceField(
              label: l10n.planGuidanceWeatherCourseNotesLabel,
              value: guidance.weatherCourseNotes!,
              l10n: l10n,
            ),
          ],
        ],
      ),
    );
  }
}

class _GuidanceField extends StatelessWidget {
  const _GuidanceField({
    required this.label,
    required this.value,
    required this.l10n,
  });

  final String label;
  final String value;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.md,
        AppSpacing.base,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration, AppLocalizations l10n) {
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes % 60;
    if (minutes == 0) {
      return '${duration.inHours}${l10n.progressHourUnit}';
    }
    return '${duration.inHours}${l10n.progressHourUnit} $minutes${l10n.progressMinuteUnit}';
  }

  return '${duration.inMinutes}${l10n.progressMinuteUnit}';
}
