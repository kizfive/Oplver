import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/files/presentation/pages/file_browser_page.dart';
import '../../features/files/presentation/pages/download_record_page.dart'; // Added import
import '../../features/media/presentation/pages/video_player_page.dart';
import '../../features/files/presentation/pages/pdf_viewer_page.dart';
import '../../features/gallery/presentation/pages/photo_gallery_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/main_screen.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/manga/presentation/pages/manga_list_page.dart';
import '../../features/manga/presentation/pages/manga_reader_page.dart';
import '../../features/manga/data/manga_models.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/auth/data/auth_provider.dart';
import '../../features/settings/data/navigation_settings_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'homeNav');
final _sectionANavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sectionANav');
final _sectionBNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sectionBNav');
final _sectionCNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sectionCNav');
final _sectionDNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sectionDNav');

// 创建 Router Provider 以便监听认证状态变化 (重定向逻辑)
final routerProvider = Provider<GoRouter>((ref) {
  // 注意：不要在这里 ref.watch(authProvider)，否则每次状态变化都会重建整个 GoRouter 实例，
  // 导致页面状态（如输入框内容）丢失。
  // 重定向逻辑由 refreshListenable 触发。

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login', // 初始默认路径
    refreshListenable: _AuthStateListenable(ref), // 当认证状态变化时触发重定向
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider).isAuthenticated;
      final isLoggingIn = state.uri.toString() == '/login';
      final isInitial = state.uri.toString() == '/';

      // 未登录且不在登录页，跳转到登录页
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      // 已登录但在登录页或根路径，跳转到主页 (Tab页 /home)
      if (isLoggedIn && (isLoggingIn || isInitial)) {
        final navSettings = ref.read(navigationSettingsProvider);
        final defaultItem = kAllNavigationItems.firstWhere(
           (item) => item.key == navSettings.defaultPageKey,
           orElse: () => kAllNavigationItems.first
        );
        return defaultItem.route;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        // 使用 state.pageKey 保持页面状态，防止 GoRouter 在重定向检查时重建页面导致输入框清空
        builder: (context, state) => LoginPage(key: state.pageKey),
      ),
      // 视频播放器路由，通过 query parameter 传递 path
      // 这是一个全屏页面，在 Root Navigator 上显示，盖过 BottomNav
      GoRoute(
        path: '/video',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          final playlist = extra?['playlist'] as List<String>? ?? [];
          return VideoPlayerPage(filePath: path, initialPlaylist: playlist);
        },
      ),
      GoRoute(
        path: '/pdf',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'] ?? '';
          return PdfViewerPage(path: path);
        },
      ),
      GoRoute(
        path: '/gallery/view',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final imageUrls = extra['imageUrls'] as List<String>;
          final initialIndex = extra['initialIndex'] as int;
          final headers = extra['headers'] as Map<String, String>;
          final files = extra['files']
              as List<dynamic>?; // Receive files (List<webdav.File>)
          final currentPath = extra['currentPath'] as String? ?? '/';
          return PhotoGalleryPage(
            imageUrls: imageUrls,
            initialIndex: initialIndex,
            headers: headers,
            files: files,
            currentPath: currentPath,
          );
        },
      ),
      GoRoute(
        path: '/download_records',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DownloadRecordPage(),
      ),
      // 漫画阅读器路由
      GoRoute(
        path: '/manga/reader',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final manga = state.extra as MangaInfo;
          return MangaReaderPage(manga: manga);
        },
      ),
      // 设置页面路由
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsPage(),
      ),
      // 文件夹详情页面 - 全屏显示，不显示底部导航栏
      GoRoute(
        path: '/browse/dir/:path(.*)',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final p = state.pathParameters['path'] ?? '';
          final decoded = p.isEmpty ? '/' : '/$p';
          final highlight = state.uri.queryParameters['highlight'];
          return CustomTransitionPage(
            key: state.pageKey,
            child: FileBrowserPage(
                initialPath: decoded, highlightFileName: highlight),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final opacity =
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut);
              return FadeTransition(opacity: opacity, child: child);
            },
          );
        },
      ),
      // 文件浏览路由 /files
      // 这是一个全屏页面，盖过 BottomNav (根据需求 "大型按钮...跳转到现在的目录树页面")
      // 我们将其放在 Root Navigator 栈顶
      GoRoute(
        path: '/files',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FileBrowserPage(initialPath: '/'),
      ),
      GoRoute(
        path: '/files/:path(.*)',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final p = state.pathParameters['path'] ?? '';
          // GoRouter 已经对 pathParameters 进行了 URL 解码
          final decoded = p.isEmpty ? '/' : '/$p';
          return FileBrowserPage(initialPath: decoded);
        },
      ),

      // 使用 StatefulShellRoute 实现底部导航栏
      // 为了支持 PageView 实现左右滑动，我们需要拿到 children 列表
      // 同时添加 builder 参数以满足 go_router 的断言检查 (One of builder or pageBuilder must be provided)
      StatefulShellRoute(
        navigatorContainerBuilder: (context, navigationShell, children) {
          return MainScreen(
              navigationShell: navigationShell, children: children);
        },
        builder: (context, state, navigationShell) {
          return navigationShell;
        },
        branches: [
          // Tab 1: 首页
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const HomePage(),
              ),
            ],
          ),
          // Tab 2: 文件浏览 (原概览) - 默认显示根目录
          StatefulShellBranch(
            navigatorKey: _sectionANavigatorKey,
            routes: [
              GoRoute(
                path:
                    '/browse', // Changed from /home since home is now HomePage
                builder: (context, state) {
                  final highlight = state.uri.queryParameters['highlight'];
                  return FileBrowserPage(
                      initialPath: '/', highlightFileName: highlight);
                },
              ),
            ],
          ),
          // Tab 3: 漫画 (Manga)
          StatefulShellBranch(
            navigatorKey: _sectionCNavigatorKey,
            routes: [
              GoRoute(
                path: '/manga',
                builder: (context, state) => const MangaListPage(),
              ),
            ],
          ),
          // Tab 4: 个人中心 (Profile)
          StatefulShellBranch(
            navigatorKey: _sectionDNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// 一个简单的 Listenable 包装器，用于 GoRouter 监听 Riverpod 状态
class _AuthStateListenable extends ChangeNotifier {
  final Ref ref;
  _AuthStateListenable(this.ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
