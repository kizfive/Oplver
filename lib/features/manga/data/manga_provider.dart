import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../application/manga_service.dart';
import '../data/manga_models.dart';

/// 漫画状态
class MangaState {
  final List<MangaInfo> mangaList;
  final bool isLoading;
  final String? error;
  final String? selectedRootPath;

  const MangaState({
    this.mangaList = const [],
    this.isLoading = false,
    this.error,
    this.selectedRootPath,
  });

  MangaState copyWith({
    List<MangaInfo>? mangaList,
    bool? isLoading,
    String? error,
    String? selectedRootPath,
  }) {
    return MangaState(
      mangaList: mangaList ?? this.mangaList,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Error is nullable, so if we pass null it clears it, if we don't pass it stays.
      // Wait, standard copyWith usually replaces if argument provided, keeps if null.
      // But here `error: error` means if I don't pass error, it becomes null? No, `this.error`.
      // The generated copyWith usually looks like `error: error ?? this.error`.
      // Let's stick to the existing manual copyWith logic but ensure I understand it.
      // Existing: `error: error`. The parameter is `String? error`.
      // If `error` is passed as null, `this.error` is NOT used?
      // Check existing code: `error: error,` directly assigns the parameter.
      // If I call `copyWith(isLoading: true)`, `error` is null (default parameter value), so state.error becomes null.
      // That's actually good for clearing errors on new actions.
      selectedRootPath: selectedRootPath ?? this.selectedRootPath,
    );
  }
}

/// 漫画状态管理器
class MangaNotifier extends StateNotifier<MangaState> {
  final MangaService _mangaService;
  static const String _prefKeyMangaRoot = 'manga_root_path';
  static const String _prefKeyMangaList = 'manga_list_cache';

  MangaNotifier(this._mangaService) : super(const MangaState()) {
    _loadSavedData();
  }

  /// 加载保存的数据（路径和缓存列表）
  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString(_prefKeyMangaRoot);
      
      List<MangaInfo> cachedList = [];
      final savedListJson = prefs.getString(_prefKeyMangaList);
      if (savedListJson != null) {
        try {
          final List<dynamic> decodedIdx = jsonDecode(savedListJson);
          cachedList = decodedIdx.map((e) => MangaInfo.fromStorageJson(e)).toList();
        } catch (e) {
          print('解析漫画缓存失败: $e');
        }
      }

      if (savedPath != null) {
        // 先显示缓存，并标记正在加载以便后台更新
        state = state.copyWith(
          selectedRootPath: savedPath,
          mangaList: cachedList,
          isLoading: true, // 标记为加载中，触发后台扫描
        );
        
        // 触发后台扫描
        await _scan(savedPath, cachedList: cachedList);
      }
    } catch (e) {
      print('加载漫画数据失败: $e');
    }
  }

  /// 设置漫画根目录并扫描
  Future<void> setRootPathAndScan(String rootPath) async {
    // 切换目录时，如果有以前的缓存但路径不同，应该清空列表吗？
    // 通常是的。如果路径变了，以前的缓存无效。
    final isPathChanged = state.selectedRootPath != rootPath;
    
    state = state.copyWith(
      isLoading: true,
      error: null,
      selectedRootPath: rootPath,
      mangaList: isPathChanged ? [] : state.mangaList, // 只有路径改变才清空
    );
    
    // 保存路径到本地
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyMangaRoot, rootPath);
    if (isPathChanged) {
        await prefs.remove(_prefKeyMangaList); // 路径改变清除旧缓存
    }

    await _scan(rootPath, cachedList: isPathChanged ? null : state.mangaList);
  }

  /// 内部扫描逻辑
  Future<void> _scan(String rootPath, {List<MangaInfo>? cachedList}) async {
    try {
      // 传入 cachedList 以利用 "一致则跳过" 优化
      final mangaList = await _mangaService.scanMangaInPath(rootPath, cachedList: cachedList);
      
      state = state.copyWith(
        mangaList: mangaList,
        isLoading: false,
      );

      // 保存列表缓存
      final prefs = await SharedPreferences.getInstance();
      final jsonList = jsonEncode(mangaList.map((e) => e.toStorageJson()).toList());
      await prefs.setString(_prefKeyMangaList, jsonList);

    } catch (e, stackTrace) {
      print('扫描漫画失败: $e');
      print('Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: '扫描漫画失败: $e',
      );
    }
  }

  /// 刷新漫画列表
  Future<void> refresh() async {
    if (state.selectedRootPath != null) {
        // 刷新时传入当前列表作为缓存参考，减少重复加载
      await setRootPathAndScan(state.selectedRootPath!);
    }
  }

  /// 强制清除缓存并刷新
  Future<void> clearCacheAndReload() async {
    // 1. 清除内存中的列表
    state = state.copyWith(mangaList: [], isLoading: true);
    
    // 2. 清除 SharedPreferences 缓存
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyMangaList);
    
    // 3. 清除封面文件缓存
    await _mangaService.clearCoverCache();
    
    // 4. 重新扫描
    if (state.selectedRootPath != null) {
      await _scan(state.selectedRootPath!, cachedList: null); // 不传 cachedList，强制全量加载
    }
  }

  /// 更新阅读进度
  Future<void> updateProgress(String folderPath, int index) async {
    final newList = state.mangaList.map((m) {
      if (m.folderPath == folderPath) {
        return m.copyWith(lastReadIndex: index);
      }
      return m;
    }).toList();

    state = state.copyWith(mangaList: newList);

    // Persist immediately
    final prefs = await SharedPreferences.getInstance();
    final jsonList = jsonEncode(newList.map((e) => e.toStorageJson()).toList());
    await prefs.setString(_prefKeyMangaList, jsonList);
  }

  /// 清空状态
  void clear() {
    state = const MangaState();
    SharedPreferences.getInstance().then((prefs) {
        prefs.remove(_prefKeyMangaList);
        prefs.remove(_prefKeyMangaRoot);
    });
  }
}

/// 漫画状态提供器
final mangaNotifierProvider = StateNotifierProvider<MangaNotifier, MangaState>((ref) {
  final mangaService = ref.watch(mangaServiceProvider);
  return MangaNotifier(mangaService);
});