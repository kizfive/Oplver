// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as path_context;
import '../../application/download_service.dart';
import '../../../../features/auth/data/auth_provider.dart';
import '../../../../core/utils/file_utils.dart';
import '../../data/file_provider.dart';
import '../../data/view_mode_provider.dart';
import '../../../history/data/file_history_provider.dart';
import 'package:intl/intl.dart';
import 'dart:math'; // Import for Random
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../../../features/settings/data/general_settings_provider.dart';
import '../../../../features/settings/data/video_settings_provider.dart';
import '../../../../features/media/data/video_playback_history_provider.dart';
import '../widgets/video_thumbnail_image.dart';
import '../widgets/thumbnail_container.dart';
import 'package:openlist_viewer/features/files/data/pdf_progress_provider.dart';
import '../../application/folder_analytics_service.dart';

class FileBrowserPage extends ConsumerStatefulWidget {
  final String initialPath;
  final String? highlightFileName;
  const FileBrowserPage(
      {super.key, this.initialPath = '/', this.highlightFileName});

  @override
  ConsumerState<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends ConsumerState<FileBrowserPage> {
  // Store thumbnail version seeds: key=filePath, value=seed
  final Map<String, int> _thumbnailSeeds = {};
  final ScrollController _breadcrumbScrollController = ScrollController();
  final ScrollController _listScrollController = ScrollController();
  // To prevent repeated scrolling
  bool _hasScrolledToHighlight = false;
  // To prevent double pops
  DateTime? _lastPopTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_breadcrumbScrollController.hasClients) {
        _breadcrumbScrollController
            .jumpTo(_breadcrumbScrollController.position.maxScrollExtent);
      }

      // Analytics: Record Visit
      ref
          .read(folderAnalyticsProvider.notifier)
          .enterFolder(widget.initialPath);
    });
  }

  @override
  void dispose() {
    _breadcrumbScrollController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FileBrowserPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检查是否需要重新滚动到高亮文件
    // 如果路径改变了，或者提供了新的高亮文件 (例如从历史记录或者搜索跳转过来)
    if (widget.highlightFileName != null) {
      // 用户强调：即使目录未变化，也要强制触发滚动
      // 所以只要 highlightFileName 存在，我们就尝试滚动

      // 重置滚动标志
      _hasScrolledToHighlight = false;

      // 立即尝试滚动（如果数据已就绪）
      final fileState = ref.read(fileBrowserProvider(widget.initialPath));
      if (!fileState.isLoading && fileState.files.isNotEmpty) {
        // 使用 addPostFrameCallback 确保在任何可能的布局更新之后
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToHighlight(context, fileState.files);
        });
      }
    } else if (widget.initialPath != oldWidget.initialPath) {
      _hasScrolledToHighlight = false;
    }
  }

  void _regenerateThumbnail(String filePath) {
    setState(() {
      final currentSeed = _thumbnailSeeds[filePath] ?? 0;
      _thumbnailSeeds[filePath] = currentSeed + 1;
    });
  }

  void _showSortSheet(BuildContext context, FileBrowserState state,
      FileBrowserNotifier notifier) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled:
          true, // Allow full height if needed, but safe area handles it usually
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('排序方式',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                _buildSortOption(context, '名称 (A-Z)', Icons.sort_by_alpha,
                    SortOption.name, SortOrder.asc, state, notifier),
                _buildSortOption(
                    context,
                    '名称 (Z-A)',
                    Icons.sort_by_alpha_outlined,
                    SortOption.name,
                    SortOrder.desc,
                    state,
                    notifier),
                const Divider(),
                _buildSortOption(context, '大小 (小到大)', Icons.format_size,
                    SortOption.size, SortOrder.asc, state, notifier),
                _buildSortOption(context, '大小 (大到小)', Icons.format_size,
                    SortOption.size, SortOrder.desc, state, notifier),
                const Divider(),
                _buildSortOption(context, '日期 (旧到新)', Icons.calendar_today,
                    SortOption.date, SortOrder.asc, state, notifier),
                _buildSortOption(
                    context,
                    '日期 (新到旧)',
                    Icons.calendar_today_outlined,
                    SortOption.date,
                    SortOrder.desc,
                    state,
                    notifier),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(
      BuildContext context,
      String label,
      IconData icon,
      SortOption option,
      SortOrder order,
      FileBrowserState state,
      FileBrowserNotifier notifier) {
    final isSelected = state.sortOption == option && state.sortOrder == order;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? Theme.of(context).colorScheme.primary : null),
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        notifier.setSort(option, order);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _handleDownload(BuildContext context, WidgetRef ref,
      webdav.File file, List<webdav.File> siblings) async {
    final downloadService = ref.read(downloadServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    // 1. Check preconditions
    final status = await downloadService.checkPreconditions();

    if (!mounted) return;

    if (status == DownloadPreconditionStatus.permissionDenied) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('需要存储权限才能下载')));
      return;
    }

    // Check Download Mode setting
    final settings = ref.read(generalSettingsProvider);
    var downloadMode = settings.defaultDownloadMode;

    bool proceed = true;
    bool batchDownloadMode = downloadMode == DownloadMode.folder;

    // If 'alwaysAsk', show dialog with choice
    if (downloadMode == DownloadMode.alwaysAsk) {
      final selected = await showDialog<DownloadMode>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('下载选项'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('文件名: ${file.name}'),
              if (file.size != null) Text('大小: ${_formatSize(file.size!)}'),
              const SizedBox(height: 16),
              const Text('请选择下载方式:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('取消'),
            ),
            // Option 1: Download Single File
            TextButton(
              onPressed: () => Navigator.pop(context, DownloadMode.singleFile),
              child: const Text('仅下载文件'),
            ),
            // Option 2: Download All (Siblings)
            TextButton(
              onPressed: () => Navigator.pop(context, DownloadMode.folder),
              child: const Text('下载当前目录下所有内容'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (selected == null) {
        proceed = false;
      } else {
        // Reuse 'folder' mode as 'batch download' mode trigger in this context
        batchDownloadMode = selected == DownloadMode.folder;
      }
    }

    if (!proceed || !mounted) return;

    if (status == DownloadPreconditionStatus.requiresWifi) {
      proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('流量提醒'),
              content: const Text('当前处于移动数据网络，是否继续下载？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('继续'),
                ),
              ],
            ),
          ) ??
          false;
      if (!mounted) return;
    }

    if (!proceed || !mounted) return;

    // Define helper for single download logic
    Future<void> startSingleDownload(webdav.File targetFile) async {
      // Use posix for WebDav paths
      final fullPath =
          path_context.posix.join(widget.initialPath, targetFile.name ?? '');

      try {
        if (targetFile.isDir ?? false) {
          await downloadService.downloadFolder(fullPath);
        } else {
          if (batchDownloadMode) {
            // Get current folder name
            final parentFolderName = widget.initialPath == '/'
                ? 'root'
                : path_context.posix.basename(widget.initialPath);

            await downloadService.downloadFile(fullPath,
                subDirectory: parentFolderName);
          } else {
            await downloadService.downloadFile(fullPath);
          }
        }
        if (!mounted) return;
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下载完成: ${targetFile.name}'), duration: const Duration(seconds: 1)));
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('下载失败 (${targetFile.name}): $e')));
      }
    }

    if (batchDownloadMode) {
      if (!mounted) return;
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('开始批量下载 ${siblings.length} 个项目...'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => context.push('/download_records'),
        ),
      ));
      // Run sequentially or parallel? WebDAV might limit parallel connections.
      // Let's do sequential to be safe.
      for (var f in siblings) {
        if (!mounted) break;
        await startSingleDownload(f);
      }
    } else {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('开始下载: ${file.name}'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => context.push('/download_records'),
        ),
      ));
      await startSingleDownload(file);
    }
  }

  void _showFileOptions(BuildContext parentContext, webdav.File file,
      AppFileType type, List<webdav.File> siblings) {
    bool isFolder = file.isDir ?? false;

    showModalBottomSheet(
      context: parentContext,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(file.name ?? 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Divider(),

              // Only show download if it's NOT a folder, as requested
              if (!isFolder)
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('下载到本地'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    // Use parentContext (from Page) to ensure it survives the sheet pop
                    _handleDownload(parentContext, ref, file, siblings);
                  },
                ),

              ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('文件属性'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showFileAttributes(file);
                  }),
              if (type == AppFileType.video)
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('重新生成预览图'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _regenerateThumbnail(file.name ?? '');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileAttributes(webdav.File file) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('文件属性'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('名称: ${file.name}'),
                  const SizedBox(height: 8),
                  Text(
                      '大小: ${file.size != null ? _formatSize(file.size!) : "未知"}'),
                  const SizedBox(height: 8),
                  Text(
                      '修改时间: ${file.mTime != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(file.mTime!) : "--"}'),
                  const SizedBox(height: 8),
                  Text('类型: ${file.mimeType ?? "未知"}'),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'))
              ],
            ));
  }

  Widget _buildBreadcrumbs(BuildContext context, String currentPath) {
    if (currentPath == '/' || currentPath.isEmpty) {
      return const SizedBox.shrink();
    }

    final segments = currentPath.split('/').where((s) => s.isNotEmpty).toList();

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
            bottom:
                BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              // Go to root
              context.go('/browse', extra: {'isBack': true});
            },
            tooltip: '根目录',
          ),
          const VerticalDivider(width: 1, indent: 8, endIndent: 8),
          Expanded(
            child: ListView.separated(
              controller: _breadcrumbScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: segments.length,
              separatorBuilder: (context, index) =>
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              itemBuilder: (context, index) {
                final segment = segments[index];
                final isLast = index == segments.length - 1;
                return InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: isLast
                      ? null
                      : () {
                          final targetPath =
                              '/${segments.sublist(0, index + 1).join('/')}';
                          final encoded =
                              Uri.encodeComponent(targetPath.substring(1));
                          // Treat breadcrumb jump as 'back' for animation logic if target is ancestor
                          context.go('/browse/dir/$encoded',
                              extra: {'isBack': true});
                        },
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        segment,
                        style: TextStyle(
                          color: isLast
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).textTheme.bodyMedium?.color,
                          fontWeight:
                              isLast ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int size) {
    if (size < 1024) {
      return '$size B';
    }
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    }
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _handleFileTap(BuildContext context, webdav.File file,
      String currentPath, List<webdav.File> files) {
    if (file.isDir ?? false) {
      final newPath = path_context.join(currentPath, file.name ?? '');
      final encoded =
          newPath == '/' ? '' : Uri.encodeComponent(newPath.substring(1));

      // Analytics
      ref.read(folderAnalyticsProvider.notifier).enterFolder(newPath);

      context.push('/browse/dir/$encoded'); // Normal push (slide)
      return;
    }

    final fileType = FileUtils.getFileType(file.name ?? '', false);
    final fullPath = path_context.join(currentPath, file.name ?? '');

    // Analytics
    ref.read(folderAnalyticsProvider.notifier).interactWithFile(fullPath);

    // Add to history
    ref.read(fileHistoryProvider.notifier).addToHistory(fullPath);

    if (fileType == AppFileType.video) {
      final videoFiles = files
          .where((f) =>
              FileUtils.getFileType(f.name ?? '', false) == AppFileType.video)
          .toList();
      final currentIndex = videoFiles.indexWhere((f) => f.name == file.name);
      List<String> playlist = [];
      if (currentIndex != -1) {
        playlist = videoFiles
            .sublist(currentIndex)
            .map((f) => path_context.join(currentPath, f.name ?? ''))
            .toList();
      }
      context.push(
          Uri(path: '/video', queryParameters: {'path': fullPath}).toString(),
          extra: {'playlist': playlist});
    } else if (fileType == AppFileType.pdf) {
      context.push(
          Uri(path: '/pdf', queryParameters: {'path': fullPath}).toString());
    } else if (fileType == AppFileType.image) {
      final imageFiles = files
          .where((f) =>
              FileUtils.getFileType(f.name ?? '', false) == AppFileType.image)
          .toList();
      final webDavService = ref.read(webDavServiceProvider);
      if (webDavService.baseUrl == null) {
        return;
      }

      final Uri baseUri = Uri.parse(webDavService.baseUrl!);
      var basePathSegments = List<String>.from(baseUri.pathSegments);
      if (basePathSegments.isNotEmpty && basePathSegments.last.isEmpty) {
        basePathSegments.removeLast();
      }

      final imageUrls = imageFiles.map((f) {
        var pathSegments = <String>[];
        pathSegments.addAll(basePathSegments);
        pathSegments.addAll(currentPath.split('/').where((s) => s.isNotEmpty));
        pathSegments.add(f.name ?? '');
        return baseUri.replace(pathSegments: pathSegments).toString();
      }).toList();

      final initialIndex = imageFiles.indexWhere((f) => f.name == file.name);
      context.push('/gallery/view', extra: {
        'imageUrls': imageUrls,
        'initialIndex': initialIndex != -1 ? initialIndex : 0,
        'headers': webDavService.authHeaders,
        'files': imageFiles, // Pass the File objects
        'currentPath': currentPath,
      });
    } else {
      // Unknown type
    }
  }

  void _scrollToHighlight(BuildContext context, List<webdav.File> files) {
    if (widget.highlightFileName == null || _hasScrolledToHighlight) return;
    final index = files.indexWhere((f) => f.name == widget.highlightFileName);
    if (index == -1) return;

    _hasScrolledToHighlight = true;

    final viewMode = ref.read(viewModeProvider);
    double offset = 0;

    if (viewMode == ViewMode.list) {
      // 列表模式：移动到从上往下第二个位置
      // 修正列表项高度估计 (Tile 72 + Vertical Padding 16 = 88?)
      // 实际上可能是 72-80 左右，稍微估大一点以防滚不到位导致在底部
      const double itemHeight = 88.0;
      final targetIndex = (index > 0) ? index - 1 : 0;
      offset = targetIndex * itemHeight;
    } else {
      // 网格模式：文件所在的行是第一行的位置
      final screenWidth = MediaQuery.of(context).size.width;
      // GridView padding: 8, crossAxisSpacing: 8
      // Width = (Screen - 8(L) - 8(R) - 8(Spacing)) / 2 = (Screen - 24) / 2
      final itemWidth = (screenWidth - 24) / 2;
      final itemHeight = itemWidth / 1.25;
      final row = index ~/ 2;

      // GridView top padding is 8.0
      // Row 0 starts at 8.0
      // Row N starts at 8.0 + N * (itemHeight + 8.0)
      offset = 8.0 + row * (itemHeight + 8.0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      //稍微延迟以确保 ScrollController 已连接且布局完成
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_listScrollController.hasClients) {
          final maxScroll = _listScrollController.position.maxScrollExtent;
          // 确保不超过最大滚动范围
          final target = offset.clamp(0.0, maxScroll);
          _listScrollController.animateTo(target,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen for data load to trigger scroll
    ref.listen(fileBrowserProvider(widget.initialPath), (previous, next) {
      if (!next.isLoading &&
          next.files.isNotEmpty &&
          !_hasScrolledToHighlight &&
          widget.highlightFileName != null) {
        _scrollToHighlight(context, next.files);
      }
    });

    // Check on build as well (if cached)
    final fileState = ref.watch(fileBrowserProvider(widget.initialPath));
    if (!fileState.isLoading &&
        fileState.files.isNotEmpty &&
        !_hasScrolledToHighlight &&
        widget.highlightFileName != null) {
      _scrollToHighlight(context, fileState.files);
    }

    final notifier = ref.read(fileBrowserProvider(widget.initialPath).notifier);
    final viewMode = ref.watch(viewModeProvider);

    // Get current route to determine navigation behavior
    final stateUri = GoRouterState.of(context).uri;
    final isFromHome = stateUri.queryParameters['from'] == 'home';
    final canGoBack =
        widget.initialPath != '/' && widget.initialPath.isNotEmpty;

    return PopScope(
      canPop: false, // Always intercept back gesture
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Handle back gesture
        if (canGoBack) {
          final now = DateTime.now();
          if (_lastPopTime != null &&
              now.difference(_lastPopTime!).inMilliseconds < 500) {
            return;
          }
          _lastPopTime = now;

          // Navigate to parent directory
          final parentPath = widget.initialPath
              .substring(0, widget.initialPath.lastIndexOf('/'));
          final normalizedParent = parentPath.isEmpty ? '/' : parentPath;

          if (normalizedParent == '/') {
            context.go('/browse');
          } else {
            final encoded = Uri.encodeComponent(normalizedParent.substring(1));
            context.go('/browse/dir/$encoded');
          }
        } else {
          // At root, exit app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        drawerEnableOpenDragGesture: false, // 禁用侧滑抽屉手势，防止冲突
        appBar: AppBar(
          title: Text(
            fileState.currentPath == '/'
                ? 'Home'
                : fileState.currentPath.split('/').last,
          ),
          leading: widget.initialPath != '/'
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    final now = DateTime.now();
                    if (_lastPopTime != null &&
                        now.difference(_lastPopTime!).inMilliseconds < 500) {
                      return;
                    }
                    _lastPopTime = now;

                    // If from home page (常访文件夹/播放历史), go back to home
                    if (isFromHome) {
                      context.go('/home');
                    } else {
                      // Normal navigation, try to pop
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        // No navigation stack, go to browse root
                        context.go('/browse');
                      }
                    }
                  },
                )
              : null,
          actions: [
            IconButton(
              icon: Icon(viewMode == ViewMode.grid
                  ? Icons.grid_view
                  : Icons.view_list),
              tooltip: '切换试图',
              onPressed: () {
                ref.read(viewModeProvider.notifier).toggle();
              },
            ),
            IconButton(
              icon: const Icon(Icons.sort),
              tooltip: '排序',
              onPressed: () {
                _showSortSheet(context, fileState, notifier);
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => notifier.refresh(),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildBreadcrumbs(context, fileState.currentPath),
            Expanded(
              child: fileState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : fileState.error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(fileState.error!,
                                  style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => notifier.refresh(),
                                child: const Text('重试'),
                              )
                            ],
                          ),
                        )
                      : fileState.files.isEmpty
                          ? const Center(child: Text('也就是这里空空如也'))
                          : viewMode == ViewMode.list
                              ? ListView.builder(
                                  controller: _listScrollController,
                                  itemCount: fileState.files.length,
                                  itemBuilder: (context, index) {
                                    final file = fileState.files[index];
                                    final isHighlighted =
                                        widget.highlightFileName != null &&
                                            file.name ==
                                                widget.highlightFileName;

                                    Widget item = _FileListItem(
                                      file: file,
                                      currentPath: fileState.currentPath,
                                      thumbnailSeed:
                                          _thumbnailSeeds[file.name] ?? 0,
                                      onLongPress: (fileType) {
                                        _showFileOptions(context, file,
                                            fileType, fileState.files);
                                      },
                                      onTap: () => _handleFileTap(
                                          context,
                                          file,
                                          fileState.currentPath,
                                          fileState.files),
                                    );

                                    if (isHighlighted) {
                                      item = Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: 0.3),
                                          border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              width: 2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: item,
                                      );
                                    }
                                    return item;
                                  },
                                )
                              : GridView.builder(
                                  controller: _listScrollController,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio:
                                        1.25, // Optimized for 16:9 thumbnail + text
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  itemCount: fileState.files.length,
                                  itemBuilder: (context, index) {
                                    final file = fileState.files[index];
                                    final isHighlighted =
                                        widget.highlightFileName != null &&
                                            file.name ==
                                                widget.highlightFileName;

                                    Widget item = _FileGridItem(
                                      file: file,
                                      currentPath: fileState.currentPath,
                                      thumbnailSeed:
                                          _thumbnailSeeds[file.name] ?? 0,
                                      onLongPress: (fileType) {
                                        _showFileOptions(context, file,
                                            fileType, fileState.files);
                                      },
                                      onTap: () => _handleFileTap(
                                          context,
                                          file,
                                          fileState.currentPath,
                                          fileState.files),
                                    );

                                    if (isHighlighted) {
                                      item = Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: 0.3),
                                          border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              width: 2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: item,
                                      );
                                    }
                                    return item;
                                  },
                                ),
            ),
          ],
        ),
      ), // End of PopScope
    );
  }
}

class _FileListItem extends ConsumerWidget {
  final webdav.File file;
  final String currentPath;
  final VoidCallback onTap;
  final Function(AppFileType) onLongPress;
  final int thumbnailSeed;

  const _FileListItem({
    required this.file,
    required this.currentPath,
    required this.onTap,
    required this.onLongPress,
    this.thumbnailSeed = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDir = file.isDir ?? false;
    final modTime = file.mTime != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(file.mTime!)
        : '--';

    final generalSettings = ref.watch(generalSettingsProvider);
    final showThumbnails = generalSettings.showFileThumbnails;

    // 简单的大小格式化
    String sizeStr = '';
    if (!isDir && file.size != null) {
      final size = file.size!;
      if (size < 1024) {
        sizeStr = '$size B';
      } else if (size < 1024 * 1024) {
        sizeStr = '${(size / 1024).toStringAsFixed(1)} KB';
      } else {
        sizeStr = '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
      }
    }

    Widget leadingWidget;

    // Prepare placeholder background color (Theme color darkened)
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final placeholderColor = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.2)
        : theme.colorScheme.primaryContainer
            .withValues(alpha: 0.6); // Darkened relative to container

    // Determine type for long press
    final ext = (file.name ?? '').split('.').last.toLowerCase();
    AppFileType type = AppFileType.unknown;
    if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) {
      type = AppFileType.video;
    } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
      type = AppFileType.image;
    } else if (ext == 'pdf') {
      type = AppFileType.pdf;
    } else if (isDir) {
      type = AppFileType.folder;
    }

    if (isDir) {
      leadingWidget = Icon(
        Icons.folder,
        color: Theme.of(context).colorScheme.primary,
        size: 32,
      );
    } else {
      if (type == AppFileType.video) {
        // Widescreen 16:9 ratio for video

        // Calculate progress
        final fullPath = pathContext.join(currentPath, file.name ?? '');
        final history = ref.watch(videoPlaybackHistoryProvider);
        final pos = history.positions[fullPath] ?? 0;
        final dur = history.durations[fullPath] ?? 0;
        final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

        if (showThumbnails) {
          // Smart Seek Implementation (Adaptive Bitrate)
          // ... previous logic ...
          final size = file.size ?? 0;
          int timeMs = 10000; // Default 10s

          if (size > 0) {
            double assumedBitrate = 2 * 1024 * 1024; // Default: 2MB/s (16Mbps)

            if (size > 500 * 1024 * 1024) assumedBitrate = 4 * 1024 * 1024;
            if (size > 2 * 1024 * 1024 * 1024) assumedBitrate = 8 * 1024 * 1024;

            final estimatedDurationMs = (size / assumedBitrate) * 1000;

            // Default: Target 45% of estimated timeline
            double percent = 0.45;

            // Apply Random Offset if regenerated (seed > 0)
            if (thumbnailSeed > 0) {
              final rng = Random(file.name.hashCode ^ thumbnailSeed);
              final sign = rng.nextBool() ? 1 : -1;
              final magnitude = rng.nextDouble() * 0.4;
              percent = percent + (sign * magnitude);
            }
            timeMs = (estimatedDurationMs * percent).toInt();
            final int upperLimit = (thumbnailSeed > 0) ? 300000 : 60000;
            timeMs = timeMs.clamp(5000, upperLimit);
          }

          // Video uses fixed width 16:9
          leadingWidget = ThumbnailContainer(
            backgroundColor: placeholderColor,
            typeIcon: Icons.videocam,
            progress: progress,
            child: VideoThumbnailImage(
              file: file,
              currentPath: currentPath,
              timeMs: timeMs,
            ),
          );
        } else {
          // Placeholder maintaining size
          leadingWidget = ThumbnailContainer(
            backgroundColor: placeholderColor,
            typeIcon: Icons.videocam,
            progress: progress,
            child: Icon(Icons.movie,
                color: theme.colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.5)),
          );
        }
      } else if (type == AppFileType.pdf) {
        // PDF with Progress Bar
        final fullPath = pathContext.join(currentPath, file.name ?? '');
        final progressData = ref.watch(pdfProgressProvider)[fullPath];
        double progress = 0.0;
        if (progressData != null && progressData.total > 0) {
          progress =
              ((progressData.page + 1) / progressData.total).clamp(0.0, 1.0);
        }

        leadingWidget = ThumbnailContainer(
          backgroundColor: placeholderColor,
          typeIcon: Icons.picture_as_pdf,
          progress: progress,
          child: Icon(Icons.picture_as_pdf,
              size: 32,
              color:
                  theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.5)),
        );
      } else if (type == AppFileType.image) {
        // Display thumbnail for image
        final webDavService = ref.read(webDavServiceProvider);

        if (showThumbnails &&
            webDavService.isConnected &&
            webDavService.baseUrl != null) {
          final Uri baseUri = Uri.parse(webDavService.baseUrl!);
          var pathSegments = <String>[];
          pathSegments.addAll(baseUri.pathSegments);
          // Remove empty last segment if any
          if (pathSegments.isNotEmpty && pathSegments.last == '') {
            pathSegments.removeLast();
          }

          var dirSegments = currentPath.split('/').where((s) => s.isNotEmpty);
          pathSegments.addAll(dirSegments);

          if (file.name != null) {
            pathSegments.add(file.name!);
          }

          // Remove queryParameters since server ignores them and returns original file
          final uri = baseUri.replace(pathSegments: pathSegments);

          leadingWidget = ThumbnailContainer(
            backgroundColor: placeholderColor,
            typeIcon: Icons.image,
            child: CachedNetworkImage(
              imageUrl: uri.toString(),
              httpHeaders: webDavService.authHeaders,
              memCacheHeight: 200,
              fit: BoxFit.contain,
              imageBuilder: (context, imageProvider) => Image(
                image: imageProvider,
                fit: BoxFit.contain,
              ),
              placeholder: (context, url) => Icon(_getFileIcon(file.name),
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer
                      .withValues(alpha: 0.5)),
              errorWidget: (context, url, error) => Icon(
                  _getFileIcon(file.name),
                  size: 32,
                  color: theme.colorScheme.error),
            ),
          );
        } else {
          // Placeholder maintaining size
          leadingWidget = ThumbnailContainer(
            backgroundColor: placeholderColor,
            typeIcon: Icons.image,
            child: Icon(_getFileIcon(file.name),
                size: 32,
                color: theme.colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.5)),
          );
        }
      } else {
        leadingWidget = ThumbnailContainer(
            backgroundColor:
                placeholderColor, // Use consistent container for other files too? Or just Icon?
            // User asked for "file attribute icon", maybe imply generic file icon if not specific.
            // Let's stick to the request "add a file attribute icon to the bottom right corner"
            // For generic files, maybe we just use the icon centered.
            // But to keep alignment consistent, let's wrap generic files too.
            typeIcon: Icons.insert_drive_file,
            child: Icon(_getFileIcon(file.name),
                size: 32,
                color: theme.colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.5)));
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8), // Add vertical padding to handle varying heights
      leading:
          leadingWidget, // Remove SizedBox wrapper, use leadingWidget directly which has constraints
      minLeadingWidth: 0, // Allow dynamic width shrinking
      title: Text(
        file.name ?? 'Unknown',
        // Allow unlimited lines
      ),
      subtitle: Text('$modTime  $sizeStr'),
      trailing: isDir ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
      onLongPress: () => onLongPress(type),
    );
  }

  IconData _getFileIcon(String? name) {
    if (name == null) return Icons.insert_drive_file;
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return Icons.movie;
      case 'mp3':
      case 'flac':
      case 'wav':
        return Icons.music_note;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
      case 'md':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }
}

class _FileGridItem extends ConsumerWidget {
  final webdav.File file;
  final String currentPath;
  final int thumbnailSeed;
  final Function(AppFileType) onLongPress;
  final VoidCallback onTap;

  const _FileGridItem({
    required this.file,
    required this.currentPath,
    required this.thumbnailSeed,
    required this.onLongPress,
    required this.onTap,
  });

  IconData _getFileIcon(String? filename) {
    return FileUtils.getFileIcon(filename ?? '');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(videoSettingsProvider);
    final showThumbnails = settings.enableThumbnails;
    final placeholderColor = theme.colorScheme.surfaceContainerHighest;

    Widget thumbnailWidget;
    final type = FileUtils.getFileType(file.name ?? '', file.isDir ?? false);

    // IconData typeIconData = Icons.insert_drive_file;

    if (file.isDir ?? false) {
      thumbnailWidget = Center(
          child:
              Icon(Icons.folder, size: 48, color: theme.colorScheme.primary));
    } else if (type == AppFileType.video) {
      // typeIconData = Icons.videocam;
      final fullPath = path_context.join(currentPath, file.name ?? '');
      final history = ref.watch(videoPlaybackHistoryProvider);
      final pos = history.positions[fullPath] ?? 0;
      final dur = history.durations[fullPath] ?? 0;
      final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

      Widget content;
      if (showThumbnails) {
        final size = file.size ?? 0;
        int timeMs = 10000;
        if (size > 0) {
          final estimatedDurationMs = (size / (2 * 1024 * 1024)) * 1000;
          timeMs = (estimatedDurationMs * 0.45).toInt().clamp(5000, 60000);
        }
        content = VideoThumbnailImage(
          file: file,
          currentPath: currentPath,
          timeMs: timeMs,
        );
      } else {
        content = Icon(Icons.movie,
            size: 48,
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.5));
      }

      thumbnailWidget = Stack(
        fit: StackFit.expand,
        children: [
          Container(color: placeholderColor, child: content),
          if (progress > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(value: progress, minHeight: 4),
            ),
          const Positioned(
            top: 4,
            right: 4,
            child: Icon(Icons.videocam, size: 16, color: Colors.white),
          )
        ],
      );
    } else if (type == AppFileType.pdf) {
      final fullPath = path_context.join(currentPath, file.name ?? '');
      final progressData = ref.watch(pdfProgressProvider)[fullPath];
      double progress = 0.0;
      if (progressData != null && progressData.total > 0) {
        progress =
            ((progressData.page + 1) / progressData.total).clamp(0.0, 1.0);
      }

      thumbnailWidget = Stack(
        fit: StackFit.expand,
        children: [
          Container(
              color: placeholderColor,
              child: Center(
                  child: Icon(Icons.picture_as_pdf,
                      size: 48, color: theme.colorScheme.onSurfaceVariant))),
          if (progress > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(value: progress, minHeight: 4),
            ),
          const Positioned(
            top: 4,
            right: 4,
            child: Icon(Icons.picture_as_pdf, size: 16, color: Colors.white),
          )
        ],
      );
    } else if (type == AppFileType.image) {
      // typeIconData = Icons.image;
      final webDavService = ref.read(webDavServiceProvider);
      if (showThumbnails &&
          webDavService.isConnected &&
          webDavService.baseUrl != null &&
          file.name != null) {
        final Uri baseUri = Uri.parse(webDavService.baseUrl!);
        // Construct URL similarly
        var pathSegments = List<String>.from(baseUri.pathSegments);
        if (pathSegments.isNotEmpty && pathSegments.last == '') {
          pathSegments.removeLast();
        }
        pathSegments.addAll(currentPath.split('/').where((s) => s.isNotEmpty));
        pathSegments.add(file.name!);

        thumbnailWidget = Container(
          color: placeholderColor,
          child: Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(
              imageUrl: baseUri.replace(pathSegments: pathSegments).toString(),
              httpHeaders: webDavService.authHeaders,
              memCacheHeight: 200,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(
                  child: Icon(Icons.image, size: 48, color: Colors.grey)),
              errorWidget: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image, size: 48)),
            ),
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.image, size: 16, color: Colors.white),
            )
          ]),
        );
      } else {
        thumbnailWidget = Container(
            color: placeholderColor,
            child: const Center(child: Icon(Icons.image, size: 48)));
      }
    } else {
      thumbnailWidget = Container(
        color: placeholderColor,
        child: Center(child: Icon(_getFileIcon(file.name), size: 48)),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => onLongPress(type),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: thumbnailWidget),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text(
                file.name ?? 'Unknown',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
