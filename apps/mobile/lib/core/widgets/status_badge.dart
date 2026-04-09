import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum StatusBadgeVariant { connected, disconnected, inactive }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.variant = StatusBadgeVariant.connected,
  });

  final String label;
  final StatusBadgeVariant variant;

  Color get _dotColor {
    switch (variant) {
      case StatusBadgeVariant.connected:
        return AppColors.success;
      case StatusBadgeVariant.disconnected:
        return AppColors.error;
      case StatusBadgeVariant.inactive:
        return AppColors.textDisabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: _dotColor.withValues(alpha: 0.15),
        borderRadius: AppRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _dotColor,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: _dotColor),
          ),
        ],
      ),
    );
  }
}
