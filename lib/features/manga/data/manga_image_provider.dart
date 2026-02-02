import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/manga_service.dart';

/// 缓存的图片URL提供者（Family Provider，根据图片路径缓存解析后的直链）
/// 使用 autoDispose 但配合 keepAlive 或者 UI 层的监听来维持缓存
/// 这里因为漫画阅读时会频繁回看，且页面销毁后缓存可以清除，所以使用 autoDispose 加上简单的内存缓存逻辑
final resolvedMangaImageProvider = FutureProvider.family.autoDispose<String?, String>((ref, imagePath) async {
  // 保持缓存：即使用户滚动出屏幕，短时间内也不销毁（可选，或者直接依赖CachedNetworkImage的磁盘缓存）
  // 但这里缓存的是"解析出的URL字符串"，开销很小。
  // 为了防止列表滚动时疯狂触发API请求，我们应该使用 keepAlive
  final link = ref.keepAlive();
  
  // 设定一个防抖/超时销毁，例如5分钟后如果没人用就销毁，或者随页面销毁?
  // 简单的 keepAlive() 会让它一直保留直到 ProviderContainer 销毁（APP重启），这对于大量图片可能占用内存（仅String key-value）？
  // String 占用很小，保留整个 Session 的 URL 映射是完全可行的。
  
  final mangaService = ref.read(mangaServiceProvider);
  return mangaService.resolveImageUrl(imagePath);
});

/// 漫画封面图片Provider (使用缩略图)
final resolvedMangaCoverProvider = FutureProvider.family.autoDispose<String?, String>((ref, imagePath) async {
  ref.keepAlive();
  final mangaService = ref.read(mangaServiceProvider);
  // 修改为：优先下载并缓存到本地，返回本地文件路径
  return mangaService.downloadAndCacheCover(imagePath);
});
