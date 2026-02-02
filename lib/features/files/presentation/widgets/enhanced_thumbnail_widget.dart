import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/network/openlist_api_service.dart';
import '../../../core/network/openlist_service.dart';
import '../../../core/network/webdav_service.dart';
import '../../settings/data/general_settings_provider.dart';

/// 增强的缩略图组件，优先使用API获取缩略图
class EnhancedThumbnailWidget extends ConsumerWidget {
  final String filePath;
  final String fileName;
  final String currentPath;
  final Widget fallbackIcon;
  final double? width;
  final double? height;
  final BoxFit fit;

  const EnhancedThumbnailWidget({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.currentPath,
    required this.fallbackIcon,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(generalSettingsProvider);
    final apiService = ref.watch(openListApiServiceProvider);
    final webdavService = ref.watch(webDavServiceProvider);

    // 如果启用了API增强功能且API已连接，优先使用API获取缩略图
    if (settings.enableApiEnhancement && apiService.isConnected) {
      return _buildApiThumbnail(context, apiService, webdavService);
    }

    // 否则使用WebDAV获取缩略图
    return _buildWebDavThumbnail(context, webdavService);
  }

  Widget _buildApiThumbnail(BuildContext context, OpenListApiService apiService, WebDavService webdavService) {
    final thumbnailUrl = apiService.getThumbnailUrl(filePath);
    
    if (thumbnailUrl == null) {
      return _buildWebDavThumbnail(context, webdavService);
    }

    return CachedNetworkImage(
      imageUrl: thumbnailUrl,
      httpHeaders: apiService.authHeaders,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => fallbackIcon,
      errorWidget: (context, url, error) {
        debugPrint('API缩略图加载失败: $error，回退到WebDAV');
        // API缩略图失败，回退到WebDAV
        return _buildWebDavThumbnail(context, webdavService);
      },
    );
  }

  Widget _buildWebDavThumbnail(BuildContext context, WebDavService webdavService) {
    if (!webdavService.isConnected || webdavService.baseUrl == null) {
      return fallbackIcon;
    }

    final Uri baseUri = Uri.parse(webdavService.baseUrl!);
    var pathSegments = <String>[];
    pathSegments.addAll(baseUri.pathSegments);
    
    // Remove empty last segment if any
    if (pathSegments.isNotEmpty && pathSegments.last == '') {
      pathSegments.removeLast();
    }

    var dirSegments = currentPath.split('/').where((s) => s.isNotEmpty);
    pathSegments.addAll(dirSegments);
    pathSegments.add(fileName);

    final uri = baseUri.replace(pathSegments: pathSegments);

    return CachedNetworkImage(
      imageUrl: uri.toString(),
      httpHeaders: webdavService.authHeaders,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => fallbackIcon,
      errorWidget: (context, url, error) => fallbackIcon,
    );
  }
}