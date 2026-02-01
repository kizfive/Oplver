import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/gallery_provider.dart';
import '../../../../features/auth/data/auth_provider.dart';

class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  @override
  void initState() {
    super.initState();
    // Load images on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(galleryProvider.notifier).loadImages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(galleryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('全部相册'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(galleryProvider.notifier).loadImages();
            },
          )
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(GalleryState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: ${state.error}'),
            ElevatedButton(
              onPressed: () => ref.read(galleryProvider.notifier).loadImages(),
              child: const Text('重试'),
            )
          ],
        ),
      );
    }

    if (state.images.isEmpty) {
      return const Center(child: Text('没有发现图片'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: state.images.length,
      itemBuilder: (context, index) {
        final file = state.images[index];
        return GestureDetector(
          onTap: () {
            _openGallery(state.images, index);
          },
          child: Hero(
            tag: _buildUrl(file.path ?? ''),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: CachedNetworkImage(
                imageUrl: _buildUrl(file.path ?? '', thumbnail: true),
                memCacheHeight: 400,
                httpHeaders: ref.read(webDavServiceProvider).authHeaders,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const Center(child: Icon(Icons.image, color: Colors.grey)),
                errorWidget: (context, url, error) {
                  // debugPrint('Failed to load image: $url, Error: $error');
                  return const Center(child: Icon(Icons.broken_image));
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _buildUrl(String path, {bool thumbnail = false}) {
    final webDavService = ref.read(webDavServiceProvider);
    if (!webDavService.isConnected || webDavService.baseUrl == null) return '';

    // 1. 如果 path 已经是完整 URL，直接返回
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return thumbnail
          ? '$path${path.contains('?') ? '&' : '?'}type=thumbnail'
          : path;
    }

    // 2. 准备 BaseURL 信息
    final Uri baseUri = Uri.parse(webDavService.baseUrl!);
    final String origin =
        '${baseUri.scheme}://${baseUri.authority}'; // e.g. https://example.com
    String basePath = baseUri.path; // e.g. /dav/
    if (basePath.endsWith('/')) {
      basePath = basePath.substring(
          0, basePath.length - 1); // Remove trailing slash e.g. /dav
    }

    // 3. 解码文件路径 (处理潜在的编码问题)
    String decodedFileContext = path;
    try {
      decodedFileContext = Uri.decodeFull(path);
    } catch (e) {
      // Ignore encoding errors, use raw path
    }

    // 4. 对路径进行规范化分段编码
    // 我们需要把 decodedFileContext 切分成段，然后对每一段进行 encodeComponent
    // 这样可以处理中文、空格、特殊符号
    final segments =
        decodedFileContext.split('/').where((s) => s.isNotEmpty).toList();
    final encodedPathString =
        segments.map((s) => Uri.encodeComponent(s)).join('/');

    // 构造带斜杠的编码后路径
    final String cleanEncodedPath = '/$encodedPathString';

    String finalUrl;

    // 5. 智能拼接
    // 检查 cleanEncodedPath 是否已经包含了 basePath
    // 这里需要比较解码后的版本，避免比对 %E4%B8... 和 /dav/ 失败 (假设 basePath 也是纯英文通常没问题，如果是中文路径挂载点则复杂)
    // 简单起见，我们对齐到 "encoded" 层面比较，或者都 decode 比较。
    // WebDAV client 这里的 path 来源是 readDir，如果之前的 crawler 传入的是完整 href，那它可能包含 /dav/。
    // 如果传入的是相对路径，则不包含。

    // 策略：检查 decodedFileContext (原始路径) 是否以 basePath (解码后的) 开头
    String decodedBasePath = Uri.decodeFull(basePath);

    // 必须确保 decodedFileContext 以 / 开头
    String checkPath = decodedFileContext.startsWith('/')
        ? decodedFileContext
        : '/$decodedFileContext';

    if (basePath.isNotEmpty && checkPath.startsWith('$decodedBasePath/')) {
      // 如果文件路径包含了挂载点 (e.g. /dav/folder/img.jpg starts with /dav/), 则直接拼 Origin
      finalUrl = '$origin$cleanEncodedPath';
    } else {
      // 否则补上 BasePath (e.g. Origin + /dav + /folder/img.jpg)
      // 注意 cleanEncodedPath 已经以 / 开头
      // 如果 basePath 为空，直接拼
      if (basePath.isEmpty) {
        finalUrl = '$origin$cleanEncodedPath';
      } else {
        // 对 basePath 也进行重新编码以防万一? 通常 baseUri.path 已经被 Uri 类处理好了
        // 直接用 baseUri.path (带/或不带)
        String prefix = baseUri.path;
        if (prefix.endsWith('/')) {
          prefix = prefix.substring(0, prefix.length - 1);
        }

        finalUrl = '$origin$prefix$cleanEncodedPath';
      }
    }

    if (thumbnail) {
      return '$finalUrl${finalUrl.contains('?') ? '&' : '?'}type=thumbnail';
    }
    return finalUrl;
  }

  void _openGallery(List<dynamic> files, int index) {
    // List<webdav.File> but dynamic to avoid import mess if needed
    final webDavService = ref.read(webDavServiceProvider);

    // Construct all URLs
    final imageUrls = files.map((f) => _buildUrl(f.path!)).toList();

    context.push(
      '/gallery/view',
      extra: {
        'imageUrls': imageUrls,
        'initialIndex': index,
        'headers': webDavService.authHeaders,
      },
    );
  }
}
