import 'dart:io';
import 'dart:typed_data';
import 'dart:async'; // Added for Completer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../../auth/data/auth_provider.dart';

class VideoThumbnailImage extends ConsumerStatefulWidget {
  final webdav.File file;
  final String currentPath;
  final int timeMs; // Control the position (in milliseconds)

  const VideoThumbnailImage({
    super.key,
    required this.file,
    required this.currentPath,
    this.timeMs = 5000, // Default to 5th second to avoid black intro frames
  });

  @override
  ConsumerState<VideoThumbnailImage> createState() =>
      _VideoThumbnailImageState();
}

class _VideoThumbnailImageState extends ConsumerState<VideoThumbnailImage> {
  Uint8List? _thumbnailBytes;
//  bool _loading = true; // Start loading immediately
  bool _error = false;
  CancelableTask<Uint8List?>? _loadTask;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void dispose() {
    _loadTask?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.name != widget.file.name ||
        oldWidget.currentPath != widget.currentPath ||
        oldWidget.timeMs != widget.timeMs) {
      // Reload if time position changes
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    if (!mounted) return;

    // Cancel previous task if any
    _loadTask?.cancel();

    // Don't set state if we are just calling this initially, only on updates or logic flow
    // But here we want to reset if it's a new file
    setState(() {
//      _loading = true;
      _error = false;
      _thumbnailBytes = null;
    });

    try {
      // 1. Check local cache first
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/video_thumbnails');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // Create a unique key based on file path, modification time, AND seek position
      final safeName =
          widget.file.name?.replaceAll(RegExp(r'[^\w\.]'), '_') ?? 'unknown';
      final mTime = widget.file.mTime?.millisecondsSinceEpoch ?? 0;
      // Include timeMs in filename to distinguish different frames
      final cacheFile =
          File('${cacheDir.path}/${safeName}_${mTime}_${widget.timeMs}.jpg');

      if (await cacheFile.exists()) {
        final bytes = await cacheFile.readAsBytes();
        if (mounted) {
          setState(() {
            _thumbnailBytes = bytes;
//            _loading = false;
          });
        }
        return;
      }

      // 2. If not in cache, fetch from network
      final webDavService = ref.read(webDavServiceProvider);
      if (!webDavService.isConnected || webDavService.baseUrl == null) {
        throw Exception('WebDAV not connected');
      }

      final Uri baseUri = Uri.parse(webDavService.baseUrl!);
      var pathSegments = List<String>.from(baseUri.pathSegments);
      if (pathSegments.isNotEmpty && pathSegments.last.isEmpty) {
        pathSegments.removeLast();
      }

      final dirSegments =
          widget.currentPath.split('/').where((s) => s.isNotEmpty);
      pathSegments.addAll(dirSegments);
      if (widget.file.name != null) {
        pathSegments.add(widget.file.name!);
      }

      final fullUri = baseUri.replace(pathSegments: pathSegments);

      // Use the global queue to limit concurrent requests
      _loadTask = _ThumbnailQueue.instance.schedule(() async {
        try {
          // Add a small delay for retries to avoid hammering the socket immediately after a change
          if (widget.file.name!.contains('_retry')) {
            // Placeholder condition, logic handled by timeMs change
            await Future.delayed(const Duration(milliseconds: 300));
          }

          return await VideoThumbnail.thumbnailData(
            video: fullUri.toString(),
            imageFormat: ImageFormat.JPEG,
            maxWidth: 320,
            timeMs: widget.timeMs,
            quality: 75,
            headers: webDavService.authHeaders,
          );
        } catch (e) {
          debugPrint('Thumbnail download error inside task: $e');
          return null;
        }
      });

      // Wait for task completion
      final bytes = await _loadTask!.future;

      if (bytes != null) {
        // 3. Save to cache
        await cacheFile.writeAsBytes(bytes);
      }

      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
//          _loading = false;
        });
      }
    } catch (e) {
      if (e == 'Cancelled') {
        // Task was cancelled, ignore
        return;
      }
      debugPrint('Error generating thumbnail for ${widget.file.name}: $e');
      if (mounted) {
        setState(() {
          _error = true;
//          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnailBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          _thumbnailBytes!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image),
        ),
      );
    }

    // Default icon while loading or on error
    return Icon(
      Icons.movie_creation_outlined,
      color: _error ? Colors.grey : null, // Dim if error
    );
  }
}

/// A simple task queue to limit concurrent thumbnail generation.
/// This helps prevent network congestion and "Socket closed" errors.
class _ThumbnailQueue {
  static final _ThumbnailQueue instance = _ThumbnailQueue._();
  _ThumbnailQueue._();

  final int maxConcurrent = 2; // Maximum concurrent tasks
  int _running = 0;
  final List<_Task> _queue = [];

  CancelableTask<T> schedule<T>(Future<T> Function() job) {
    final completer = Completer<T>();
    final task = _Task(job, completer);
    _queue.add(task);

    // Try to start immediately
    _pump();

    return CancelableTask(
      completer.future,
      () {
        // Cancellation logic
        if (_queue.contains(task)) {
          _queue.remove(task);
          completer.completeError('Cancelled');
        }
        // Note: If task is already running, we can't stop the Future job,
        // but we removed the listener so the widget won't update.
      },
    );
  }

  void _pump() async {
    if (_running >= maxConcurrent || _queue.isEmpty) return;

    _running++;
    final task = _queue.removeAt(0);

    try {
      final result = await task.job();
      if (!task.completer.isCompleted) {
        task.completer.complete(result);
      }
    } catch (e) {
      if (!task.completer.isCompleted) {
        task.completer.completeError(e);
      }
    } finally {
      _running--;
      // Schedule next pump
      _pump();
    }
  }
}

class _Task<T> {
  final Future<T> Function() job;
  final Completer<T> completer;
  _Task(this.job, this.completer);
}

class CancelableTask<T> {
  final Future<T> future;
  final VoidCallback cancel;
  CancelableTask(this.future, this.cancel);
}
