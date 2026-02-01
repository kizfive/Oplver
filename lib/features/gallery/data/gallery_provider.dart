import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../features/auth/data/auth_provider.dart';
import '../../../../core/utils/file_utils.dart';

class GalleryState {
  final bool isLoading;
  final List<webdav.File> images;
  final String? error;

  GalleryState({
    this.isLoading = false,
    this.images = const [],
    this.error,
  });
}

class GalleryNotifier extends StateNotifier<GalleryState> {
  final Ref ref;
  static const String _cacheKey = 'gallery_image_cache';

  GalleryNotifier(this.ref) : super(GalleryState());

  Future<void> loadImages() async {
    // 1. Load cache immediately to show something
    final cachedFiles = await _loadCache();
    // 初始状态：显示缓存，isLoading=true 表示正在后台刷新
    state = GalleryState(isLoading: true, images: cachedFiles);

    try {
      final webDavService = ref.read(webDavServiceProvider);
      if (!webDavService.isConnected) {
        if (webDavService.baseUrl == null) {
          // If no connection info and no cache, error.
          // If has cache, maybe just show cache? But we want to refresh.
          if (cachedFiles.isEmpty) throw Exception("WebDAV not connected");
        }
        if (webDavService.client == null && cachedFiles.isEmpty) {
          throw Exception("WebDAV client is null");
        }
      }

      List<webdav.File> crawlingImages = [];
      if (webDavService.client != null) {
        // Reset cache flag logic:
        // Once we start getting REAL data from server, we should replace the cache in UI.
        // We pass a callback to _crawl to handle granular updates.
        bool firstUpdate = true;

        await _crawl(webDavService.client!, '/', crawlingImages, 0,
            onUpdate: (currentList) {
          // Strategy:
          // If it's the very first update from server, we replace the "Cached List" with "Live List".
          // This might cause a visual jump (e.g. 100 cached -> 1 live),
          // but it's consistent with "Refreshing".
          // To make it smoother, maybe we wait for first 10 items?
          if (firstUpdate) {
            if (currentList.isNotEmpty) {
              // As soon as we have 1 live image
              firstUpdate = false;
              state =
                  GalleryState(isLoading: true, images: List.from(currentList));
            }
          } else {
            // Subsequent updates
            state =
                GalleryState(isLoading: true, images: List.from(currentList));
          }
        });
      }

      // Save to cache after full crawl
      await _saveCache(crawlingImages);
      state = GalleryState(images: crawlingImages, isLoading: false);
    } catch (e) {
      // If error, keep showing cache but stop loading
      state = GalleryState(
          error: e.toString(), isLoading: false, images: state.images);
    }
  }

  // Caching Logic
  Future<List<webdav.File>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? cachedPaths = prefs.getStringList(_cacheKey);
      if (cachedPaths == null) return [];

      return cachedPaths
          .map((path) => webdav.File(
              path: path,
              name: path.split('/').where((s) => s.isNotEmpty).last,
              isDir: false,
              mimeType: 'image/jpeg' // Dummy mimetype
              ))
          .toList();
    } catch (e) {
      debugPrint('Failed to load gallery cache: $e');
      return [];
    }
  }

  Future<void> _saveCache(List<webdav.File> files) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Only verify valid paths
      final paths =
          files.where((f) => f.path != null).map((f) => f.path!).toList();
      await prefs.setStringList(_cacheKey, paths);
    } catch (e) {
      debugPrint('Failed to save gallery cache: $e');
    }
  }

  // Crawler with depth limit (e.g. 10) and max items limit (e.g. 5000)
  Future<void> _crawl(
      webdav.Client client, String path, List<webdav.File> result, int depth,
      {Function(List<webdav.File>)? onUpdate} // New callback
      ) async {
    if (depth > 10) return; // Increased max depth
    if (result.length >= 5000) return; // Increased soft limit

    try {
      // Ensure path ends with / for readDir on directory
      String safePath = path;
      if (!safePath.endsWith('/')) {
        safePath += '/';
      }

      // debugPrint('Crawling: $safePath (Depth: $depth)');

      final files = await client.readDir(safePath);

      // Separate folders and collect images immediately
      List<webdav.File> subFolders = [];

      for (var f in files) {
        if (result.length >= 5000) break;

        final name = f.name;
        if (name == null || name.startsWith('.')) continue;

        // Filter common NAS/System junk folders
        if (f.isDir == true) {
          if (const {
            '@eaDir',
            '#recycle',
            '#snapshot',
            'System Volume Information',
            '\$RECYCLE.BIN',
            'Recycle Bin'
          }.contains(name)) {
            continue;
          }
        }

        // Skip current directory logic
        String? fPath = f.path;
        if (fPath != null) {
          if (fPath == safePath) {
            continue;
          }
          if (fPath.endsWith('/') &&
              fPath.substring(0, fPath.length - 1) == safePath) {
            continue;
          }
        }

        if (f.isDir == true) {
          subFolders.add(f);
        } else {
          // Explicitly ignore video files
          final lowerName = name.toLowerCase();
          if (lowerName.endsWith('.mp4') ||
              lowerName.endsWith('.mov') ||
              lowerName.endsWith('.avi') ||
              lowerName.endsWith('.mkv')) {
            continue;
          }

          final type = FileUtils.getFileType(name, false);
          if (type == AppFileType.image) {
            result.add(f);
            // Progressive update: always update for the first batch to ensure "First Paint" is fast
            if (result.length < 20 || result.length % 20 == 0) {
              onUpdate?.call(result);
            }
          }
        }
      }

      // Process subfolders with limit to prevent network saturation
      // Using simple chunking (Concurrency Limit ~5)
      // This prevents opening too many connections at once which can cause timeouts or stalling
      const int concurrentLimit = 5;
      for (var i = 0; i < subFolders.length; i += concurrentLimit) {
        if (result.length >= 5000) break;

        final end = (i + concurrentLimit < subFolders.length)
            ? i + concurrentLimit
            : subFolders.length;
        final chunk = subFolders.sublist(i, end);

        // Run this chunk in parallel
        await Future.wait(chunk.map((folder) {
          String nextPath = folder.path ?? '$safePath${folder.name!}/';
          return _crawl(client, nextPath, result, depth + 1,
              onUpdate: onUpdate);
        }));
      }
    } catch (e) {
      debugPrint('Error crawling $path: $e');
    }
  }
}

final galleryProvider =
    StateNotifierProvider<GalleryNotifier, GalleryState>((ref) {
  return GalleryNotifier(ref);
});
