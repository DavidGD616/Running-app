import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(options.length >= 2),
       assert(selectedIndex >= 0),
       assert(selectedIndex < options.length);

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: AppRadius.borderLg,
      ),
      child: Row(
        children: List.generate(options.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentPrimary : Colors.transparent,
                  borderRadius: AppRadius.borderMd,
                ),
                child: Text(
                  options[index],
                  style: AppTypography.labelMedium.copyWith(
                    color: isSelected
                        ? AppColors.backgroundPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
