import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Selectable choice card used in onboarding screens.
class AppChoiceCard extends StatelessWidget {
  const AppChoiceCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentMuted : AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.borderDefault,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle!, style: AppTypography.bodyMedium),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.accentPrimary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Session card showing a training session (day, type, duration).
class AppSessionCard extends StatelessWidget {
  const AppSessionCard({
    super.key,
    required this.day,
    required this.sessionType,
    required this.duration,
    this.distance,
    this.isCompleted = false,
    this.onTap,
  });

  final String day;
  final String sessionType;
  final String duration;
  final String? distance;
  final bool isCompleted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.success : AppColors.accentPrimary,
                borderRadius: AppRadius.borderFull,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day, style: AppTypography.caption),
                  const SizedBox(height: AppSpacing.xs),
                  Text(sessionType, style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Text(duration, style: AppTypography.bodyMedium),
                      if (distance != null) ...[
                        Text('  ·  ', style: AppTypography.bodyMedium),
                        Text(distance!, style: AppTypography.bodyMedium),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isCompleted)
              const Icon(Icons.check_circle, color: AppColors.success, size: 20)
            else
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
