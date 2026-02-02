import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../../data/manga_models.dart';
import '../../application/manga_service.dart';
import '../../data/manga_image_provider.dart';
import '../../data/manga_provider.dart'; // Add manga provider import
import '../../../settings/data/general_settings_provider.dart';

import 'package:openlist_viewer/features/history/data/file_history_provider.dart';

/// 漫画阅读器页面
class MangaReaderPage extends ConsumerStatefulWidget {
  final MangaInfo manga;

  const MangaReaderPage({super.key, required this.manga});

  @override
  ConsumerState<MangaReaderPage> createState() => _MangaReaderPageState();
}

class _MangaReaderPageState extends ConsumerState<MangaReaderPage> {
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  
  bool _isVerticalMode = true;
  int _currentPage = 0;
  bool _showAppBar = false;
  double _coverAspectRatio = 0.707; // 默认A4比例

  @override
  void initState() {
    super.initState();
    
    // 初始化历史记录 & 恢复阅读进度
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _restoreReadingProgress();
      _updateHistory();
    });
    
    // 监听滚动位置以更新页面指示器
    _scrollController.addListener(_onScroll);
    _pageController.addListener(_onPageChanged);
    _resolveCoverAspectRatio();
  }
  
  // 恢复阅读进度
  void _restoreReadingProgress() async {
    final settings = ref.read(generalSettingsProvider);
    // 确保有进度且开启了自动恢复
    if (settings.autoResumeManga && widget.manga.lastReadIndex > 0) {
      final targetPage = widget.manga.lastReadIndex.clamp(0, widget.manga.chapters.length - 1);
      
      setState(() {
         _currentPage = targetPage;
      });
      
      if (_isVerticalMode) {
         // 垂直模式处理
         // 等待布局完成，如果不等待，maxScrollExtent 可能为 0
         await Future.delayed(const Duration(milliseconds: 300));
         
         if (mounted && _scrollController.hasClients) {
            // 尝试估算位置跳转
            // 注意：这种估算在图片高度差异很大时会不准确，但在大多数漫画中是可用的
            try {
              final maxScroll = _scrollController.position.maxScrollExtent;
              if (maxScroll > 0) {
                final ratio = targetPage / (widget.manga.chapters.length > 1 ? widget.manga.chapters.length - 1 : 1);
                final offset = maxScroll * ratio;
                _scrollController.jumpTo(offset);
              }
            } catch (e) {
              // 忽略跳转错误
            }
         }
      } else {
         _pageController.jumpToPage(targetPage);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text('已恢复阅读进度: 第 ${targetPage + 1} 页'),
           duration: const Duration(milliseconds: 1000),
        ));
      }
    }
  }

  // 更新播放历史 & 漫画进度
  void _updateHistory() {
    final total = widget.manga.chapters.length;
    final current = _currentPage;
    final progress = total > 0 ? (current / total) : 0.0;
    
    // 1. 更新通用历史记录
    ref.read(fileHistoryProvider.notifier).addToHistory(
      widget.manga.folderPath,
      type: FileType.manga,
      title: widget.manga.title,
      coverPath: widget.manga.getCoverImagePath(),
      progress: progress,
      extra: {
        'current': current,
        'total': total,
      }
    );
    
    // 2. 更新漫画专属进度 (持久化到 MangaNotifier)
    ref.read(mangaNotifierProvider.notifier).updateProgress(
        widget.manga.folderPath, 
        current
    );
  }

  /// 尝试获取封面图片的宽高比
  void _resolveCoverAspectRatio() {
    final coverPath = widget.manga.getCoverImagePath();
    if (coverPath == null) return;

    // 先获取图片的URL (使用缩略图更快，且宽高比通常一致)
    ref.read(resolvedMangaCoverProvider(coverPath).future).then((url) {
      if (url == null || !mounted) return;

      final mangaService = ref.read(mangaServiceProvider);
      
      ImageProvider provider;
      if (url.startsWith('http')) {
        final headers = mangaService.getHeadersForUrl(url);
        provider = CachedNetworkImageProvider(url, headers: headers);
      } else {
        provider = FileImage(File(url));
      }

      provider.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener(
          (ImageInfo info, bool _) {
            if (mounted && info.image.width > 0 && info.image.height > 0) {
              setState(() {
                _coverAspectRatio = info.image.width / info.image.height;
              });
            }
          },
          onError: (dynamic exception, StackTrace? stackTrace) {
            // 忽略错误，保持默认比例
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _updateHistory(); // 退出时确保保存最后进度
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isVerticalMode && widget.manga.chapters.isNotEmpty) {
      if (!_scrollController.hasClients) return;
      
      // 简单估算：假设所有图片高度大致相同，或者分布均匀
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;
      
      final scrollRatio = _scrollController.offset / maxScroll;
      final estimatedPage = (scrollRatio * (widget.manga.chapters.length - 1)).round();
      
      if (estimatedPage != _currentPage) {
        // 只有当差异较大时才更新，避免频繁抖动，但也需要足够灵敏
        setState(() {
          _currentPage = estimatedPage.clamp(0, widget.manga.chapters.length - 1);
        });
        // 滚动时不实时保存到磁盘，只更新内存状态，退出或暂停时保存？
        // 现在的 _updateHistory 会写文件/SP，太频繁了。
        // 可以考虑 debouncing，但这里为了简单，先保留，或者只在 dispose 保存？
        // 用户要求“无论这次退出的位置”，所以 dispose 时保存是最重要的。
        // 实时保存是为了防止崩溃丢失。
        _updateHistory(); 
      }
    }
  }

  void _onPageChanged() {
    if (!_isVerticalMode) {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
      _updateHistory(); 
    }
  }

  void _toggleAppBarVisibility() {
    setState(() {
      _showAppBar = !_showAppBar;
    });
  }

  void _toggleReadingMode() {
    setState(() {
      _isVerticalMode = !_isVerticalMode;
    });

    // 在模式切换时保持当前页面位置
    if (!_isVerticalMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.jumpToPage(_currentPage);
      });
    }
  }

  void _jumpToPage() {
    showDialog(
      context: context,
      builder: (context) {
        int targetPage = _currentPage + 1;
        return AlertDialog(
          title: const Text('跳转到页面'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('总共 ${widget.manga.chapters.length} 页'),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '页码',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      targetPage = int.tryParse(value) ?? targetPage;
                    },
                    controller: TextEditingController(text: targetPage.toString()),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                final pageIndex = (targetPage - 1).clamp(0, widget.manga.chapters.length - 1);
                
                if (_isVerticalMode) {
                  // 垂直模式：滚动到对应位置
                  if (_scrollController.hasClients) {
                    final ratio = pageIndex / (widget.manga.chapters.length - 1);
                    final targetOffset = ratio * _scrollController.position.maxScrollExtent;
                    _scrollController.animateTo(
                      targetOffset,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                } else {
                  // 水平模式：切换到对应页面
                  _pageController.animateToPage(
                    pageIndex,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
                
                setState(() {
                  _currentPage = pageIndex;
                });
                _updateHistory(); // 更新进度
              },
              child: const Text('跳转'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mangaService = ref.watch(mangaServiceProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = kToolbarHeight + topPadding;

    return Scaffold(
      backgroundColor: Colors.black, // Reading mode usually dark
      body: Stack(
        children: [
          // Content Layer (Bottom)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleAppBarVisibility,
              behavior: HitTestBehavior.opaque,
              child: _isVerticalMode 
                  ? _buildVerticalReader(mangaService) 
                  : _buildHorizontalReader(mangaService),
            ),
          ),
          
          // AppBar Layer (Top, Animated)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _showAppBar ? 0 : -headerHeight,
            left: 0,
            right: 0,
            height: headerHeight,
            child: AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.9),
              elevation: 4,
              leading: BackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.manga.title,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    '${_currentPage + 1} / ${widget.manga.chapters.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(_isVerticalMode ? Icons.view_column : Icons.view_agenda),
                  onPressed: _toggleReadingMode,
                  tooltip: _isVerticalMode ? '切换到水平模式' : '切换到垂直模式',
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _jumpToPage, // 保留精确跳转功能
                  tooltip: '跳转页面',
                ),
              ],
            ),
          ),

          // Bottom Control Layer (Seek Bar)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _showAppBar ? 0 : -100, // 隐藏时移出屏幕
            height: 100, // 高度足够容纳滑块
            child: Container(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Text(
                        '第 ${_currentPage + 1} 页', 
                        style: Theme.of(context).textTheme.bodyMedium
                      ),
                       Text(
                        '共 ${widget.manga.chapters.length} 页', 
                        style: Theme.of(context).textTheme.bodyMedium
                      ),
                    ],
                  ),
                  Slider(
                    value: _currentPage.toDouble().clamp(0, (widget.manga.chapters.length - 1).toDouble()),
                    min: 0,
                    max: (widget.manga.chapters.length > 1 ? widget.manga.chapters.length - 1 : 1).toDouble(),
                    divisions: (widget.manga.chapters.length > 1 ? widget.manga.chapters.length - 1 : 1),
                    label: '${_currentPage + 1}',
                    onChanged: (value) {
                      setState(() {
                         _currentPage = value.round();
                      });
                    },
                    onChangeEnd: (value) {
                       final pageIndex = value.round();
                       if (_isVerticalMode) {
                          // 垂直模式跳转
                           if (_scrollController.hasClients) {
                              final maxScroll = _scrollController.position.maxScrollExtent;
                              if (maxScroll > 0) {
                                final ratio = pageIndex / (widget.manga.chapters.length - 1);
                                _scrollController.jumpTo(ratio * maxScroll);
                              }
                           }
                       } else {
                          // 水平模式跳转
                          _pageController.jumpToPage(pageIndex);
                       }
                       _updateHistory();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildVerticalReader(MangaService mangaService) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.manga.chapters.length,
      // 使用 cacheExtent 预加载图片
      cacheExtent: 1000, 
      itemBuilder: (context, index) {
        final imagePath = widget.manga.chapters[index];

        // 使用 ref.watch(provider) 替代 FutureBuilder
        // 这样即使列表项被回收重建，只要 provider 没有被 dispose，数据就是即时的
        // 从而消除闪烁
        final asyncUrl = ref.watch(resolvedMangaImageProvider(imagePath));
        
        return asyncUrl.when(
          data: (imageUrl) {
            if (imageUrl == null) {
              return Container(
                height: 400,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 48),
                ),
              );
            }
            
            final headers = mangaService.getHeadersForUrl(imageUrl);

            return CachedNetworkImage(
              imageUrl: imageUrl,
              httpHeaders: headers,
              fit: BoxFit.fitWidth,
              // 优化：使用动态获取的封面比例作为占位符比例
              // 并将背景改为黑色以符合阅读体验
              placeholder: (context, url) => AspectRatio(
                aspectRatio: _coverAspectRatio, 
                child: Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white24, // 降低loading亮度，减少刺眼
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => AspectRatio(
                aspectRatio: _coverAspectRatio,
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('第 ${index + 1} 页加载失败', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () => AspectRatio(
            aspectRatio: _coverAspectRatio,
            child: Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white24),
              ),
            ),
          ),
          error: (err, stack) => AspectRatio(
            aspectRatio: _coverAspectRatio,
            child: Container(
              color: Colors.black,
              child: const Center(
                child: Icon(Icons.error_outline, size: 48, color: Colors.grey),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHorizontalReader(MangaService mangaService) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.manga.chapters.length,
      itemBuilder: (context, index) {
        final imagePath = widget.manga.chapters[index];
        final asyncUrl = ref.watch(resolvedMangaImageProvider(imagePath));
        
        return asyncUrl.when(
          data: (imageUrl) {
            if (imageUrl == null) {
              return Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.white),
                ),
              );
            }

            final headers = mangaService.getHeadersForUrl(imageUrl);

            return PhotoView(
              onTapUp: (context, details, controllerValue) => _toggleAppBarVisibility(),
              imageProvider: CachedNetworkImageProvider(
                imageUrl,
                headers: headers,
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3.0,
              heroAttributes: PhotoViewHeroAttributes(tag: imagePath),
              loadingBuilder: (context, event) => Container(
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image, size: 48, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(
                        '第 ${index + 1} 页加载失败',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => Container(
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator()),
          ),
          error: (err, stack) => Container(
                color: Colors.black,
                child: const Center(child: Icon(Icons.error, color: Colors.red)),
          )
        );
      },
    );
  }
}