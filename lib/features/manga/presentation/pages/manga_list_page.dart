import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../settings/data/general_settings_provider.dart';
import '../../data/manga_provider.dart';
import '../../../files/presentation/widgets/folder_selector_dialog.dart';
import '../widgets/manga_card_widget.dart';

/// 漫画列表页面
class MangaListPage extends ConsumerStatefulWidget {
  const MangaListPage({super.key});

  @override
  ConsumerState<MangaListPage> createState() => _MangaListPageState();
}

class _MangaListPageState extends ConsumerState<MangaListPage> {
  @override
  void initState() {
    super.initState();
    
    // 检查是否已有选择的根路径，如果有则自动加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mangaState = ref.read(mangaNotifierProvider);
      if (mangaState.selectedRootPath != null) {
        ref.read(mangaNotifierProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(generalSettingsProvider);
    final mangaState = ref.watch(mangaNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('漫画'),
        actions: [
          if (mangaState.selectedRootPath != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(mangaNotifierProvider.notifier).refresh();
              },
              tooltip: '刷新',
            ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _selectMangaFolder,
            tooltip: '选择漫画文件夹',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_cache') {
                 _showClearCacheDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_cache', 
                child: Row(
                   children: [
                     Icon(Icons.cleaning_services_outlined, color: Colors.grey),
                     SizedBox(width: 12),
                     Text('清除漫画缓存'),
                   ],
                )
              ),
            ],
          ),
        ],
      ),
      body: !settings.enableApiEnhancement
          ? _buildApiRequiredWidget()
          : mangaState.selectedRootPath == null
              ? _buildSelectFolderWidget()
              : Column(
                  children: [
                    if (mangaState.isLoading) 
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: mangaState.mangaList.isEmpty && mangaState.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : mangaState.mangaList.isEmpty && mangaState.error != null
                              ? _buildErrorWidget(mangaState.error!)
                              : mangaState.mangaList.isEmpty
                                  ? _buildEmptyWidget()
                                  : _buildMangaGrid(mangaState.mangaList),
                    ),
                  ],
                ),
    );
  }

  Widget _buildApiRequiredWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.api_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '需开启API增强',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '漫画功能需要API支持，请前往“我的”页面开启API增强功能',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              context.go('/profile');
            },
            icon: const Icon(Icons.person),
            label: const Text('前往开启'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectFolderWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '选择漫画文件夹',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '请选择包含漫画的文件夹开始浏览',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _selectMangaFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('选择文件夹'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              ref.read(mangaNotifierProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '没有发现漫画',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '在选择的文件夹中没有找到包含.manga文件的漫画目录',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _selectMangaFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('重新选择文件夹'),
          ),
        ],
      ),
    );
  }

  Widget _buildMangaGrid(mangaList) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: mangaList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final manga = mangaList[index];
        return MangaCardWidget(
          manga: manga,
          onTap: () {
            context.push('/manga/reader', extra: manga);
          },
        );
      },
    );
  }

  Future<void> _selectMangaFolder() async {
    final selectedPath = await showFolderSelector(
      context,
      title: '选择漫画文件夹',
    );

    if (selectedPath != null && mounted) {
      ref.read(mangaNotifierProvider.notifier).setRootPathAndScan(selectedPath);
    }
  }

  Future<void> _showClearCacheDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除漫画缓存'),
        content: const Text('确定要清除所有漫画元数据和封面缓存吗？\n这将触发重新全量扫描。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(mangaNotifierProvider.notifier).clearCacheAndReload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('缓存已清除，正在重新扫描...')),
      );
    }
  }
}