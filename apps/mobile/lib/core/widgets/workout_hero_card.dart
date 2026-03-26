import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

class WorkoutHeroCard extends StatelessWidget {
  const WorkoutHeroCard({
    super.key,
    required this.sessionType,
    required this.sessionName,
    required this.duration,
    required this.distance,
    this.targetGuidance,
    this.sessionTypeIconAsset,
    this.onViewDetails,
    this.onStart,
  });

  final String sessionType;
  final String sessionName;
  final String duration;
  final String distance;
  final String? targetGuidance;
  final String? sessionTypeIconAsset;
  final VoidCallback? onViewDetails;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentMuted,
                  borderRadius: AppRadius.borderMd,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    sessionTypeIconAsset ?? 'assets/icons/zap.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                        AppColors.accentPrimary, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sessionType, style: AppTypography.caption),
                  Text(sessionName, style: AppTypography.titleMedium),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'Duration',
                  value: duration,
                  iconAsset: 'assets/icons/clock.svg',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCell(
                  label: 'Distance',
                  value: distance,
                  iconAsset: 'assets/icons/distance.svg',
                ),
              ),
            ],
          ),
          if (targetGuidance != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: AppRadius.borderMd,
              ),
              child: Text(
                targetGuidance!,
                style: AppTypography.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'View Details',
                  onPressed: onViewDetails,
                  variant: AppButtonVariant.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Start',
                  onPressed: onStart,
                  variant: AppButtonVariant.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.iconAsset,
  });

  final String label;
  final String value;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.borderMd,
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
                AppColors.accentPrimary, BlendMode.srcIn),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.caption),
              Text(value, style: AppTypography.labelLarge),
            ],
          ),
        ],
      ),
    );
  }
}
