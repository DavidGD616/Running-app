import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class UpNextRowCard extends StatelessWidget {
  const UpNextRowCard({
    super.key,
    required this.sessionName,
    required this.dayLabel,
    required this.duration,
    required this.effortLabel,
    this.iconAsset,
    this.onTap,
  });

  final String sessionName;
  final String dayLabel;
  final String duration;
  final String effortLabel;
  final String? iconAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentMuted,
                borderRadius: AppRadius.borderMd,
              ),
              child: Center(
                child: SvgPicture.asset(
                  iconAsset ?? 'assets/icons/zap.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                      AppColors.accentPrimary, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sessionName, style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$dayLabel  ·  $duration  ·  $effortLabel',
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ),
            Opacity(
              opacity: 0.40,
              child: SvgPicture.asset(
                'assets/icons/chevron_right.svg',
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                    AppColors.textPrimary, BlendMode.srcIn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
