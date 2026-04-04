import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum SettingsRowVariant {
  chevron,
  badge,
  toggleOn,
  toggleOff,
  value,
  selection,
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    required this.iconAsset,
    this.iconColor = AppColors.textSecondary,
    this.variant = SettingsRowVariant.chevron,
    this.badgeLabel,
    this.valueLabel,
    this.onTap,
    this.onToggle,
    this.isDestructive = false,
    this.isSelected = false,
  });

  final String label;
  final String iconAsset;
  final Color iconColor;
  final SettingsRowVariant variant;
  final String? badgeLabel;
  final String? valueLabel;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;
  final bool isDestructive;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          variant == SettingsRowVariant.toggleOn ||
              variant == SettingsRowVariant.toggleOff
          ? null
          : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppColors.error.withValues(alpha: 0.08)
                    : iconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SvgPicture.asset(
                  iconAsset,
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    isDestructive ? AppColors.error : iconColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyLarge.copyWith(
                  color: isDestructive
                      ? AppColors.error
                      : AppColors.textPrimary,
                ),
              ),
            ),
            _trailing(),
          ],
        ),
      ),
    );
  }

  Widget _trailing() {
    switch (variant) {
      case SettingsRowVariant.chevron:
        return SvgPicture.asset(
          'assets/icons/chevron_right.svg',
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(
            AppColors.textSecondary,
            BlendMode.srcIn,
          ),
        );
      case SettingsRowVariant.badge:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusBadgeInline(label: badgeLabel ?? ''),
            const SizedBox(width: AppSpacing.sm),
            SvgPicture.asset(
              'assets/icons/chevron_right.svg',
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                AppColors.textSecondary,
                BlendMode.srcIn,
              ),
            ),
          ],
        );
      case SettingsRowVariant.toggleOn:
        return Switch(
          value: true,
          onChanged: onToggle,
          activeThumbColor: AppColors.accentPrimary,
        );
      case SettingsRowVariant.toggleOff:
        return Switch(
          value: false,
          onChanged: onToggle,
          activeThumbColor: AppColors.accentPrimary,
        );
      case SettingsRowVariant.value:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              valueLabel ?? '',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            SvgPicture.asset(
              'assets/icons/chevron_right.svg',
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                AppColors.textSecondary,
                BlendMode.srcIn,
              ),
            ),
          ],
        );
      case SettingsRowVariant.selection:
        return Opacity(
          opacity: isSelected ? 1 : 0,
          child: SvgPicture.asset(
            'assets/icons/circle_check.svg',
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(
              AppColors.accentPrimary,
              BlendMode.srcIn,
            ),
          ),
        );
    }
  }
}

class _StatusBadgeInline extends StatelessWidget {
  const _StatusBadgeInline({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/circle_check.svg',
            width: 13,
            height: 13,
            colorFilter: const ColorFilter.mode(
              AppColors.accentPrimary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone destructive row for actions like "Log Out".
class DestructiveRow extends StatelessWidget {
  const DestructiveRow({
    super.key,
    required this.label,
    required this.iconAsset,
    this.onTap,
  });

  final String label;
  final String iconAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.error,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.labelLarge.copyWith(color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}
