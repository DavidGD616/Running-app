import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class StatColumn extends StatelessWidget {
  const StatColumn({
    super.key,
    required this.label,
    required this.value,
    this.hasDivider = false,
  });

  final String label;
  final String value;
  final bool hasDivider;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.textDisabled,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return Expanded(
      child: hasDivider
          ? DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.backgroundCard),
                ),
              ),
              child: content,
            )
          : content,
    );
  }
}
