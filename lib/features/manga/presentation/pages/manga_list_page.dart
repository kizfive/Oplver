import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../settings/data/general_settings_provider.dart';
import '../../data/manga_provider.dart';
import '../../../files/presentation/widgets/folder_selector_dialog.dart';
import '../widgets/manga_card_widget.dart';
import '../../../../core/i18n/app_localizations.dart';

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
    final l10n = context.l10n;
    final settings = ref.watch(generalSettingsProvider);
    final mangaState = ref.watch(mangaNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('manga')),
        actions: [
          if (mangaState.selectedRootPath != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(mangaNotifierProvider.notifier).refresh();
              },
              tooltip: l10n.tr('refresh'),
            ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _selectMangaFolder,
            tooltip: l10n.tr('selectMangaFolder'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_cache') {
                 _showClearCacheDialog(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear_cache', 
                child: Row(
                   children: [
                     const Icon(Icons.cleaning_services_outlined, color: Colors.grey),
                     const SizedBox(width: 12),
                     Text(l10n.tr('clearMangaCache')),
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
          Text(
            context.l10n.tr('apiEnhancementRequired'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.tr('mangaApiRequiredHint'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              context.go('/profile');
            },
            icon: const Icon(Icons.person),
            label: Text(context.l10n.tr('goEnable')),
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
          Text(
            context.l10n.tr('selectMangaFolderTitle'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.tr('selectMangaFolderHint'),
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _selectMangaFolder,
            icon: const Icon(Icons.folder_open),
            label: Text(context.l10n.tr('selectFolder')),
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
            context.l10n.tr('loadFailed'),
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
            label: Text(context.l10n.tr('retry')),
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
          Text(
            context.l10n.tr('noMangaFound'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.tr('noMangaFoundHint'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _selectMangaFolder,
            icon: const Icon(Icons.folder_open),
            label: Text(context.l10n.tr('reselectFolder')),
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
      title: context.l10n.tr('selectMangaFolder'),
    );

    if (selectedPath != null && mounted) {
      ref.read(mangaNotifierProvider.notifier).setRootPathAndScan(selectedPath);
    }
  }

  Future<void> _showClearCacheDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.tr('clearMangaCache')),
        content: Text(context.l10n.tr('confirmClearMangaCache')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.l10n.tr('clear')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(mangaNotifierProvider.notifier).clearCacheAndReload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tr('mangaCacheClearedAndRescan'))),
      );
    }
  }
}