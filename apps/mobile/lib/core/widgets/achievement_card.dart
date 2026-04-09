import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AchievementCardVariant { gold, green, locked }

class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.title,
    required this.description,
    this.dateOrProgress,
    this.variant = AchievementCardVariant.locked,
    this.iconAsset,
  });

  final String title;
  final String description;
  final String? dateOrProgress;
  final AchievementCardVariant variant;
  final String? iconAsset;

  Color get _accentColor {
    switch (variant) {
      case AchievementCardVariant.gold:
        return AppColors.warning;
      case AchievementCardVariant.green:
        return AppColors.success;
      case AchievementCardVariant.locked:
        return AppColors.textDisabled;
    }
  }

  bool get _isLocked => variant == AchievementCardVariant.locked;

  String get _iconPath {
    if (_isLocked) return 'assets/icons/medal.svg';
    return iconAsset ?? 'assets/icons/trophy.svg';
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _isLocked ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: _isLocked
                ? AppColors.borderDefault
                : _accentColor.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.15),
                borderRadius: AppRadius.borderMd,
              ),
              child: Center(
                child: SvgPicture.asset(
                  _iconPath,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(_accentColor, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(description, style: AppTypography.bodyMedium),
                  if (dateOrProgress != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      dateOrProgress!,
                      style: AppTypography.caption.copyWith(
                        color: _isLocked
                            ? AppColors.textDisabled
                            : _accentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
