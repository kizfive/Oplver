import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:intl/intl.dart';

import 'package:openlist_viewer/features/history/data/file_history_provider.dart';
// removed unused import: view_mode_provider
// removed unused import: view_mode_provider
import '../../../../core/theme/theme_provider.dart';
import 'package:openlist_viewer/features/media/data/video_playback_history_provider.dart';
import 'package:openlist_viewer/features/auth/data/auth_provider.dart';
import 'package:openlist_viewer/features/files/presentation/widgets/video_thumbnail_image.dart';
import 'package:openlist_viewer/features/files/data/pdf_progress_provider.dart';
import 'package:openlist_viewer/features/files/application/folder_analytics_service.dart';

// Local provider controlling the frequent-folders layout on HomePage only
// (removed: layout toggle button uses global view mode now)

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handlePlayUrl() async {
    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('播放网络视频'),
          content: TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: '输入视频 URL (http/https/rtmp...)',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_urlController.text.trim()),
              child: const Text('播放'),
            ),
          ],
        );
      },
    );

    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http')) {
        try {
          final uri = Uri.parse(url);
          final resp = await http.head(uri).timeout(const Duration(seconds: 5));
          if (resp.statusCode >= 400 && resp.statusCode != 405) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('无法访问: ${resp.statusCode}')));
            return;
          }
        } catch (e) {
          // ignore
        }
      }

      if (mounted) {
        context.push('/video?path=${Uri.encodeComponent(url)}');
        ref.read(fileHistoryProvider.notifier).addToHistory(url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(fileHistoryProvider);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: '播放 URL',
            onPressed: () {
              _urlController.clear();
              _handlePlayUrl();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHistorySection(),
            _buildFrequencySection(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySection() {
    final asyncData = ref.watch(folderFrequencyProvider);
    final themeState = ref.watch(appThemeStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      padding: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.bar_chart, size: 20, color: themeState.seedColor),
                const SizedBox(width: 8),
                Text(
                  '常访文件夹',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: '清除常访计数',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认清除'),
                        content: const Text('确定要清除所有常访文件夹的访问计数吗？'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('取消')),
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('确定')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref
                          .read(folderAnalyticsProvider.notifier)
                          .clearAllCounts();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已清除常访计数')));
                    }
                  },
                ),
              ],
            ),
          ),
          asyncData.when(
            data: (entries) {
              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('暂无常访记录',
                        style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ),
                );
              }

              final topEntries = entries.take(10).toList();

              return ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topEntries.length,
                itemBuilder: (context, index) {
                  final entry = topEntries[index];
                  final pathName = p.basename(entry.key) == ''
                      ? 'Root'
                      : p.basename(entry.key);
                  return ListTile(
                    leading: Icon(Icons.folder,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text(
                      pathName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${entry.value} 次访问',
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    onTap: () {
                      final encoded = entry.key == '/'
                          ? ''
                          : Uri.encodeComponent(entry.key.substring(1));
                      ref
                          .read(folderAnalyticsProvider.notifier)
                          .enterFolder(entry.key);

                      if (entry.key == '/') {
                        context.go('/browse');
                      } else {
                        context.push('/browse/dir/$encoded?from=home');
                      }
                    },
                  );
                },
              );
            },
            error: (e, s) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                  child:
                      Text('加载失败', style: TextStyle(color: colorScheme.error))),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    final history = ref.watch(fileHistoryProvider);

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      padding: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.history, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '播放历史',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: '清除播放历史',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认清除'),
                        content: const Text('确定要清除所有播放历史吗？'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('取消')),
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('确定')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref
                          .read(fileHistoryProvider.notifier)
                          .clearHistory();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已清除播放历史')));
                    }
                  },
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 120,
              child: history.isEmpty
                  ? Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off,
                              size: 24,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5)),
                          const SizedBox(width: 8),
                          Text('暂无播放记录',
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return _HistoryCard(item: history[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  final HistoryItem item;

  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 140,
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _handleTap(context, ref),
          onLongPress: () => _showHistoryOptions(context, ref),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: _buildThumbnail(context, ref),
                      ),
                      if (item.type == FileType.video)
                        const Positioned(
                          right: 4,
                          bottom: 4,
                          child: Icon(Icons.play_circle,
                              color: Colors.white70, size: 16),
                        )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(_getFileIcon(item.type),
                      size: 12, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      p.basename(item.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (item.type == FileType.video || item.type == FileType.pdf)
                Padding(
                  padding: const EdgeInsets.only(right: 0.0),
                  child: _buildProgress(ref, context),
                )
              else
                Text(
                  DateFormat('MM-dd HH:mm').format(item.lastOpened),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 9),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
        context: context,
        builder: (_) {
          return SafeArea(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('选项',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                    leading: Icon(Icons.folder_open,
                        color: Theme.of(context).colorScheme.primary),
                    title: const Text('打开文件所在文件夹'),
                    onTap: () {
                      Navigator.pop(context);

                      final dir = p.dirname(item.path);
                      // Add analytics - use recordDirectAccess to ensure it counts immediately
                      ref
                          .read(folderAnalyticsProvider.notifier)
                          .recordDirectAccess(dir);

                      final name = p.basename(item.path);

                      String targetPath = '/browse';
                      if (dir != '/') {
                        final relativeDir =
                            dir.startsWith('/') ? dir.substring(1) : dir;
                        final encoded = Uri.encodeComponent(relativeDir);
                        targetPath += '/dir/$encoded';
                      }

                      // Add timestamp to force rebuild/scroll
                      final qp = {
                        'highlight': name,
                        't': DateTime.now().millisecondsSinceEpoch.toString(),
                        'from': 'home',
                      };
                      context.push(Uri(path: targetPath, queryParameters: qp)
                          .toString());
                    }),
                ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('文件信息'),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                                title: const Text('详细信息'),
                                content: Text(
                                    '路径: ${item.path}\n上次打开: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(item.lastOpened)}'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('确定'))
                                ],
                              ));
                    }),
                const SizedBox(height: 8),
              ]));
        });
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    // Removed immediate history update to prevent visual jump
    // ref.read(fileHistoryProvider.notifier).addToHistory(item.path);

    final webDavService = ref.read(webDavServiceProvider);
    if (!webDavService.isConnected) return;

    if (item.type == FileType.video) {
      context.push('/video?path=${Uri.encodeComponent(item.path)}');
    } else if (item.type == FileType.pdf) {
      context.push('/pdf?path=${Uri.encodeComponent(item.path)}');
    } else if (item.type == FileType.image) {
      final dirPath = p.dirname(item.path);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final files = await webDavService.client!.readDir(dirPath);
        final images = files.where((f) {
          final ext = (f.name ?? '').split('.').last.toLowerCase();
          return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic']
              .contains(ext);
        }).toList();

        images.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

        final imageUrls = images.map((f) {
          final fullPath = p.join(dirPath, f.name);
          return webDavService.getUrl(fullPath);
        }).toList();

        final myName = p.basename(item.path);
        int initialIndex = images.indexWhere((f) => f.name == myName);
        if (initialIndex == -1) initialIndex = 0;

        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          context.push('/gallery/view', extra: {
            'imageUrls': imageUrls,
            'initialIndex': initialIndex,
            'headers': webDavService.authHeaders,
            'files': images,
            'currentPath': dirPath,
          });
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('加载目录失败: $e')));
          final fullUrl = webDavService.getUrl(item.path);
          context.push('/gallery/view', extra: {
            'imageUrls': [fullUrl],
            'initialIndex': 0,
            'headers': webDavService.authHeaders,
            // Fallback: no files/path if failure
          });
        }
      }
    }
  }

  IconData _getFileIcon(FileType type) {
    switch (type) {
      case FileType.video:
        return Icons.movie;
      case FileType.image:
        return Icons.image;
      case FileType.pdf:
        return Icons.picture_as_pdf;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildProgress(WidgetRef ref, BuildContext context) {
    if (item.type == FileType.pdf) {
      final progressMap = ref.watch(pdfProgressProvider);
      final progressData = progressMap[item.path];

      int page = 0;
      int total = 0;
      if (progressData != null) {
        page = progressData.page + 1;
        total = progressData.total;
      }

      double percent = 0.0;
      if (total > 0) {
        percent = (page / total).clamp(0.0, 1.0);
      }

      final pStr = '$page';
      final tStr = '$total';

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: percent,
            backgroundColor: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.2),
            color: Theme.of(context).colorScheme.primary,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(pStr,
                  style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text(tStr,
                  style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          )
        ],
      );
    }

    final history = ref.watch(videoPlaybackHistoryProvider);
    final progressMs = history.positions[item.path] ?? 0;
    final durationMs = history.durations[item.path] ?? 0;

    double percent = 0.0;
    if (durationMs > 0) {
      percent = (progressMs / durationMs).clamp(0.0, 1.0);
    }

    final pStr = _formatDuration(progressMs);
    final dStr = _formatDuration(durationMs);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: percent,
          backgroundColor: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.2),
          color: Theme.of(context).colorScheme.primary,
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(pStr,
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(dStr,
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        )
      ],
    );
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '00:00';
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Widget _buildThumbnail(BuildContext context, WidgetRef ref) {
    switch (item.type) {
      case FileType.image:
        return _buildImageThumbnail(ref, item.path);
      case FileType.video:
        final fileName = p.basename(item.path);
        final dirPath = p.dirname(item.path);
        return VideoThumbnailImage(
          file: webdav.File(name: fileName, isDir: false, size: 0),
          currentPath: dirPath,
          timeMs: 10000,
        );
      case FileType.pdf:
        return Center(
            child: Icon(Icons.picture_as_pdf,
                size: 48, color: Theme.of(context).colorScheme.secondary));
      default:
        return const Center(
            child: Icon(Icons.insert_drive_file, size: 48, color: Colors.grey));
    }
  }

  Widget _buildImageThumbnail(WidgetRef ref, String path) {
    final webDav = ref.read(webDavServiceProvider);
    if (!webDav.isConnected) return const Icon(Icons.broken_image);

    final uri = webDav.getUrl(path);

    return CachedNetworkImage(
      imageUrl: uri,
      httpHeaders: webDav.authHeaders,
      fit: BoxFit.cover,
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorWidget: (context, url, error) => const Icon(Icons.image),
      memCacheWidth: 150,
    );
  }
}
