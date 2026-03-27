import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Large home-style header with title, optional plan badge, and profile icon.
class AppHomeHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const AppHomeHeaderBar({
    super.key,
    required this.title,
    this.planBadge,
  });

  final String title;
  final Widget? planBadge;

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headlineLarge),
          if (planBadge != null) ...[
            const SizedBox(height: 4),
            planBadge!,
          ],
        ],
      ),
    );
  }
}

/// Detail-style header with back button and centered title.
class AppDetailHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const AppDetailHeaderBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 4,
              child: GestureDetector(
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: SvgPicture.asset(
                    'assets/icons/chevron_left.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                        AppColors.textPrimary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
            Text(title, style: AppTypography.titleMedium),
            if (actions != null)
              Positioned(
                right: 4,
                child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
              ),
          ],
        ),
      ),
    );
  }
}
