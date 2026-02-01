import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const MainScreen({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(initialPage: widget.navigationShell.currentIndex);
  }

  @override
  void didUpdateWidget(MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 确保 PageView 与 BottomNavigationBar 状态同步
    final int targetIndex = widget.navigationShell.currentIndex;
    final int? currentIndex = _pageController.page?.round();

    if (currentIndex != null && targetIndex != currentIndex) {
      _pageController.jumpToPage(targetIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (index != widget.navigationShell.currentIndex) {
            widget.navigationShell.goBranch(index);
          }
        },
        children: widget.children
            .map((child) => _KeepAlivePage(child: child))
            .toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined,
                color: Theme.of(context).colorScheme.primary),
            selectedIcon:
                Icon(Icons.home, color: Theme.of(context).colorScheme.primary),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_open,
                color: Theme.of(context).colorScheme.primary),
            selectedIcon: Icon(Icons.folder,
                color: Theme.of(context).colorScheme.primary),
            label: '文件',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline,
                color: Theme.of(context).colorScheme.primary),
            selectedIcon: Icon(Icons.person,
                color: Theme.of(context).colorScheme.primary),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
