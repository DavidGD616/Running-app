import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class TimelinePhase {
  const TimelinePhase({
    required this.label,
    required this.duration,
    this.paceRange,
    this.notes,
    this.iconAsset,
  });

  final String label;
  final String duration;
  final String? paceRange;
  final String? notes;
  final String? iconAsset;
}

class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.phases,
  });

  final List<TimelinePhase> phases;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(phases.length, (i) => _PhaseRow(
        phase: phases[i],
        isLast: i == phases.length - 1,
      )),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({required this.phase, required this.isLast});

  final TimelinePhase phase;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentMuted,
                  ),
                  child: phase.iconAsset != null
                      ? Center(
                          child: SvgPicture.asset(
                            phase.iconAsset!,
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                                AppColors.accentPrimary, BlendMode.srcIn),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.borderDefault,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppSpacing.base,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(phase.label, style: AppTypography.titleMedium),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: AppRadius.borderFull,
                        ),
                        child: Text(phase.duration, style: AppTypography.caption),
                      ),
                    ],
                  ),
                  if (phase.paceRange != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(phase.paceRange!, style: AppTypography.bodyMedium),
                  ],
                  if (phase.notes != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: AppRadius.borderMd,
                      ),
                      child: Text(phase.notes!, style: AppTypography.bodyMedium),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
