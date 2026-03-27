import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_tab_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppTabBar(
        currentTab: _tabFromIndex(navigationShell.currentIndex),
        onTabSelected: (tab) {
          navigationShell.goBranch(
            _indexFromTab(tab),
            initialLocation: navigationShell.currentIndex == _indexFromTab(tab),
          );
        },
      ),
    );
  }

  static AppTab _tabFromIndex(int index) {
    switch (index) {
      case 0: return AppTab.today;
      case 1: return AppTab.plan;
      case 2: return AppTab.progress;
      case 3: return AppTab.settings;
      default: return AppTab.today;
    }
  }

  static int _indexFromTab(AppTab tab) {
    switch (tab) {
      case AppTab.today:    return 0;
      case AppTab.plan:     return 1;
      case AppTab.progress: return 2;
      case AppTab.settings: return 3;
    }
  }
}
