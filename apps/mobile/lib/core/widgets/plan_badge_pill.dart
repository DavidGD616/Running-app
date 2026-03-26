import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class PlanBadgePill extends StatelessWidget {
  const PlanBadgePill({
    super.key,
    required this.planName,
    this.weekInfo,
  });

  final String planName;
  final String? weekInfo;

  String get _label => weekInfo != null ? '$planName · $weekInfo' : planName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentMuted,
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _label,
            style: AppTypography.caption.copyWith(
              color: AppColors.accentPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
