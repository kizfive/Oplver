import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/data/navigation_settings_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const MainScreen({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late PageController _pageController; // We need to recreate this if valid index changes drastically?
  // Actually PageController holds pixel offset. If pages count changes or current index changes mapping, we need to be careful.

  @override
  void initState() {
    super.initState();
    // Initial controller - we will update its position in didUpdateWidget/build
    _pageController = PageController(); 
  }

  @override
  void didUpdateWidget(MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Logic moved to build/post-build to handle riverpod state changes too
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navSettings = ref.watch(navigationSettingsProvider);
    
    // 1. Calculate Visible Navigation Items
    final visibleItems = navSettings.order
        .where((key) => !navSettings.hiddenKeys.contains(key))
        .map((key) => kAllNavigationItems.firstWhere((item) => item.key == key))
        .toList();

    // 2. Map current active branch to visual index
    final int activeBranchIndex = widget.navigationShell.currentIndex;
    int visualIndex = visibleItems.indexWhere((item) => item.branchIndex == activeBranchIndex);

    // If currently active branch is hidden (should not happen normally, but deep links possible)
    // fallback to first item or profile?
    if (visualIndex == -1) {
       // This is tricky. We are purely visual here. The route IS active.
       // Only showing content for visible items in PageView implies we can't show hidden items content.
       // If visualIndex is -1, maybe we should force navigation to a valid branch?
       // But build() cannot navigate.
       
       // Allow showing content? No, user said "User cannot switch to be closed options".
       // So force redirect logic? 
       // For now, let's just default to 0 if out of bounds, but ideally we match.
       visualIndex = 0; 
       
       // Side effect: Redirect if current is invalid
       WidgetsBinding.instance.addPostFrameCallback((_) {
          if (visibleItems.isNotEmpty) {
             final target = visibleItems.first.branchIndex;
             if (activeBranchIndex != target) {
                 widget.navigationShell.goBranch(target);
             }
          }
       });
    }

    // 3. Reorder children for PageView
    // widget.children corresponds to [0, 1, 2, 3] of branches
    final reorderedChildren = visibleItems.map((item) {
      if (item.branchIndex < widget.children.length) {
         return widget.children[item.branchIndex];
      }
      return const SizedBox();
    }).toList();

    // 4. Sync PageController
    if (_pageController.hasClients && _pageController.page?.round() != visualIndex) {
      _pageController.jumpToPage(visualIndex);
    } else if (!_pageController.hasClients) {
       _pageController = PageController(initialPage: visualIndex);
    }

    return Scaffold(
      body: PageView(
        controller: _pageController,
        // Playlist usually enables swipe. But if we dynamically reorder, swipe is fine.
        // User said: "Can switch position up/down... like in playlist".
        // "User cannot swipe/switch to closed options".
        // This implies hidden options are gone. Visible options are swipeable.
        physics: const ClampingScrollPhysics(), // Enable swipe
        onPageChanged: (index) {
          if (index >= 0 && index < visibleItems.length) {
             final targetBranch = visibleItems[index].branchIndex;
             if (targetBranch != widget.navigationShell.currentIndex) {
               widget.navigationShell.goBranch(targetBranch);
             }
          }
        },
        children: reorderedChildren
            .mapIndexed((index, child) => _KeepAlivePage(
                  key: ValueKey(visibleItems[index].branchIndex), // Important: Preserve state
                  child: child
              ))
            .toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: visualIndex,
        onDestinationSelected: (index) {
          if (index >= 0 && index < visibleItems.length) {
             final targetBranch = visibleItems[index].branchIndex;
             widget.navigationShell.goBranch(
               targetBranch,
               initialLocation: targetBranch == widget.navigationShell.currentIndex,
             );
          }
        },
        destinations: visibleItems.map((item) => _buildDestination(context, item.key)).toList(),
      ),
    );
  }

  NavigationDestination _buildDestination(BuildContext context, String key) {
    switch (key) {
      case 'home':
        return NavigationDestination(
          icon: Icon(Icons.home_outlined, color: Theme.of(context).colorScheme.primary),
          selectedIcon: Icon(Icons.home, color: Theme.of(context).colorScheme.primary),
          label: '首页',
        );
      case 'browse': // Key is 'browse', label '文件'
         return NavigationDestination(
            icon: Icon(Icons.folder_open,
                color: Theme.of(context).colorScheme.primary),
            selectedIcon: Icon(Icons.folder,
                color: Theme.of(context).colorScheme.primary),
            label: '文件',
          );
      case 'manga':
         return NavigationDestination(
            icon: Icon(Icons.menu_book_outlined,
                color: Theme.of(context).colorScheme.primary),
            selectedIcon: Icon(Icons.menu_book,
                color: Theme.of(context).colorScheme.primary),
            label: '漫画',
          );
      case 'profile':
         return NavigationDestination(
            icon: Icon(Icons.person_outline,
                color: Theme.of(context).colorScheme.primary),
            selectedIcon: Icon(Icons.person,
                color: Theme.of(context).colorScheme.primary),
            label: '我的',
          );
      default:
         return const NavigationDestination(icon: Icon(Icons.error), label: 'Unknown');
    }
  }
}

// Helper extension for mapIndexed since collection package might not be imported or used directly
extension IterableExtension<E> on Iterable<E> {
  Iterable<T> mapIndexed<T>(T Function(int index, E e) f) sync* {
    var index = 0;
    for (final element in this) {
      yield f(index++, element);
    }
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({super.key, required this.child});

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
