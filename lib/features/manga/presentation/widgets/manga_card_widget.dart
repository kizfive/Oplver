import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/manga_models.dart';
import '../../application/manga_service.dart';
import '../../data/manga_image_provider.dart';

/// 漫画卡片组件
class MangaCardWidget extends ConsumerWidget {
  final MangaInfo manga;
  final VoidCallback onTap;

  const MangaCardWidget({
    super.key,
    required this.manga,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mangaService = ref.watch(mangaServiceProvider);
    // 使用封面路径，通过异步Provider获取URL
    final coverPath = manga.getCoverImagePath();
    
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 140, // 固定高度
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 封面图片 (左侧)
                  SizedBox(
                    width: 100, // 固定宽度
                    child: coverPath != null
                        ? _buildCoverImage(context, ref, coverPath, mangaService)
                        : _buildDefaultCover(context),
                  ),
                  
                  // 漫画信息 (右侧)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                manga.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              
                              if (manga.author != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  manga.author!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                          
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               // 标签
                              if (manga.tags != null && manga.tags!.isNotEmpty) ...[
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: manga.tags!.take(3).map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      tag,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  )).toList(),
                                ),
                                const SizedBox(height: 4),
                              ],

                              if (manga.chapters.isNotEmpty)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.insert_drive_file_outlined, 
                                      size: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${manga.chapters.length} 页',
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 底部进度条
          if (manga.chapters.isNotEmpty && manga.lastReadIndex > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: manga.lastReadIndex / (manga.chapters.length > 1 ? manga.chapters.length - 1 : 1),
                minHeight: 4, // 稍微加粗一点点，增强可见性
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary.withOpacity(0.9),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context, WidgetRef ref, String coverPath, MangaService mangaService) {
    // 异步获取URL，解决鉴权和直链问题
    // 使用 resolvedMangaCoverProvider 获取缩略图
    final asyncUrl = ref.watch(resolvedMangaCoverProvider(coverPath));

    return asyncUrl.when(
      data: (path) {
        if (path == null) return _buildErrorCover(context);
        
        // 兼容网络图片
        if (path.startsWith('http')) {
            final headers = mangaService.getHeadersForUrl(path);

            return CachedNetworkImage(
              imageUrl: path,
              httpHeaders: headers,
              fit: BoxFit.cover,
              memCacheWidth: 300, // 限制内存缓存大小，优化列表性能
              placeholder: (context, url) => _buildLoadingCover(context),
              errorWidget: (context, url, error) => _buildErrorCover(context),
            );
        } 
        
        // 本地文件
        return Image.file(
           File(path),
           fit: BoxFit.cover,
           cacheWidth: 300,
           errorBuilder: (_,__,___) => _buildErrorCover(context),
        );
      },
      loading: () => _buildLoadingCover(context),
      error: (err, stack) => _buildErrorCover(context),
    );
  }

  Widget _buildDefaultCover(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.menu_book, size: 48, color: Colors.grey),
      ),
    );
  }

  Widget _buildLoadingCover(BuildContext context) {
     return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

   Widget _buildErrorCover(BuildContext context) {
     return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
      ),
    );
  }
}