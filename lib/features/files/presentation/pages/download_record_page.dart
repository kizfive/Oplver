import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

import '../../application/download_service.dart';
import '../../application/download_task.dart';

class DownloadRecordPage extends ConsumerWidget {
  const DownloadRecordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清除已完成记录',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认清除'),
                  content: const Text('确定要清除所有已完成/失败的下载记录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(downloadNotifierProvider.notifier).clearCompletedTasks();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已清除完成记录')),
                );
              }
            },
          )
        ],
      ),
      body: tasks.isEmpty
          ? const Center(child: Text('没有下载记录'))
          : ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                // Show newest first? Or keeps order.
                // Usually newest added is at end of list in notifier, so let's reverse visual order if needed.
                // For now, standard order (fifo).
                final task = tasks[tasks.length - 1 - index];
                return _DownloadTaskTile(task: task);
              },
            ),
    );
  }
}

class _DownloadTaskTile extends ConsumerWidget {
  final DownloadTask task;

  const _DownloadTaskTile({required this.task});

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatSpeed(double speedBytesPerSec) {
    if (speedBytesPerSec <= 0) return '';
    return '${_formatBytes(speedBytesPerSec.toInt())}/s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp']
        .contains(path.extension(task.fileName).toLowerCase());

    // Only show thumbnail when download is actively completed.
    // While downloading or paused, show the file icon placeholder.
    // This ensures we don't try to load incomplete/locked files and caching failed states.
    final showThumbnail =
        isImage && task.status == DownloadTaskStatus.completed;

    // Calculate progress value for indicator
    double? progressValue;
    if (task.status == DownloadTaskStatus.completed) {
      progressValue = 1.0;
    } else if (task.totalBytes > 0) {
      progressValue = task.receivedBytes / task.totalBytes;
    } else {
      progressValue = null; // Indeterminate
    }

    // Determine status color/text
    Color? statusColor;
    String statusText = '';

    switch (task.status) {
      case DownloadTaskStatus.failed:
        statusColor = theme.colorScheme.error;
        statusText = 'Failed';
        break;
      case DownloadTaskStatus.paused:
        statusColor = Colors.orange;
        statusText = 'Paused';
        break;
      case DownloadTaskStatus.completed:
        statusColor = Colors.green;
        statusText = ''; // Don't show text if completed, or verified
        break;
      case DownloadTaskStatus.running:
        statusColor = theme.primaryColor;
        // Optionally show speed here or in separate widget
        break;
      default:
        break;
    }

    return InkWell(
      onTap: () {
        if (task.status == DownloadTaskStatus.completed) {
          OpenFilex.open(task.localPath);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon/Image
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: showThumbnail
                      ? Image.file(File(task.localPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image))
                      : const Icon(Icons.insert_drive_file),
                ),
                const SizedBox(width: 12),

                // Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Filename
                      Text(
                        task.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),

                      // Progress Stats (Line 1)
                      Row(
                        children: [
                          if (task.status == DownloadTaskStatus.completed)
                            Text(
                              _formatBytes(task.totalBytes > 0
                                  ? task.totalBytes
                                  : task.receivedBytes),
                              style: theme.textTheme.bodySmall,
                            )
                          else
                            Text(
                              '${_formatBytes(task.receivedBytes)} / ${_formatBytes(task.totalBytes)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          if (statusText.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              statusText,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: statusColor),
                            ),
                          ],
                          if (task.status == DownloadTaskStatus.running) ...[
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                              _formatSpeed(task.speed),
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            )),
                          ]
                        ],
                      ),

                      // Time (Line 2)
                      if (task.startTime != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.startTime.toString().split('.')[0],
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),

                // Action Button
                _buildAction(context, ref),
              ],
            ),
          ),

          // Progress Bar (Stuck to bottom)
          if (task.status != DownloadTaskStatus.pending)
            SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  statusColor ?? theme.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, WidgetRef ref) {
    // Force rebuild on status change
    switch (task.status) {
      case DownloadTaskStatus.running:
        return IconButton(
          icon: const Icon(Icons.pause),
          onPressed: () {
            ref.read(downloadServiceProvider).pauseDownload(task.id);
          },
        );
      case DownloadTaskStatus.paused:
      case DownloadTaskStatus.failed:
      case DownloadTaskStatus.canceled:
        return IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () {
            ref.read(downloadServiceProvider).resumeDownload(task.id);
          },
        );
      case DownloadTaskStatus.completed:
        return IconButton(
          icon: Icon(Icons.folder_open,
              color: Theme.of(context).colorScheme.primary),
          onPressed: () async {
            if (Platform.isAndroid) {
              // Try to open specific folder first
              // 尝试引导用户到具体的 'Oplver Download' 子文件夹
              try {
                // 构建 DocumentsUI 的 Content URI
                // 格式通常为: content://com.android.externalstorage.documents/document/primary:Download%2FOplver%20Download
                // 注意: 这依赖于特定的 Android 版本和文件管理器实现
                const intent = AndroidIntent(
                  action: 'android.intent.action.VIEW',
                  data:
                      'content://com.android.externalstorage.documents/document/primary:Download%2FOplver%20Download',
                  type: 'vnd.android.document/directory',
                  flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
                );
                await intent.launch();
              } catch (e) {
                // 失败回退到通用下载文件夹
                try {
                  const intent = AndroidIntent(
                    action: 'android.intent.action.VIEW_DOWNLOADS',
                    flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
                  );
                  await intent.launch();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '无法直接打开子文件夹。文件位于 "Download > Oplver Download" 中'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e2) {
                  // 最后尝试直接打开文件
                  OpenFilex.open(task.localPath);
                }
              }
            } else {
              OpenFilex.open(path.dirname(task.localPath));
            }
          },
        );
      default:
        // pending
        return const SizedBox(width: 40); // Placeholder
    }
  }
}
