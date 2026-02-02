import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:path/path.dart' as path_utils; // 避免与 flutter path 冲突
import 'package:lpinyin/lpinyin.dart'; // Add Pinyin support
import '../../auth/data/auth_provider.dart';
import '../../settings/data/general_settings_provider.dart';
import '../../../core/network/openlist_service.dart';
import 'file_sort_enums.dart';
import 'sort_settings_provider.dart';

export 'file_sort_enums.dart';

// 强制使用 Posix 风格的 Context，确保在所有平台（包括模拟器）上处理 WebDAV URL 路径时使用 '/' 分隔符
final pathContext = path_utils.Context(style: path_utils.Style.posix);

// 状态对象
class FileBrowserState {
  final String currentPath;
  final List<webdav.File> files;
  final Map<String, String> thumbnails; // Path -> Thumbnail URL
  final bool isLoading;
  final String? error;
  final SortOption sortOption;
  final SortOrder sortOrder;

  FileBrowserState({
    this.currentPath = '/',
    this.files = const [],
    this.thumbnails = const {},
    this.isLoading = false,
    this.error,
    this.sortOption = SortOption.name,
    this.sortOrder = SortOrder.asc,
  });

  FileBrowserState copyWith({
    String? currentPath,
    List<webdav.File>? files,
    Map<String, String>? thumbnails,
    bool? isLoading,
    String? error,
    SortOption? sortOption,
    SortOrder? sortOrder,
  }) {
    return FileBrowserState(
      currentPath: currentPath ?? this.currentPath,
      files: files ?? this.files,
      thumbnails: thumbnails ?? this.thumbnails,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sortOption: sortOption ?? this.sortOption,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class FileBrowserNotifier extends StateNotifier<FileBrowserState> {
  final Ref ref;

  FileBrowserNotifier(this.ref, String initialPath)
      : super(FileBrowserState(currentPath: initialPath)) {
    // 监听全局排序设置变化
    ref.listen<SortSettingsState>(sortSettingsProvider, (previous, next) {
      if (previous?.sortOption != next.sortOption ||
          previous?.sortOrder != next.sortOrder) {
        state = state.copyWith(
            sortOption: next.sortOption, sortOrder: next.sortOrder);
        if (state.files.isNotEmpty) {
          final sortedFiles = List<webdav.File>.from(state.files);
          _sortFiles(sortedFiles, next.sortOption, next.sortOrder);
          state = state.copyWith(files: sortedFiles);
        }
      }
    });

    // 初始化应用当前全局设置
    final sortSettings = ref.read(sortSettingsProvider);
    state = state.copyWith(
        sortOption: sortSettings.sortOption, sortOrder: sortSettings.sortOrder);

    // 初始化时加载指定目录
    refresh();
  }

  // 获取 WebDAV 客户端
  webdav.Client? get _client => ref.read(webDavServiceProvider).client;

  // 刷新当前目录
  Future<void> refresh() async {
    await _fetchFiles(state.currentPath);
  }

  // 通过外部传入路径加载
  Future<void> loadPath(String path) async {
    await _fetchFiles(path);
  }

  // 保持现有逻辑不变，虽然 family 模式下主要靠路由跳转
  // ...

  // 进入文件夹
  Future<void> enterFolder(String folderName) async {
    // 使用 pathContext.join 确保使用 / 连接
    // 很多 WebDAV 客户端对路径格式敏感，确保没有反斜杠
    final newPath = pathContext.join(state.currentPath, folderName);
    await _fetchFiles(newPath);
  }

  // 返回上一级
  Future<bool> goBack() async {
    if (state.currentPath == '/' || state.currentPath == '') {
      return false; // 已经在根目录，无法返回
    }
    // 使用 pathContext.dirname 确保正确解析上级目录
    final parentPath = pathContext.dirname(state.currentPath);
    await _fetchFiles(parentPath);
    return true;
  }

  Future<void> _fetchFiles(String path) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final settings = ref.read(generalSettingsProvider);
      
      // 1. API 增强模式
      if (settings.enableApiEnhancement) {
        // 尝试使用 API 获取文件列表（包含略缩图信息）
        final apiService = ref.read(openListApiServiceProvider);
        if (apiService.isConnected) {
          try {
            final fileList = await apiService.listFiles(path);
            if (fileList != null) {
              // 转换 FileInfo 到 webdav.File
              final files = fileList.content.map((info) {
                return webdav.File(
                  name: info.name,
                  isDir: info.isDir,
                  size: info.size,
                  mTime: DateTime.tryParse(info.modified) ?? DateTime.now(),
                  cTime: DateTime.now(), // API doesn't provide cTime usually
                  path: pathContext.join(path, info.name),
                );
              }).toList();

              // 提取略缩图
              final thumbs = <String, String>{};
              for (var info in fileList.content) {
                if (info.thumb != null && info.thumb!.isNotEmpty) {
                  // 保存略缩图 URL，Key 为完整路径
                  final fullPath = pathContext.join(path, info.name);
                  thumbs[fullPath] = info.thumb!;
                }
              }

              _sortFiles(files, state.sortOption, state.sortOrder);

              state = state.copyWith(
                currentPath: path,
                files: files,
                thumbnails: thumbs,
                isLoading: false,
              );
              return; // API 获取成功，直接返回
            }
          } catch (e) {
            // API 失败，降级到 WebDAV
            // debugPrint('API listing failed, falling back to WebDAV: $e');
          }
        }
      }

      // 2. WebDAV 模式 (默认或降级)
      if (_client == null) {
        state = state.copyWith(error: '未连接服务器', isLoading: false);
        return;
      }

      // 确保路径格式正确
      final fetchPath = path.endsWith('/') ? path : '$path/';

      final list = await _client!.readDir(fetchPath);

      _sortFiles(list, state.sortOption, state.sortOrder);

      state = state.copyWith(
        currentPath: path,
        files: list,
        thumbnails: {}, // WebDAV 模式下没有预加载的略缩图
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载失败: $e');
    }
  }

  void setSort(SortOption option, SortOrder order) {
    // 更新全局设置，通过 listener 触发本地更新
    ref.read(sortSettingsProvider.notifier).setSort(option, order);
  }

  void _sortFiles(List<webdav.File> list, SortOption option, SortOrder order) {
    list.sort((a, b) {
      // Always keep directories on top? Usually yes.
      final aIsDir = a.isDir ?? false;
      final bIsDir = b.isDir ?? false;

      if (aIsDir != bIsDir) {
        // Directories always first regardless of sort order, or respect sort order?
        // Standard file explorers keep dirs on top.
        return aIsDir ? -1 : 1;
      }

      int result = 0;
      switch (option) {
        case SortOption.name:
          result = _compareNames(a.name, b.name);
          break;
        case SortOption.size:
          result = (a.size ?? 0).compareTo(b.size ?? 0);
          break;
        case SortOption.date:
          final timeA = a.mTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          final timeB = b.mTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          result = timeA.compareTo(timeB);
          break;
      }

      return order == SortOrder.asc ? result : -result;
    });
  }

  int _compareNames(String? nameA, String? nameB) {
    if (nameA == null && nameB == null) return 0;
    if (nameA == null) return -1;
    if (nameB == null) return 1;

    final strA = nameA.trim();
    final strB = nameB.trim();

    if (strA.isEmpty && strB.isEmpty) return 0;
    if (strA.isEmpty) return -1;
    if (strB.isEmpty) return 1;

    // Helper to detect if string starts with Chinese
    bool isChinese(String s) {
      if (s.isEmpty) return false;
      final code = s.codeUnitAt(0);
      return (code >= 0x4E00 && code <= 0x9FFF);
    }

    // Helper to detect if string starts with English letter
    // bool isLetter(String s) {
    //   if (s.isEmpty) return false;
    //   final code = s.toLowerCase().codeUnitAt(0);
    //   return (code >= 97 && code <= 122);
    // }

    final isChineseA = isChinese(strA);
    final isChineseB = isChinese(strB);

    // Rule 1: Chinese always before non-Chinese (including English)
    if (isChineseA && !isChineseB) return -1;
    if (!isChineseA && isChineseB) return 1;

    // Rule 2: If both are Chinese, sort by Pinyin
    if (isChineseA && isChineseB) {
      final pinyinA = PinyinHelper.getPinyin(strA,
          separator: '', format: PinyinFormat.WITHOUT_TONE);
      final pinyinB = PinyinHelper.getPinyin(strB,
          separator: '', format: PinyinFormat.WITHOUT_TONE);
      return pinyinA.toLowerCase().compareTo(pinyinB.toLowerCase());
    }

    // Rule 3: Natural sort for mixed English/Special Characters
    // We want English letters to be sorted nicely, but non-letters (like symbols) might come after?
    // User requested: Chinese > English.
    // What about Symbols vs English? usually Symbols > English in standard ASCII.
    // Let's stick to standard compare for non-Chinese parts,
    // BUT we need to handle the case where one is English and one is Symbol if we want strict ordering.
    // For now, let's trust standard compare for non-Chinese items unless user complains about symbols.

    return strA.toLowerCase().compareTo(strB.toLowerCase());
  }
}

final fileBrowserProvider = StateNotifierProvider.family
    .autoDispose<FileBrowserNotifier, FileBrowserState, String>((ref, path) {
  return FileBrowserNotifier(ref, path);
});
