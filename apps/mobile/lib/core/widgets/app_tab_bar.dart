import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AppTab { today, plan, progress, settings }

class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  final AppTab currentTab;
  final ValueChanged<AppTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: AppTab.values.map((tab) => _TabItem(
              tab: tab,
              isActive: currentTab == tab,
              onTap: () => onTabSelected(tab),
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final AppTab tab;
  final bool isActive;
  final VoidCallback onTap;

  String get _iconAsset {
    switch (tab) {
      case AppTab.today:
        return 'assets/icons/grid.svg';
      case AppTab.plan:
        return 'assets/icons/calendar.svg';
      case AppTab.progress:
        return 'assets/icons/bar_chart.svg';
      case AppTab.settings:
        return 'assets/icons/person.svg';
    }
  }

  String get _label {
    switch (tab) {
      case AppTab.today:
        return 'Today';
      case AppTab.plan:
        return 'Plan';
      case AppTab.progress:
        return 'Progress';
      case AppTab.settings:
        return 'Settings';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.accentPrimary : AppColors.textSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              _iconAsset,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              _label,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
