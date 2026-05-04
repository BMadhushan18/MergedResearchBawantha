import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:boq_frontend/features/it22172532/providers/ai_provider.dart';
import 'package:boq_frontend/features/it22172532/providers/project_provider.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'package:boq_frontend/features/it22172532/screens/home/home_screen.dart';
import 'package:boq_frontend/features/it22172532/screens/project_progress/track_progress_screen.dart';
import 'package:boq_frontend/features/it22172532/screens/projects/project_search_screen.dart';
import 'package:boq_frontend/features/it22172532/screens/three_d_view/view_3d_screen.dart';

class AppNavigationShell extends StatefulWidget {
  final int initialIndex;

  const AppNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  late int _currentIndex;

  // Each tab has its own navigator so the bottom bar stays visible
  // when screens are pushed inside a tab.
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiProvider>().loadKey();
    });
  }

  /// Pop the active tab's navigator; if at its root, let the system handle it.
  bool _onBackPressed() {
    final nav = _navigatorKeys[_currentIndex].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return true; // consumed
    }
    return false; // let OS handle (exit)
  }

  Widget _tabNavigator(int index, Widget Function(BuildContext) builder) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: builder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Never auto-pop the shell; we handle it manually.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackPressed();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _tabNavigator(0, (_) => const HomeScreen()),
            _tabNavigator(1, (_) => const View3DScreen()),
            _tabNavigator(2, (_) => const ProjectSearchScreen()),
            _tabNavigator(3, (ctx) {
              final sp =
                  ctx.watch<ProjectProvider>().currentProject;
              return TrackProgressScreen(
                pid: sp?.projectId,
                projectName: sp?.projectName,
                location: sp?.location,
              );
            }),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          color: Colors.white,
          elevation: 8,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                _navItem(1, Icons.view_in_ar_outlined, Icons.view_in_ar_rounded, '3D View'),
                _navItem(2, Icons.search_outlined, Icons.search_rounded, 'Projects'),
                _navItem(3, Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Progress'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final selected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (index != _currentIndex) {
            setState(() => _currentIndex = index);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
